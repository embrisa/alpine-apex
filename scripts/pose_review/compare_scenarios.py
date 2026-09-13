"""Build a local, synchronized review of scenario or recorded-case evidence.

Source/tuning changes are expected comparison inputs. Mismatched stimuli,
truncated coverage and failed producers remain visible; no automatic fix verdict.
"""
import argparse
import hashlib
import html
import json
import math
import os
from pathlib import Path
import shutil
from urllib.parse import quote

FORMAT = "alpine-scenario-evidence"
ROOT = Path(__file__).resolve().parent


def finite(value):
    if isinstance(value, float) and not math.isfinite(value):
        raise ValueError("Non-finite evidence value")
    if isinstance(value, dict):
        for item in value.values():
            finite(item)
    if isinstance(value, list):
        for item in value:
            finite(item)


def read_json(path):
    value = json.loads(path.read_text(encoding="utf-8-sig"))
    finite(value)
    return value


def asset(folder, name):
    if not isinstance(name, str) or not name or Path(name).is_absolute() or ":" in name or "\\" in name:
        raise ValueError("Evidence assets must use relative paths")
    path = (folder / name).resolve()
    if not path.is_relative_to(folder):
        raise ValueError("Evidence asset escapes its directory")
    return path


def load_evidence(path):
    path = Path(path).resolve()
    if path.is_dir():
        path /= "manifest.json"
    manifest = read_json(path)
    if not isinstance(manifest, dict):
        raise ValueError("Expected manifest object")
    if manifest.get("format") != FORMAT or manifest.get("version") != 1 or manifest.get("simulation_hz") != 120:
        raise ValueError("Unsupported evidence format, version or simulation rate")
    for field in ("scenario", "stimulus", "identity", "status", "captures", "stable_sources"):
        if field not in manifest:
            raise ValueError("Missing manifest field: " + field)
    if not isinstance(manifest["identity"], dict) or not isinstance(manifest["stimulus"], dict):
        raise ValueError("Expected identity and stimulus objects")
    rows = read_json(asset(path.parent, manifest.get("telemetry")))
    if not isinstance(rows, list) or not rows or len(rows) > 72001:
        raise ValueError("Expected 1-72001 telemetry rows")
    previous = None
    for row in rows:
        if not isinstance(row, dict):
            raise ValueError("Expected telemetry object")
        tick = row.get("tick")
        if isinstance(tick, bool) or not isinstance(tick, (int, float)) or tick != int(tick) or tick < 0:
            raise ValueError("Invalid telemetry tick")
        if previous is not None and tick != previous + 1:
            raise ValueError("Telemetry must have continuous, ordered ticks")
        if not isinstance(row.get("time"), (int, float)) or abs(row["time"] - tick / 120) > 1e-6:
            raise ValueError("Telemetry time does not match its 120 Hz tick")
        if not isinstance(row.get("state"), dict) or not isinstance(row.get("metrics"), dict) or not isinstance(row.get("input"), list):
            raise ValueError("Invalid telemetry state, metrics or input")
        position = row["state"].get("position")
        if not isinstance(position, list) or len(position) != 3 or not all(isinstance(v, (int, float)) for v in position):
            raise ValueError("Expected 3D state position")
        if not all(v is None or isinstance(v, (int, float)) for v in row["metrics"].values()):
            raise ValueError("Metrics must be numeric or null")
        if not isinstance(row.get("events"), list) or not all(isinstance(e, str) for e in row["events"]):
            raise ValueError("Invalid telemetry events")
        previous = tick
    if not isinstance(manifest["captures"], list):
        raise ValueError("Expected capture list")
    missing = []
    for frame in manifest["captures"]:
        if not isinstance(frame, dict):
            raise ValueError("Expected capture object")
        file = asset(path.parent, frame.get("path"))
        if file.suffix.lower() not in (".png", ".jpg", ".jpeg", ".webp"):
            raise ValueError("Capture must be a raster image")
        if not isinstance(frame.get("tick"), (int, float)) or not rows[0]["tick"] <= frame["tick"] <= rows[-1]["tick"]:
            raise ValueError("Capture tick outside telemetry coverage")
        if not file.is_file():
            missing.append(frame["path"])
    return {"path": path, "manifest": manifest, "rows": rows, "missing": missing}


def different(a, b, tolerance):
    if isinstance(a, bool) or isinstance(b, bool):
        return type(a) != type(b) or a != b
    if isinstance(a, (int, float)) and isinstance(b, (int, float)):
        return abs(a - b) > tolerance
    if isinstance(a, list) and isinstance(b, list):
        return len(a) != len(b) or any(different(x, y, tolerance) for x, y in zip(a, b))
    if isinstance(a, dict) and isinstance(b, dict):
        return a.keys() != b.keys() or any(different(a[k], b[k], tolerance) for k in a)
    return a != b


