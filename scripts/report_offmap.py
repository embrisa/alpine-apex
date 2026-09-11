"""Build a local before/after gallery and collect measured off-map evidence."""
import json
import hashlib
from pathlib import Path
from html import escape
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "artifacts/offmap_v2"
NATIVE = ROOT / "artifacts/pc_environment"
BEFORE = NATIVE / "offmap_v2_before"
AFTER = NATIVE / "offmap_v2_final"


def read(path):
    return json.loads(path.read_text(encoding="utf-8-sig")) if path.exists() else None


def audit(folder):
    source = read(folder / "system.json")
    if not source:
        return None
    samples = source["samples"]
    gpu = [row["gpu_memory"] for row in samples if row.get("gpu_memory")]
    engine_ids = {row["engine_pid"] for row in samples}
    return {
        "started_utc": source["started_utc"], "ended_utc": source["ended_utc"],
        "cpu": source["cpu"], "installed_ram_bytes": source["installed_ram_bytes"],
        "changed_sources": source["changed_sources"],
        "other_godot_samples": sum(any(p["Id"] not in engine_ids for p in row.get("other_godot_processes", [])) for row in samples),
        "raw_other_godot_samples": sum(bool(row.get("other_godot_processes")) for row in samples),
        "engine_pids": sorted(engine_ids),
        "audit_note": "The console launcher may briefly list its own engine child before discovery; engine IDs observed in this same run are excluded from competing-process counts. Raw samples are retained in system.json.",
        "wow_samples": sum(bool(row.get("wow_running")) for row in samples),
        "peak_working_set_bytes": max(row["working_set_bytes"] for row in samples),
        "peak_private_bytes": max(row["private_bytes"] for row in samples),
        "minimum_system_free_bytes": min(row["system_free_bytes"] for row in samples),
        "peak_dedicated_gpu_bytes": max((row["dedicated_bytes"] for row in gpu), default=None),
        "peak_shared_gpu_bytes": max((row["shared_bytes"] for row in gpu), default=None),
        "memory_scope": "Whole paired-validation process including both scenery sets and loading",
    }


def compare_descents(paired):
    comparisons = {}
    if not paired:
        return comparisons
    for condition in ["clear", "snowfall"]:
        trials = [r for r in paired["trials"] if r["weather"] == condition]
        if len(trials) != 2:
            continue
        a = next(r for r in trials if r["baseline"])
        b = next(r for r in trials if not r["baseline"])
        budget = {"gpu_delta_ms": b["render_gpu_ms"]["median"] - a["render_gpu_ms"]["median"],
                  "p95_ratio": b["frame_ms"]["p95"] / a["frame_ms"]["p95"],
                  "p99_ratio": b["frame_ms"]["p99"] / a["frame_ms"]["p99"]}
        budget["relative_pass"] = budget["gpu_delta_ms"] <= .5 and max(budget["p95_ratio"], budget["p99_ratio"]) <= 1.05
        budget["absolute_pass"] = b["frame_ms"]["p95"] <= 11.1 and b["frame_ms"]["p99"] <= 16.7
        budget["baseline_absolute_pass"] = a["frame_ms"]["p95"] <= 11.1 and a["frame_ms"]["p99"] <= 16.7
        budget["matched_simulation"] = all(a[k] == b[k] for k in ["loaded_simulation_sha256", "height_sha256", "obstacle_sha256", "seconds", "peak_kmh"])
        budget["both_finished"] = a["finished"] and b["finished"] and not a["crash"] and not b["crash"]
        comparisons[condition] = budget
    return comparisons


