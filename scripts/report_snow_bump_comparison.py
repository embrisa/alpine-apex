"""Build an unretouched image comparison gallery from native Godot captures."""
import argparse
import html
import json
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFont

LABELS = {
    "open_waves": "Open slope",
    "shallow_wave": "Shallow snow waves",
    "bank_lip": "Snow bank",
    "tree_mounds": "Forest snow",
    "clear": "Clear sky",
    "cloudy": "Overcast",
    "snowfall": "Snowfall",
    "dusk": "Low evening sun",
}


def font(size):
    for path in (Path("C:/Windows/Fonts/segoeui.ttf"), Path("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf")):
        if path.exists():
            return ImageFont.truetype(str(path), size)
    return ImageFont.load_default(size=size)


def title(name):
    for site in ("open_waves", "shallow_wave", "bank_lip", "tree_mounds"):
        if name.startswith(site + "_"):
            weather, daytime = name[len(site) + 1:].rsplit("_", 1)
            return f"{LABELS[site]} · {LABELS[weather]}" + (f" · {LABELS[daytime]}" if daytime != "day" else "")
    return name


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("directory", type=Path)
    args = parser.parse_args()
    folder = args.directory.resolve()
    report = json.loads((folder / "report.json").read_text(encoding="utf-8"))
    if report["failures"]:
        raise SystemExit(f"Capture failed: {report['failures']}")
    if report["display"]["preferences"]["upscaler"] != "native":
        raise SystemExit("This gallery requires the native-resolution comparison")
    if len(report.get("controls", [])) != 2 or not all(c["byte_identical"] for c in report["controls"]):
        raise SystemExit("Frozen baseline repeat controls are not byte-identical")
    pairs = {}
    for sample in report["samples"]:
        pairs.setdefault(sample["name"], {})[sample["look"]] = sample
    cards, metrics = [], []
    for name, pair in pairs.items():
        if set(pair) != {"before", "after"} or pair["before"]["state"] != pair["after"]["state"]:
            raise SystemExit(f"Unmatched camera/weather/state: {name}")
        before = Image.open(folder / pair["before"]["image"]).convert("RGB")
        after = Image.open(folder / pair["after"]["image"]).convert("RGB")
        if before.size != after.size or before.size != (3840, 2160):
            raise SystemExit(f"Unexpected image dimensions: {name}")
        # Same central foreground rectangle at native pixel size in both images.
        crop = (1440, 1300, 2400, 1840)
        a, b = np.asarray(before, dtype=np.float32), np.asarray(after, dtype=np.float32)
        difference = np.abs(a - b)
        detail = difference[crop[1]:crop[3], crop[0]:crop[2]]
        row = {"name": name, "crop_xyxy": crop,
               "mean_absolute_rgb_difference_255": float(difference.mean()),
               "foreground_mean_absolute_rgb_difference_255": float(detail.mean()),
               "identical": bool(np.array_equal(a, b))}
        if row["identical"]:
            raise SystemExit(f"Candidate made no pixel change: {name}")
        metrics.append(row)
        board = Image.new("RGB", (1920, 1230), "#101923")
        draw = ImageDraw.Draw(board)
        draw.text((24, 12), title(name), font=font(28), fill="#eff5fa")
        draw.text((24, 54), "BEFORE · Current snow bump", font=font(22), fill="#b8c8d7")
        draw.text((984, 54), "AFTER · Half snow bump", font=font(22), fill="#b8c8d7")
        for x, picture in ((0, before), (960, after)):
            board.paste(picture.resize((960, 540), Image.Resampling.LANCZOS), (x, 90))
            board.paste(picture.crop(crop), (x, 670))
        draw.text((24, 638), "Same foreground crop · native pixels · no image enhancement", font=font(20), fill="#b8c8d7")
        board.save(folder / f"{name}_comparison.jpg", quality=96, subsampling=0)
        # Lossless, unresized close crops allow direct inspection separately.
        for look, picture in (("before", before), ("after", after)):
            picture.crop(crop).save(folder / f"{name}_{look}_crop.png")
        cards.append(f'''<section class="card" id="{name}"><h2>{html.escape(title(name))}</h2>
<div class="labels"><span>Before · Current bump</span><span>After · Half bump</span></div>
<div class="comparison" style="--split:50%"><img src="{name}_after.png" alt="Half snow bump">
<div class="before"><img src="{name}_before.png" alt="Current snow bump"></div><div class="line"></div>
<input type="range" min="0" max="100" value="50" aria-label="Before and after divider" oninput="this.parentElement.style.setProperty('--split',this.value+'%')"></div>
<details><summary>Compare the same close-up</summary><div class="crop"><figure><img src="{name}_before_crop.png"><figcaption>Before · Current bump</figcaption></figure><figure><img src="{name}_after_crop.png"><figcaption>After · Half bump</figcaption></figure></div></details>
<p class="links"><a href="{name}_before.png" target="_blank">Before · full 4K PNG</a><a href="{name}_after.png" target="_blank">After · full 4K PNG</a><a href="{name}_comparison.jpg" target="_blank">Side-by-side + close-ups</a></p></section>''')
    (folder / "image_metrics.json").write_text(json.dumps(metrics, indent=2), encoding="utf-8")
    page = '''<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Alpine Apex · Softer snow comparison</title><style>
*{box-sizing:border-box}body{margin:0;background:#101923;color:#edf3f8;font:16px system-ui,sans-serif}main{max-width:1460px;margin:0 auto;padding:36px 24px}h1{font-size:clamp(28px,4vw,48px);margin:6px 0 14px}h2{font-size:23px;margin:0 0 16px}p{line-height:1.65;color:#b8c8d7;max-width:950px}.tag{color:#85d9df;letter-spacing:.14em;font-size:12px}nav{display:flex;gap:10px;flex-wrap:wrap;margin:26px 0}a{color:#92dce9;text-underline-offset:4px}nav a{background:#243441;padding:8px 13px;border-radius:6px;text-decoration:none}.card{margin:36px 0 50px;padding:22px;background:#192632;border-radius:12px}.labels{display:flex;justify-content:space-between;gap:10px;margin-bottom:9px;font-size:14px}.comparison{position:relative;width:100%;aspect-ratio:16/9;overflow:hidden;background:#000}.comparison>img,.before img{position:absolute;width:100%;height:100%;object-fit:contain;inset:0}.before{position:absolute;inset:0;clip-path:inset(0 calc(100% - var(--split)) 0 0)}.line{position:absolute;top:0;bottom:0;left:var(--split);width:2px;background:#fff;box-shadow:0 0 6px #000}.comparison input{position:absolute;inset:0;width:100%;height:100%;opacity:0;cursor:ew-resize;margin:0}.links{display:flex;gap:20px;flex-wrap:wrap;font-size:14px}.crop{display:grid;grid-template-columns:1fr 1fr;gap:12px}.crop figure{margin:12px 0}.crop img{width:100%}figcaption{font-size:13px;color:#b8c8d7}summary{padding:16px 0;cursor:pointer}footer{font-size:13px;color:#b8c8d7}@media(max-width:650px){main{padding:20px 12px}.card{padding:14px}.crop{grid-template-columns:1fr}}
</style><main><div class="tag">ALPINE APEX · MATERIAL PREVIEW</div><h1>Does softer surface detail help?</h1>
<p>Drag across each image to compare. <strong>Before</strong> uses the current snow texture bump contribution; <strong>after</strong> halves it. Each pair has the same camera, weather, lighting, terrain and frozen particles. Color, roughness, sparkle settings and geometry are unchanged. The game's default material has not been changed.</p>
<p>Godot DX12 captures · RX 9070 · High preset 7 · Native 3840 × 2160 · MSAA 2× · Upscaling and frame generation off. Two repeated baseline captures match byte for byte. These are still-image comparisons, not performance or motion tests. Close-ups are identical, unretouched crops.</p>
<nav>'''
    page += "".join(f'<a href="#{name}">{html.escape(title(name))}</a>' for name in pairs)
    page += "</nav>" + "\n".join(cards)
    page += '<footer><a href="report.json">Capture receipt</a> · <a href="image_metrics.json">Image verification</a></footer></main></html>'
    (folder / "index.html").write_text(page, encoding="utf-8")
    print(json.dumps({"pairs": len(pairs), "gallery": str(folder / "index.html"), "metrics": metrics}, indent=2))


if __name__ == "__main__":
    main()