def changes(a, b):
    return sorted(k for k in a.keys() | b.keys() if a.get(k) != b.get(k))


def state_identity(manifest):
    return manifest.get("recorded_identity", manifest["identity"]) if manifest.get("state_origin") == "recorded_pose" else manifest["identity"]


def compare(before, after, tolerance=1e-6):
    if not math.isfinite(tolerance) or tolerance < 0:
        raise ValueError("Tolerance must be finite and nonnegative")
    a, b = before["manifest"], after["manifest"]
    left = {r["tick"]: r for r in before["rows"]}
    right = {r["tick"]: r for r in after["rows"]}
    ticks = sorted(left.keys() & right.keys())
    if not ticks:
        raise ValueError("Evidence has no overlapping ticks")
    issues = []
    if a["scenario"] != b["scenario"] or a["stimulus"] != b["stimulus"]:
        issues.append("Different scenario or stimulus; this is an unmatched comparison.")
    for label, evidence in (("Before", before), ("After", after)):
        m = evidence["manifest"]
        if m["status"] != "complete" or m.get("failures"):
            issues.append(label + " producer failed: " + str(m.get("failures", m["status"])))
        if not m["stable_sources"]:
            issues.append(label + " source changed during evidence production.")
        if m.get("scope") == "diagnostic_case" and not m.get("recorded_stable_sources", False):
            issues.append(label + " original recording has unstable source identity; matching-source verification is unavailable.")
        if evidence["missing"]:
            issues.append(label + " has missing capture files.")
        if not m["captures"]:
            issues.append(label + " has telemetry only; visual review is unavailable.")
    if left.keys() != right.keys():
        issues.append("Coverage differs; the unmatched tail is not compared.")
    input_tick = next((t for t in ticks if left[t]["input"] != right[t]["input"]), None)
    if input_tick is not None:
        issues.append(f"Input differs at tick {input_tick}; later differences may be stimulus driven.")
    ai, bi = state_identity(a), state_identity(b)
    if ai.get("engine_sha256") != bi.get("engine_sha256"):
        issues.append("Simulation engine identities differ.")
    if a.get("camera") != b.get("camera"):
        issues.append("Capture settings differ; inspect each image's actual camera and time.")
    # Additional telemetry can be introduced without treating absent optional
    # channels (such as historical body roll) as a physics divergence.
    state_fields = sorted(set.intersection(*(set(left[t]["state"]) & set(right[t]["state"]) for t in ticks)))
    excluded = sorted(set.union(*(set(left[t]["state"]) | set(right[t]["state"]) for t in ticks)) - set(state_fields))
    first = None
    first_fields = []
    max_position = 0.0
    for tick in ticks:
        ls, rs = left[tick]["state"], right[tick]["state"]
        fields = [k for k in state_fields if different(ls[k], rs[k], tolerance)]
        if first is None and fields:
            first, first_fields = tick, fields
        max_position = max(max_position, math.dist(ls["position"], rs["position"]))
    metrics = sorted(set.union(*(set(left[t]["metrics"]) | set(right[t]["metrics"]) for t in ticks)))
    stats = {}
    for key in metrics:
        stats[key] = {}
        for label, side in (("before", left), ("after", right)):
            values = [side[t]["metrics"].get(key) for t in ticks]
            values = [v for v in values if v is not None]
            stats[key][label] = {"samples": len(values), "min": min(values), "max": max(values), "mean": sum(values) / len(values)} if values else None
    return {"format": "alpine-scenario-comparison", "version": 1, "issues": issues,
            "first_divergence_tick": first, "first_divergence_fields": first_fields,
            "state_tolerance": tolerance, "compared_fields": state_fields, "excluded_fields": excluded,
            "maximum_position_difference_m": max_position, "first_input_difference_tick": input_tick,
            "source_changes": sorted(k for k in ai.get("sources", {}).keys() & bi.get("sources", {}).keys() if ai["sources"][k] != bi["sources"][k]),
            "unpaired_source_hashes": {"before_only": sorted(ai.get("sources", {}).keys() - bi.get("sources", {}).keys()), "after_only": sorted(bi.get("sources", {}).keys() - ai.get("sources", {}).keys())},
            "tuning_changes": changes(a.get("tuning", {}), b.get("tuning", {})),
            "coverage": {"before": [min(left), max(left)], "after": [min(right), max(right)], "overlap": [ticks[0], ticks[-1]]},
            "metrics": metrics, "metric_statistics": stats, "verdict": "Observations only; no automatic fix, performance or human acceptance verdict."}


