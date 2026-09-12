"""Compare matched native carving captures without claiming visual acceptance."""
from __future__ import annotations

import argparse
import json
from pathlib import Path


def compare(before: Path, after: Path) -> dict:
    old = json.loads((before / "results.json").read_text(encoding="utf-8"))
    new = json.loads((after / "results.json").read_text(encoding="utf-8"))
    failures = []
    for label, report in (("before", old), ("after", new)):
        if report.get("continuity_contract") != 1:
            failures.append(f"{label}: capture lacks required grounded-continuity assertions; v2 is prior evidence")
        if report["failures"] or not report["stable_sources"] or not report["unranked"]:
            failures.append(f"{label}: invalid capture or unstable sources")
    for key in ("model", "engine", "device", "display"):
        if old[key] != new[key]:
            failures.append(f"Mismatched {key}")
    old_cases = {case["name"]: case for case in old["cases"]}
    new_cases = {case["name"]: case for case in new["cases"]}
    if old_cases.keys() != new_cases.keys():
        failures.append("Scenario sets differ")
    identity_paths = [
        "scripts/core/ski_simulation.gd", "config/ski_default.tres",
        "scripts/racing/run_replay.gd", "scripts/presentation/skier_visual.gd",
        "scripts/presentation/skier_full_motion.gd",
    ]
    if old.get("eligibility_reference"):
        identity_paths = list(new["sources"])
    for path in identity_paths:
        if old["sources"].get(path) != new["sources"].get(path):
            failures.append(f"Source identity differs: {path}")
    cases = []
    for name in sorted(old_cases.keys() & new_cases.keys()):
        a, b = old_cases[name], new_cases[name]
        if a["physics_sha256"] != b["physics_sha256"] or a["frames"] != b["frames"]:
            failures.append(f"{name}: completed physics/replay or frame count mismatch")
        if not a["presentation_preserves_physics"] or not b["presentation_preserves_physics"]:
            failures.append(f"{name}: presentation mutation")
        original = [json.loads(line) for line in (before / name / "frames.jsonl").read_text().splitlines()]
        proposed = [json.loads(line) for line in (after / name / "frames.jsonl").read_text().splitlines()]
        rescued, remaining, zero_depth, regressions = [], [], [], []
        remaining_details, continuity_gaps = [], []
        required_count = 0
        for frame_a, frame_b in zip(original, proposed, strict=True):
            frame = frame_a["frame"]
            if frame != frame_b["frame"] or frame_a["physics_sha256"] != frame_b["physics_sha256"]:
                failures.append(f"{name}/{frame}: unmatched completed state")
            for ski_a, ski_b in zip(frame_a["contacts"], frame_b["contacts"], strict=True):
                ski = ski_a["ski"]
                if ski_a["rendered_position"] != ski_b["rendered_position"] or ski_a["rendered_forward"] != ski_b["rendered_forward"]:
                    failures.append(f"{name}/{frame}/{ski}: rendered equipment differs")
                if ski_a.get("continuity_required") != ski_b.get("continuity_required"):
                    failures.append(f"{name}/{frame}/{ski}: continuity evidence window differs")
                if ski_b.get("continuity_required"):
                    required_count += 1
                    if not ski_b["live"]:
                        continuity_gaps.append([frame, ski, ski_b["response"].get("track_reason")])
                if ski_a["live"] and not ski_b["live"]:
                    regressions.append([frame, ski, "previously live mark lost"])
                if not frame_a["grounded"]:
                    if ski_b["live"]:
                        regressions.append([frame, ski, "airborne live footprint"])
                    continue
                if not ski_a["live"] and ski_b["live"]:
                    rescued.append({"frame": frame, "ski": ski, "physical_grounded": ski_a["grounded"],
                                    "load_n": ski_a["load_n"], "rendered_lift_m": ski_a["rendered_height_above_surface_m"],
                                    "old_response": ski_a["response"], "new_response": ski_b["response"]})
                if not ski_b["live"]:
                    remaining.append([frame, ski, ski_b["response"].get("track_reason", "baseline")])
                    remaining_details.append({"frame": frame, "ski": ski, "physical_grounded": ski_b["grounded"],
                                              "load_n": ski_b["load_n"], "material": ski_b["material"],
                                              "root_clearance_m": ski_b["clearance_m"],
                                              "rendered_lift_m": ski_b["rendered_height_above_surface_m"],
                                              "reason": ski_b["response"].get("track_reason"),
                                              "rejection": ski_b["response"].get("track_rejection", {})})
                if ski_b["live"] and ski_b["response"].get("track_depth_m", ski_b["response"]["depth_m"]) <= 0:
                    zero_depth.append([frame, ski])
        if regressions:
            failures.append(f"{name}: invalid or lost marks")
        if zero_depth:
            failures.append(f"{name}: live mark has zero depth")
        if continuity_gaps:
            failures.append(f"{name}: required grounded continuity still interrupted")
        if b["scenario"] != "jump" and (not required_count or required_count != b.get("required_continuity_samples")):
            failures.append(f"{name}: grounded continuity windows missing or sample count differs")
        cases.append({"name": name, "rescued_frames": rescued, "remaining_grounded_gaps": remaining,
                      "remaining_grounded_gap_details": remaining_details, "required_continuity_samples": required_count,
                      "required_continuity_gaps": continuity_gaps,
                      "live_zero_depth_frames": zero_depth, "invalid_marks": regressions,
                      "before_effects_us": a["effects_submission_us"], "after_effects_us": b["effects_submission_us"]})
    rescue_count = sum(len(case["rescued_frames"]) for case in cases)
    return {"failures": failures, "cases": cases, "rescued_ski_frames": rescue_count,
            "reproduction": "ordinary-input eligibility gaps measured" if rescue_count else "NOT reproduced by these captures",
            "visual_acceptance": "pending full grounded continuity review, including all remaining exclusions; restored flags alone are insufficient",
            "human_acceptance": "pending", "timing_scope": "effects CPU submission only; contended run, not full-descent FPS"}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("before", type=Path)
    parser.add_argument("after", type=Path)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    report = compare(args.before, args.after)
    with args.output.open("x", encoding="utf-8") as stream:
        json.dump(report, stream, indent=2)
    print(f"Carving comparison: {report['reproduction']}; failures={len(report['failures'])}")
    return int(bool(report["failures"]))


if __name__ == "__main__":
    raise SystemExit(main())
