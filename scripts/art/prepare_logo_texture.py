"""The approved vector-only ice/rock finish for the hand-drawn logo.

Large fractures are drawn explicitly. Seeded polygon flecks add repeatable fine
grain; no photographs, image models, filters, fonts or raster content are used.
The clean geometry master is never changed. Run with Python 3, no dependencies.
"""
from copy import deepcopy
from random import Random
import xml.etree.ElementTree as ET
from prepare_logo import BRAND, NS, element, save


def path(group, d, color, opacity=1.0, **attrs):
    group.append(element("path", d=d, fill=color, opacity=str(opacity), **attrs))


def clip(defs, name, shapes):
    region = element("clipPath", id=name, clipPathUnits="userSpaceOnUse")
    for shape in shapes:
        region.append(element("path", d=shape.get("d"), **{"clip-rule": "evenodd"}))
    defs.append(region)
    return {"clip-path": f"url(#{name})"}


def flecks(group, seed, box, count, color, opacity, size=1.0):
    rng = Random(seed)
    x0, y0, width, height = box
    contours = []
    for _ in range(count):
        x, y = x0+rng.random()*width, y0+rng.random()*height
        length, depth = rng.uniform(1.5, 6.0)*size, rng.uniform(.35, 1.3)*size
        contours.append(f"M{x:.2f} {y:.2f}l{length:.2f} {-depth:.2f} "
                        f"{-length*.62:.2f} {depth*1.8:.2f}Z")
    path(group, " ".join(contours), color, opacity)


