"""Publish a compact receipt after the guarded v15 audit, preserving failures.

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
AUDIT = ROOT / "artifacts/v15_route_audit/audit.json"
GUARD = ROOT / "artifacts/guarded/v15-route-audit"
OUTPUT = ROOT / "docs/V15_ROUTE_AUDIT_RESULTS.json"
TERMINAL = {"completed", "crashed", "stalled", "tick_limit"}


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
    require(guard["exit_code"] == 0 and not guard["stop_reason"], "Guard failed")
    require(guard["workload_launched"] and not guard["concurrent"], "Wrong guard scope")
    require("tests/alpine_v15_route_audit.gd" in guard["arguments"], "Wrong guarded script")
    logs = (GUARD / "stdout.log").read_text() + (GUARD / "stderr.log").read_text()
    require(not re.search(r"^(ERROR:|SCRIPT ERROR:|FAIL )", logs, re.M), "Engine/test errors")
    require("V15_ROUTE_AUDIT status=complete" in logs, "Missing completion marker")
    require(audit["status"] == "complete" and not audit["harness_failures"], "Audit failed")
    identity = audit["identity"]
    require(identity["version"] == 15 and identity["seed"] == 849205174, "Wrong recipe")
    require(set(identity["settings"].values()) == {1.0}, "Not Standard settings")
    for source, expected in identity["source_sha256"].items():
        require(digest(ROOT / source.removeprefix("res://")) == expected, f"Source drift: {source}")
    require([row["face_index"] for row in audit["faces"]] == list(range(6)), "Missing/duplicate face")
    receipt = copy.deepcopy(audit)
    for row in receipt["faces"]:
        require(row["survey_status"] == "surveyed", "Unfinished survey")
        pilot = row["pilot"]
        require(pilot["attempts"] == 1 and pilot["status"] in TERMINAL, "Unfinished/repeated pilot")
        require(pilot["completed"] == (pilot["status"] == "completed"), "Pilot status mismatch")
        evidence = ROOT / pilot["evidence"].removeprefix("res://")
        require(digest(evidence) == pilot["evidence_sha256"], "Pilot evidence hash mismatch")
        trace = json.loads(evidence.read_text(encoding="utf-8"))
        require(trace["ticks"] == pilot["ticks"], "Pilot tick count mismatch")
        positions = [[sample[1], sample[3]] for sample in trace["samples"]]
        positions.append([pilot["position"][0], pilot["position"][2]])
        offsets = []
        for x, z in positions:
            angle = math.atan2(x, z) - row["heading_radians"]
            offsets.append(abs(math.atan2(math.sin(angle), math.cos(angle))))
        pilot["sampled_max_face_offset_degrees"] = math.degrees(max(offsets))
        pilot["sampled_positions_outside_30_degree_half_sector"] = sum(
            angle > math.pi / 6 for angle in offsets
        )
        pilot["face_coverage_sampling"] = "One-second positions plus final position; not every tick"
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
        "audit": "artifacts/v15_route_audit/audit.json",
        "audit_sha256": digest(AUDIT),
        "guard": "artifacts/guarded/v15-route-audit/guard.json",
        "guard_sha256": digest(GUARD / "guard.json"),
        "stdout_sha256": digest(GUARD / "stdout.log"),
        "stderr_sha256": digest(GUARD / "stderr.log"),
        "guard_exit_code": guard["exit_code"],
        "command": "./scripts/run_guarded.ps1 -FilePath ./godotw.ps1 -Arguments @('--headless','--script','tests/alpine_v15_route_audit.gd') -Label v15-route-audit -TimeoutSeconds 3600",
        "receipt_command": "python tests/report_v15_route_audit.py",
        "receipt_producer_sha256": digest(Path(__file__)),
        "checkout_head_at_receipt": subprocess.check_output(
            ["git", "rev-parse", "HEAD"], cwd=ROOT, text=True
        ).strip(),
    }
    OUTPUT.write_text(json.dumps(receipt, indent=2, sort_keys=True) + "\n", encoding="utf-8", newline="\n")
    print(f"Validated six surveys and six bounded pilot outcomes: {OUTPUT}")


if __name__ == "__main__":
    main()