def build(before_path, after_path, output, tolerance=1e-6):
    before, after = load_evidence(before_path), load_evidence(after_path)
    result = compare(before, after, tolerance)
    output = Path(output).resolve()
    if output.exists():
        raise ValueError("Choose a fresh comparison directory; existing reviews are preserved")
    payload = {"comparison": result}
    for label, evidence in (("before", before), ("after", after)):
        m = evidence["manifest"]
        payload[label] = {"scenario": m["scenario"], "state_origin": m.get("state_origin", "current_solver"), "notes": m.get("notes", {}), "stop_reason": m.get("stop_reason"), "manifest": quote(os.path.relpath(evidence["path"], output).replace("\\", "/")), "captures": [], "rows": [{k: row[k] for k in ("tick", "time", "metrics", "events")} for row in evidence["rows"]]}
        result[label + "_manifest_sha256"] = hashlib.sha256(evidence["path"].read_bytes()).hexdigest()
        result[label + "_telemetry_sha256"] = hashlib.sha256(asset(evidence["path"].parent, m["telemetry"]).read_bytes()).hexdigest()
        for frame in sorted(m["captures"], key=lambda f: f["tick"]):
            item = {k: v for k, v in frame.items() if k != "pose"}
            item["url"] = quote(os.path.relpath(asset(evidence["path"].parent, frame["path"]), output).replace("\\", "/"))
            item["missing"] = frame["path"] in evidence["missing"]
            payload[label]["captures"].append(item)
    output.mkdir(parents=True)
    (output / "comparison.json").write_text(json.dumps(result, indent=2, allow_nan=False), encoding="utf-8")
    for name in ("scenario_review.js", "scenario_review.css"):
        shutil.copyfile(ROOT / name, output / name)
    encoded = json.dumps(payload, allow_nan=False).replace("<", "\\u003c").replace("\u2028", "\\u2028").replace("\u2029", "\\u2029")
    title = html.escape(str(before["manifest"].get("notes", {}).get("title") or before["manifest"]["scenario"]))
    page = '''<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Scenario comparison</title><link rel="stylesheet" href="scenario_review.css">
<main><p class="eyebrow">ALPINE APEX / EVIDENCE REVIEW</p><h1>SCENARIO</h1><p>Original stimulus, synchronized ticks, observed changes. Images show the nearest captured frame.</p>
<div id="issues" role="status"></div><div class="pair"><section><h2>Before <small id="before-origin"></small></h2><img id="before-image" alt="Before captured frame"><p id="before-frame"></p><a id="before-manifest">Evidence manifest</a></section><section><h2>After <small id="after-origin"></small></h2><img id="after-image" alt="After captured frame"><p id="after-frame"></p><a id="after-manifest">Evidence manifest</a></section></div>
<section class="timeline"><div class="controls"><button id="play">Play</button><button id="previous" aria-label="Previous tick">−1 tick</button><button id="next" aria-label="Next tick">+1 tick</button><button id="divergence">First divergence</button><output id="clock"></output></div><input id="timeline" aria-label="Synchronized tick" type="range" step="1"><div id="events"></div></section>
<section><div class="controls"><label>Metric <select id="metric"></select></label><span class="legend">● Before <b>● After</b></span><output id="values"></output></div><canvas id="chart" width="1200" height="220" aria-label="Metric over shared tick coverage"></canvas><p id="chart-range"></p></section>
<details open><summary>Comparison identity and coverage</summary><pre id="identity"></pre></details><details><summary>Case notes</summary><pre id="notes"></pre></details><footer>Observations only. Rendered evidence, physics checks, FPS measurements and human/controller acceptance remain separate.</footer></main>
<script id="evidence" type="application/json">PAYLOAD</script><script src="scenario_review.js"></script></html>'''
    (output / "index.html").write_text(page.replace("SCENARIO", title).replace("PAYLOAD", encoded), encoding="utf-8")
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("before", type=Path)
    parser.add_argument("after", type=Path)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--tolerance", type=float, default=1e-6)
    args = parser.parse_args()
    try:
        result = build(args.before, args.after, args.output, args.tolerance)
    except (ValueError, OSError, KeyError, TypeError) as error:
        parser.exit(2, str(error) + "\n")
    print(json.dumps({"output": str(args.output.resolve() / "index.html"), "first_divergence_tick": result["first_divergence_tick"], "issues": result["issues"]}))


if __name__ == "__main__":
    main()