def provenance():
    frozen = ROOT / "tests/fixtures/offmap_v1"
    snapshot = read(OUT / "baseline_sources.json")
    verified = {}
    for row in snapshot:
        name = Path(row["Path"].replace("\\", "/")).name
        original = (frozen / name).read_bytes()
        if name == "alpine_wilderness.gd":
            original = original.replace(b"res://tests/fixtures/offmap_v1/wilderness_data.gd", b"res://scripts/world/wilderness_data.gd")
            original = original.replace(b"res://tests/fixtures/offmap_v1/alpine_wilderness.gdshader", b"res://assets/graphics/alpine_wilderness.gdshader")
        verified[name] = hashlib.sha256(original).hexdigest().upper() == row["Hash"]
    before = read(BEFORE / "wilderness.json")
    after = read(AFTER / "wilderness.json")
    return {"frozen_baseline_matches_original_hashes": verified,
            "matched_physical_fingerprints": all(before[k] == after[k] for k in ["height_sha256", "obstacle_sha256"]),
            "baseline_presentation_version": before["backdrop"]["version"],
            "upgraded_presentation_version": after["backdrop"]["version"],
            "upgraded_sources": after["backdrop"]["source_sha256"]}


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    views = sorted(p.name for p in AFTER.glob("*.png") if (BEFORE / p.name).exists())
    selected = ["summit_clear_day_0.png", "summit_clear_day_3.png", "descent_clear_day_1250_chase.png"]
    board = Image.new("RGB", (1920, 3 * 580), "#172431")
    draw = ImageDraw.Draw(board)
    for row, name in enumerate(selected):
        for col, folder in enumerate([BEFORE, AFTER]):
            with Image.open(folder / name) as source:
                picture = source.convert("RGB").resize((960, 540), Image.Resampling.LANCZOS)
            board.paste(picture, (col * 960, row * 580 + 40))
            draw.text((col * 960 + 16, row * 580 + 12), ("Before" if col == 0 else "After") + " - " + name.removesuffix(".png"), fill="white")
    board.save(OUT / "comparison.jpg", quality=95)
    abba = read(NATIVE / "offmap_v2_abba_final/comparison.json")
    paired = read(NATIVE / "offmap_v2_descents/paired.json")
    suites = read(OUT / "regressions.json")
    comparisons = compare_descents(paired)
    summary = {"abba": abba, "descents": paired, "descent_budgets": comparisons,
               "audits": {name: audit(NATIVE / folder) for name, folder in [("abba", "offmap_v2_abba_final"), ("descents", "offmap_v2_descents")]},
               "regressions": suites, "matched_captures": len(views), "user_skiing_acceptance": "pending"}
    summary["provenance"] = provenance()
    summary["rendered_review"] = read(OUT / "visual_review.json")
    cards = []
    for name in views:
        cards.append(f'<section><h2>{escape(name.removesuffix(".png"))}</h2><div class="pair">' + "".join(f'<figure><figcaption>{label}</figcaption><a href="../pc_environment/{folder}/{name}"><img loading="lazy" src="../pc_environment/{folder}/{name}"></a></figure>' for label, folder in [("Before", BEFORE.name), ("After", AFTER.name)]) + '</div></section>')
    motion = NATIVE / "offmap_v2_motion"
    motion_cards = []
    manifest = read(motion / "motion.json") or {"clips": [], "frames_per_clip": 0}
    summary["motion"] = manifest
    qa_pages = {}
    for clip_index, condition in enumerate(label.removesuffix("_baseline") for label in manifest["clips"] if label.endswith("_baseline")):
        frames = []
        for index in range(manifest["frames_per_clip"]):
            frame = Image.new("RGB", (1280, 380), "#172431")
            d = ImageDraw.Draw(frame)
            for col, label in enumerate(["baseline", "upgraded"]):
                with Image.open(motion / f"{condition}_{label}_{index:03d}.jpg") as source:
                    frame.paste(source.resize((640, 360), Image.Resampling.LANCZOS), (640 * col, 20))
                d.text((640 * col + 10, 4), "Before" if col == 0 else "After", fill="white")
            frames.append(frame)
            keyframes = [0, manifest["frames_per_clip"] // 2, manifest["frames_per_clip"] - 1]
            if index in keyframes:
                page = qa_pages.setdefault(clip_index // 4, Image.new("RGB", (1920, 4 * 390), "#172431"))
                x, y = keyframes.index(index) * 640, (clip_index % 4) * 390
                page.paste(frame.crop((640, 20, 1280, 380)), (x, y + 30))
                ImageDraw.Draw(page).text((x + 8, y + 8), f"{condition} / frame {index}", fill="white")
        frames[0].save(OUT / f"motion_{condition}.webp", save_all=True, append_images=frames[1:], duration=100, loop=0, quality=80, method=4)
        motion_cards.append(f'<h2>{condition}</h2><img loading="lazy" src="motion_{condition}.webp"><p>Matched camera motion; capture overhead is excluded from performance results. <a href="../pc_environment/offmap_v2_motion/{condition}_upgraded_000.jpg">4K frame</a></p>')
    for page_index, page in qa_pages.items():
        page.save(OUT / f"qa_motion_{page_index}.jpg", quality=93)
    budget = abba["budget"] if abba else {}
    summary["acceptance"] = {
        "automated_pass": bool(suites) and all(row["exit"] == 0 and row["errors"] == 0 for row in suites),
        "relative_performance_pass": bool(budget.get("relative_pass")) and len(comparisons) == 2 and all(row["relative_pass"] and row["both_finished"] and row["matched_simulation"] for row in comparisons.values()),
        "absolute_frame_targets_pass": bool(budget.get("absolute_pass")) and len(comparisons) == 2 and all(row["absolute_pass"] for row in comparisons.values()),
        "isolated_stable_timing": all(row and not row["changed_sources"] and row["other_godot_samples"] == 0 for row in summary["audits"].values()),
        "rendered_evidence_complete": len(views) == 46 and len(manifest["clips"]) == 32 and manifest.get("actual_pixels") == [3840, 2160],
        "user_skiing": "pending",
    }
    html = '<!doctype html><meta charset="utf-8"><title>Alpine Apex - off-map scenery v2</title><style>body{margin:32px;background:#14212c;color:#e1e9ee;font:16px system-ui}h1{font-size:30px}.pair{display:grid;grid-template-columns:1fr 1fr;gap:16px}figure{margin:0}img{width:100%;height:auto}section{margin:40px 0}figcaption{margin-bottom:8px}pre{white-space:pre-wrap}a{color:#c9e4ff}</style>'
    html += '<h1>Alpine Apex - off-map scenery v2</h1><p>4K output / High / 75% FSR2 / 120 FPS cap / SDFGI off. Captures show appearance; benchmark timings exclude readback. User skiing acceptance remains pending.</p><p><a href="report.json">Complete measurements, memory audits and checks</a> · <a href="../../docs/OFFMAP_V2.md">Implementation and acceptance notes</a></p>'
    html += '<h2>Measured performance</h2><table cellpadding="10"><tr><th>Scenario / scenery</th><th>Median GPU ms</th><th>Median render CPU ms</th><th>p95 frame ms</th><th>p99 frame ms</th><th>Mean draw calls</th></tr>'
    rows = []
    if abba:
        for label, row in abba["pooled"].items():
            rows.append(("Six-view ABBA / " + label, row["gpu_ms"], row["cpu_ms"], row["frame_ms"], row["draw_calls"]))
    if paired:
        for row in paired["trials"]:
            rows.append((row["weather"] + " descent / " + ("baseline" if row["baseline"] else "upgraded"), row["render_gpu_ms"], row["render_cpu_ms"], row["frame_ms"], row["draw_calls"]))
    for label, gpu, cpu, frame, draws in rows:
        html += f'<tr><td>{escape(label)}</td><td>{gpu["median"]:.3f}</td><td>{cpu["median"]:.3f}</td><td>{frame["p95"]:.3f}</td><td>{frame["p99"]:.3f}</td><td>{draws["mean"]:.1f}</td></tr>'
    html += '</table><p>Allowance: at most +0.5 ms median GPU time and +5% p95/p99. Project targets: p95 ≤11.1 ms / p99 ≤16.7 ms.</p><pre>' + escape(json.dumps({"abba": budget, "descents": comparisons}, indent=2)) + '</pre>'
    html += '<p>Memory audits include both scenery versions resident for controlled switching. Full-descent physics/source identity and construction timings are in the complete measurements. Animated comparisons are camera tours, not human skiing acceptance.</p>'
    html += ''.join(motion_cards + cards)
    (OUT / "index.html").write_text(html, encoding="utf-8")
    (OUT / "report.json").write_text(json.dumps(summary, indent=2), encoding="utf-8")
    print(json.dumps({"matched_captures":len(views), "budget":budget, "report":str(OUT / "index.html")}))
    return 0 if all(summary["acceptance"][key] for key in ["automated_pass", "relative_performance_pass", "isolated_stable_timing", "rendered_evidence_complete"]) and all(summary["provenance"]["frozen_baseline_matches_original_hashes"].values()) else 1


if __name__ == "__main__":
    raise SystemExit(main())
