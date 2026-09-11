"""Freeze the pre-carving working tree and retain isolated regression evidence."""
from pathlib import Path
import argparse
import hashlib
import json

import steep_upgrade_evidence as runner

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "artifacts/arcade_carving_v20"
SUITES = "physics runtime downhill_control downhill_contact handling_upgrade high_speed_turns high_speed_balance jump airborne_control airborne_pose ski_attachment turn_anatomy impact_recovery landing_absorption rock_terrain competitive rider_lifecycle skier_anatomy".split()


def sources():
    paths = [p for folder in ("scripts", "tests", "config", "assets")
             for p in (ROOT / folder).rglob("*")
             if p.suffix in (".gd", ".tres", ".gdshader", ".gdshaderinc", ".tscn", ".json")]
    paths += [ROOT / "project.godot", ROOT / "main.tscn"]
    return {p.relative_to(ROOT).as_posix(): hashlib.sha256(p.read_bytes()).hexdigest()
            for p in paths}


def freeze():
    isolated_runner()["freeze"]()
    # Freeze raw tests and presentation too, so later failures can be audited.
    for folder in ("tests", "scripts/presentation", "scripts/racing", "config"):
        for p in (ROOT / folder).rglob("*"):
            if p.is_file() and p.suffix in (".gd", ".tres", ".json"):
                target = OUT / "baseline_sources" / p.relative_to(ROOT)
                target.parent.mkdir(parents=True, exist_ok=True)
                target.write_bytes(p.read_bytes())
    (OUT / "baseline_runtime_hashes.json").write_text(json.dumps(sources(), indent=2))


def prepare_native_reference():
    """Pair frozen physics with the current renderer, world and animation."""
    if not (OUT / "reference/ski_simulation.gd").exists():
        raise SystemExit("The native reference needs the frozen v19 source snapshot.")
    main = (ROOT / "scripts/main.gd").read_text(encoding="utf-8-sig")
    main = main.replace("res://scripts/core/ski_simulation.gd",
                        "res://artifacts/arcade_carving_v20/reference/ski_simulation.gd")
    main = main.replace("var sim: SkiSimulation", "var sim: RefCounted")
    (OUT / "native_reference_main.gd").write_text(main, encoding="utf-8")
    scene = (ROOT / "main.tscn").read_text(encoding="utf-8-sig")
    scene = scene.replace("res://scripts/main.gd",
                          "res://artifacts/arcade_carving_v20/native_reference_main.gd")
    (OUT / "native_reference.tscn").write_text(scene, encoding="utf-8")


def isolated_runner():
    # The inherited runner redirects artifact writes into this task's directory.
    # Replace its embedded historical path without changing that earlier helper.
    code = Path(runner.__file__).read_text(encoding="utf-8-sig")
    code = code.replace("artifacts/steep_animation_physics_upgrade", "artifacts/arcade_carving_v20")
    namespace = {"__file__": runner.__file__, "__name__": "arcade_suite_runner"}
    exec(compile(code, runner.__file__, "exec"), namespace)
    return namespace


def suites(label, selected):
    namespace = isolated_runner()
    before = sources()
    outcome = namespace["suites"](label, selected or SUITES)
    after = sources()
    folder = OUT / label
    (folder / "source_hashes.json").write_text(json.dumps({"before": before, "after": after,
        "changed_during_run": [p for p in before.keys() | after.keys() if before.get(p) != after.get(p)]}, indent=2))
    return outcome


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--freeze", action="store_true")
    parser.add_argument("--prepare-native", action="store_true")
    parser.add_argument("--label", default="after")
    parser.add_argument("suites", nargs="*")
    args = parser.parse_args()
    OUT.mkdir(parents=True, exist_ok=True)
    if args.freeze:
        freeze()
    elif args.prepare_native:
        prepare_native_reference()
    else:
        raise SystemExit(suites(args.label, args.suites))
