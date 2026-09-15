"""Install the complete premium presentation catalog without touching world data."""
import json
import os
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def main() -> None:
    if os.environ.get("ALPINE_VALIDATION_MODE") != "Exclusive":
        raise SystemExit("Run integrate_premium_trees.ps1 under its owning guard.")
    update = json.loads((ROOT / "artifacts/premium_forest_integration/catalog_update.json").read_text())
    catalog_path = ROOT / "assets/graphics/trees/manifest.json"
    branches_path = ROOT / "assets/graphics/trees/branches.json"
    catalog = json.loads(catalog_path.read_text())
    branches = json.loads(branches_path.read_text())
    replacement = {entry["id"]: entry for entry in update["assets"]}
    current_ids = [entry["id"] for entry in catalog["assets"]]
    if len(replacement) != 30 or set(replacement) != set(current_ids):
        raise SystemExit("Premium catalog must replace exactly the current 30 tree IDs.")
    catalog["assets"] = [replacement[entry["id"]] for entry in catalog["assets"]]
    branches.update(update["branches"])
    for path, data in ((catalog_path, catalog), (branches_path, branches)):
        raw = path.read_bytes()
        newline = "\r\n" if b"\r\n" in raw else "\n"
        path.write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n", encoding="utf-8", newline=newline)
    print(f"PREMIUM_CATALOG_MERGED assets={len(replacement)} physical_tree_data_unchanged=true")


if __name__ == "__main__":
    main()