def main():
    logo = ET.parse(BRAND / "alpine_apex.svg").getroot()
    logo.find(f"{{{NS}}}title").text = "Alpine Apex / fractured ice"
    logo.find(f"{{{NS}}}desc").text = (
        "Hand-drawn vector logo with explicit rock facets, snow fractures and "
        "deterministic polygon frost. Transparent background and letter openings.")
    defs = element("defs")
    logo.insert(2, defs)
    mountain = logo.find(".//*[@id='mountain']")
    shadow = mountain.find(".//*[@id='ridge-shadow']")
    rock = element("g", id="rock-strata", **clip(defs, "rock-boundary", [shadow]))

    # Broad discontinuous planes follow each face's descent direction.
    dark_planes = [
        "M720 24 687 154 646 222 619 302 573 360 627 249 653 174Z",
        "M684 113 660 205 597 274 552 346 585 268 635 196Z",
        "M641 163 615 237 573 267 519 353 547 273 592 227Z",
        "M720 181 708 247 736 315 720 351 703 296 690 258Z",
        "M759 118 800 204 827 237 858 313 820 270 788 213Z",
        "M774 285 797 353 833 392 850 424 804 389 780 331Z",
        "M408 257 403 306 368 354 337 384 360 335Z",
        "M470 326 447 370 398 393 353 418 433 360Z",
        "M542 349 523 387 477 414 453 424 485 391Z",
        "M1008 263 990 327 1013 365 1083 418 1035 399 978 351Z",
        "M1027 333 1054 352 1075 389 1117 415 1075 404Z",
        "M930 328 923 363 960 397 1000 424 952 411 900 373Z",
        "M674 367 650 401 613 424 657 414 692 380Z",
        "M723 344 699 395 670 424 726 411 746 391Z",
    ]
    for contour in dark_planes:
        path(rock, contour, "#183B50", .58)
    light_planes = [
        "M712 54 685 180 651 222 634 280 655 250 677 221 695 163Z",
        "M658 178 629 246 585 290 600 259 631 216Z",
        "M603 253 580 310 548 352 565 314Z",
        "M742 184 760 259 788 293 773 252Z",
        "M696 283 678 347 649 380 659 352Z",
        "M404 293 379 348 362 365 385 346Z",
        "M454 349 430 380 389 405 428 371Z",
        "M1000 309 1013 354 1043 377 1027 353Z",
        "M903 364 931 392 970 416 944 387Z",
        "M775 356 786 387 813 412 797 377Z",
        "M696 400 715 377 724 393 710 413Z",
    ]
    for contour in light_planes:
        path(rock, contour, "#9BC8DA", .45)
    flecks(rock, 913, (208, 24, 1024, 400), 2200, "#D0EAF1", .23, 1.1)
    flecks(rock, 914, (208, 24, 1024, 400), 1500, "#102F44", .30, 1.3)
    mountain.insert(1, rock)

    snow_shapes = [mountain.find(f".//*[@id='{name}']")
                   for name in ["west-snow", "summit-snow", "east-facet"]]
    snow = element("g", id="snow-fractures", **clip(defs, "snow-boundary", snow_shapes))
    for contour in [
        "M747 63 766 111 781 126 787 156 812 190 805 179 774 137Z",
        "M786 137 813 180 840 196 848 220 875 253 848 235 831 211 808 195Z",
        "M843 214 872 256 886 261 910 305 943 337 918 320 895 298 874 270Z",
        "M803 204 829 247 835 278 867 313 841 294 816 248Z",
        "M994 264 1017 285 1020 306 1050 336 1027 324 1004 299Z",
        "M1066 330 1091 371 1139 402 1111 387 1082 374Z",
        "M408 245 434 265 445 288 475 304 458 302 437 287Z",
        "M546 259 518 302 491 324 485 344 504 323 529 300Z",
        "M329 359 299 385 267 398 246 415 282 401 309 386Z",
    ]:
        path(snow, contour, "#487E9D", .30)
    path(snow, "M747 82 761 119 778 130 783 151 M780 129 790 145 "
         "M815 183 824 209 841 218 844 232 M824 209 819 221 "
         "M876 263 886 284 902 292 909 311 M886 284 881 297 "
         "M1010 281 1024 302 1024 316 1043 331 M1024 302 1032 305 "
         "M426 266 432 284 455 296 M432 284 427 291",
         "none", .42, stroke="#446E89", **{"stroke-width":"1.1"})
    flecks(snow, 915, (208, 24, 1024, 400), 2800, "#3B6984", .19, 1.0)
    flecks(snow, 916, (208, 24, 1024, 400), 1800, "#FFFFFF", .65, 1.3)
    # Place before chevrons to keep the emblem legible over the textured face.
    mountain.insert(list(mountain).index(mountain.find(".//*[@id='upper-chevron']")), snow)
    for index, name in enumerate(["upper-chevron", "lower-chevron"]):
        chevron = mountain.find(f".//*[@id='{name}']")
        frost = element("g", id=f"{name}-frost", **clip(defs, f"{name}-boundary", [chevron]))
        flecks(frost, 917+index, (500, 130, 450, 290), 650, "#406E87", .16, 1.15)
        flecks(frost, 927+index, (500, 130, 450, 290), 450, "#FFFFFF", .5, 1.0)
        mountain.append(frost)

    # Texture each letter locally, so real counters remain holes in every renderer.
    wordmark = logo.find(".//*[@id='wordmark']")
    for word in list(wordmark):
        for index, letter in enumerate(list(word)):
            name = letter.get("id")
            wrapper = element("g", transform=letter.attrib.pop("transform", "translate(0)"))
            wrapper.append(deepcopy(letter))
            finish = element("g", **clip(defs, name+"-boundary", [letter]))
            path(finish, "M-4 66 29 58 53 62 82 53 120 58V106H-4Z", "#447B98", .12)
            seed = sum(ord(c) for c in name)
            flecks(finish, seed, (0, 0, 114, 100), 220, "#244F6A", .18, .75)
            flecks(finish, seed+100, (0, 0, 114, 100), 180, "#FFFFFF", .58, .85)
            # Short discontinuous ice seams, never a bevel or outline.
            path(finish, ["M28 12 31 22 26 31 29 40 M31 22 38 24",
                          "M11 51 18 57 16 68 25 75",
                          "M57 4 54 13 62 20 59 30 M62 20 71 22"][index % 3],
                 "none", .2, stroke="#315C76", **{"stroke-width":".75"})
            wrapper.append(finish)
            word.remove(letter)
            word.insert(index, wrapper)
    save(logo, BRAND / "alpine_apex_ice.svg")
    print("Prepared approved fractured-ice finish; clean geometry master unchanged.")


if __name__ == "__main__":
    main()
