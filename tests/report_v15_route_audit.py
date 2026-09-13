"""Publish a compact current receipt after the guarded bounded v15 audit.

Run from the repository root: python tests/report_v15_route_audit.py
Detailed paths/commands/logs remain in ignored artifacts; the receipt is tracked.
"""

import copy
import hashlib
import json
import math
import re
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
AUDIT = ROOT / "artifacts/current_v15_bounded_route_audit/audit.json"
GUARD = ROOT / "artifacts/guarded/current-v15-bounded-route-audit"
OUTPUT = ROOT / "docs/CURRENT_V15_BOUNDED_ROUTE_RESULTS.json"
TERMINAL = {"bounded_complete"}


def digest(path):
    result = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            result.update(chunk)
    return result.hexdigest()


def require(condition, message):
    if not condition:
        raise ValueError(message)


def base_crossing(points, radius=2850.0):
    """First outward intersection, in the survey's face-local coordinates."""
    for a, b in zip(points, points[1:]):
        if math.hypot(*b) < radius:
            continue
        dx, dz = b[0] - a[0], b[1] - a[1]
        length_squared = dx * dx + dz * dz
        projection = a[0] * dx + a[1] * dz
        discriminant = projection**2 - length_squared * (
            a[0] ** 2 + a[1] ** 2 - radius**2
        )
        t = (-projection + math.sqrt(max(0.0, discriminant))) / length_squared
        return [a[0] + t * dx, a[1] + t * dz]
    return None


def main():
    audit = json.loads(AUDIT.read_text(encoding="utf-8"))
    guard = json.loads((GUARD / "guard.json").read_text(encoding="utf-8-sig"))
    require(guard["exit_code"] == 0 and not guard["stop_reason"] and guard["workload_launched"], "Guard failed")
    require(guard["full_mountain"] and guard["full_mountain_reason"].strip(), "Missing recorded full-mountain coverage reason")
    require("tests/alpine_v15_route_audit.gd" in guard["arguments"], "Wrong guarded script")
    logs = (GUARD / "stdout.log").read_text() + (GUARD / "stderr.log").read_text()
    require(not re.search(r"^(ERROR:|SCRIPT ERROR:|FAIL )", logs, re.M), "Engine/test errors")
    require("CURRENT_V15_BOUNDED_ROUTE_AUDIT status=complete" in logs, "Missing completion marker")
    require(audit["status"] == "complete" and not audit["harness_failures"], "Audit failed")
    require(audit["classification"] == "current_source_hashed_bounded_route_scenario", "Wrong audit classification")
    identity = audit["identity"]
    require(identity["version"] == 15 and identity["seed"] == 849205174, "Wrong recipe")
    require(set(identity["settings"].values()) == {1.0}, "Not Standard settings")
    for source, expected in identity["source_sha256"].items():
        require(digest(ROOT / source.removeprefix("res://")) == expected, f"Source drift: {source}")
    require([row["face_index"] for row in audit["faces"]] == list(range(6)), "Missing/duplicate face")
    receipt = copy.deepcopy(audit)
    for row in receipt["faces"]:
        require(row["survey_status"] == "surveyed", "Unfinished survey")
        probes = row["probes"]
        require(len(probes) == 3, "Need three matched bounded probes")
        for probe_index, probe in enumerate(probes, 1):
            require(probe["repetition"] == probe_index and probe["status"] in TERMINAL, "Unfinished probe")
            require(probe["ticks"] == 1800 and math.isclose(probe["simulation_seconds"], 15.0), "Wrong probe duration")
            stress = probe["stress"]
            require(math.isclose(stress["target_speed_kmh"], 170.0), "Wrong stress target")
            require(abs(stress["speed_kmh"]["min"] - 170.0) <= .01 and abs(stress["speed_kmh"]["max"] - 170.0) <= .01, "Uncontrolled probe speed")
            require(stress["travelled_m"] >= 170.0 / 3.6 * 15.0 * .9, "Insufficient probe distance")
            evidence = ROOT / probe["evidence"].removeprefix("res://")
            require(digest(evidence) == probe["evidence_sha256"], "Probe evidence hash mismatch")
            trace = json.loads(evidence.read_text(encoding="utf-8"))
            require(trace["ticks"] == probe["ticks"] and trace["control"] == {"stress_speed_kmh": 170.0, "full_tuck": True, "braking": False}, "Probe control mismatch")
            positions = [[sample[1], sample[3]] for sample in trace["samples"]]
            positions.append([probe["position"][0], probe["position"][2]])
            offsets = []
            for x, z in positions:
                angle = math.atan2(x, z) - row["heading_radians"]
                offsets.append(abs(math.atan2(math.sin(angle), math.cos(angle))))
            probe["sampled_max_face_offset_degrees"] = math.degrees(max(offsets))
            probe["sampled_positions_outside_30_degree_half_sector"] = sum(angle > math.pi / 6 for angle in offsets)
            probe["face_coverage_sampling"] = "One-second positions plus final position; not every tick"
        row.pop("reachable_columns")
        crossings = []
        for path in row["paths"]:
            points = path.pop("points")
            path["point_count"] = len(points)
            path["base_boundary_local_xz"] = base_crossing(points)
            if path["base_boundary_local_xz"] is not None:
                crossings.append(path["base_boundary_local_xz"])
        row["base_boundary_endpoint_separation_m"] = (
            math.dist(*crossings) if len(crossings) == 2 else None
        )
    receipt["evidence"] = {
        "audit": "artifacts/current_v15_bounded_route_audit/audit.json",
        "audit_sha256": digest(AUDIT),
        "guard": "artifacts/guarded/current-v15-bounded-route-audit/guard.json",
        "guard_sha256": digest(GUARD / "guard.json"),
        "stdout_sha256": digest(GUARD / "stdout.log"),
        "stderr_sha256": digest(GUARD / "stderr.log"),
        "guard_exit_code": guard["exit_code"],
        "command": "./scripts/run_guarded.ps1 -FilePath ./godotw.ps1 -Arguments @('--headless','--script','tests/alpine_v15_route_audit.gd') -Label current-v15-bounded-route-audit -TimeoutSeconds 900 -FullMountain -FullMountainReason 'Current default-v15 route geometry and bounded speed-controlled probe evidence'",
        "receipt_command": "python tests/report_v15_route_audit.py",
        "receipt_producer_sha256": digest(Path(__file__)),
        "checkout_head_at_receipt": subprocess.check_output(
            ["git", "rev-parse", "HEAD"], cwd=ROOT, text=True
        ).strip(),
    }
    receipt["acceptance"] = {
        "automated": "passed: six source-hashed graph surveys and three exact 15-second 170 km/h full-tuck/no-brake probes per face",
        "rendered": "not_run: headless route audit has no rendered inspection",
        "performance": "not_measured: headless probes contain no rendered frame-time acceptance",
        "human_controller": "not_run: synthetic benchmark-only steering/control is not player acceptance",
    }
    OUTPUT.write_text(json.dumps(receipt, indent=2, sort_keys=True) + "\n", encoding="utf-8", newline="\n")
    print(f"Validated six surveys and eighteen bounded high-speed probe outcomes: {OUTPUT}")


if __name__ == "__main__":
    main()
