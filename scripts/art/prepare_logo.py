"""Derive the small-use and single-ink logos from the hand-drawn SVG master.

No fonts, tracing, image generation, third-party modules or raster intermediates.
Edit assets/images/branding/alpine_apex.svg, then run this script with Python 3.
"""
from copy import deepcopy
from pathlib import Path
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[2]
BRAND = ROOT / "assets/images/branding"
NS = "http://www.w3.org/2000/svg"
ET.register_namespace("", NS)


def element(tag, **attributes):
    return ET.Element(f"{{{NS}}}{tag}", attributes)


def document(width, height, title):
    svg = element("svg", width=str(width), height=str(height),
                  viewBox=f"0 0 {width} {height}", fill="none")
    ET.SubElement(svg, f"{{{NS}}}title").text = title
    return svg


def save(svg, path):
    ET.indent(svg, space="  ")
    data = ET.tostring(svg, encoding="unicode") + "\n"
    if not path.exists() or path.read_text(encoding="utf-8") != data:
        path.write_text(data, encoding="utf-8")


def ink(group, color):
    for shape in group.iter():
        if "fill" in shape.attrib and shape.attrib["fill"] != "none":
            shape.set("fill", color)


def summit(color="#EDF4F8"):
    # Optical small-use drawing: three separated strokes, no tiny ridge facets.
    # Same summit / double-chevron rhythm as the full mountain at 32 px.
    group = element("g", fill=color)
    for contour in [
        "M8 96 64 16 120 96H101L64 43 27 96Z",
        "M34 96 64 54 94 96H77L64 78 51 96Z",
        "M57 96 64 86 71 96Z",
    ]:
        group.append(element("path", d=contour))
    return group


def main():
    master = ET.parse(BRAND / "alpine_apex.svg").getroot()
    wordmark = master.find(".//*[@id='wordmark']")

    # For a single ink, a filled shadow would swallow the snow and chevrons.
    # Remove that plane; preserve the ridgeline and the spaces between strokes.
    for name, color in [("light", "#EDF4F8"), ("dark", "#102833")]:
        mono = deepcopy(master)
        mountain = mono.find(".//*[@id='mountain']")
        mountain.remove(mountain.find(".//*[@id='ridge-shadow']"))
        ink(mono, color)
        save(mono, BRAND / f"alpine_apex_{name}.svg")

    compact = document(1120, 180, "Alpine Apex / compact wordmark")
    mark = summit()
    mark.set("transform", "translate(0 16) scale(1.3)")
    compact.append(mark)
    letters = deepcopy(wordmark)
    letters.set("transform", "translate(205 48) scale(.88) skewX(-12)")
    compact.append(letters)
    save(compact, BRAND / "alpine_apex_compact.svg")

    mark = document(128, 128, "Alpine Apex / summit mark")
    mark.append(summit())
    save(mark, BRAND / "alpine_apex_mark.svg")

    app = document(128, 128, "Alpine Apex")
    app.append(element("rect", width="128", height="128", rx="22", fill="#102833"))
    shape = summit()
    shape.set("transform", "translate(8 8) scale(.875)")
    app.append(shape)
    save(app, ROOT / "icon.svg")

    print("Prepared two single-ink logos, compact wordmark, summit mark and app icon.")


if __name__ == "__main__":
    main()
