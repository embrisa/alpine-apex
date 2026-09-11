# Private GitHub collaboration

The project uses the private `embrisa/alpine-apex` repository. Code, configuration,
scenes, import settings and documentation use normal Git. Models, textures, audio,
editable art, large collision data and the Windows toolchain use Git LFS.
Both collaborators need access to this repository and Git LFS installed.

## First checkout on Windows

Install Git for Windows (includes Git LFS) and PowerShell 7. In PowerShell:

```powershell
git lfs install
git clone https://github.com/embrisa/alpine-apex.git
cd alpine-apex
git lfs pull
./scripts/setup_collaboration.ps1
./godotw.ps1
```

Setup verifies and extracts the bundled, pinned Godot 4.7.2 editor and the
validated Alpine FidelityFX game runtime into ignored `.tools`, then imports
the assets. The first import can take 20 minutes or more; later imports are
incremental. Blender and Cascadeur
are needed only for their authoring workflows, not for playing or exporting.
The purchased TreeDesigner authoring library remains excluded; exported game
assets are included. Keep that library backed up separately.

Use `./godotw.ps1 --editor` to open the bundled editor. F5 in the stock editor
uses stock rendering; use `./godotw.ps1` for the custom FidelityFX runtime.
`GODOT_BIN` explicitly overrides automatic engine selection; unset it when
using this pinned setup. Windows x64 and a compatible DX12 GPU are required
for the custom runtime. Hardware behavior on another PC still needs a playtest.

## Pull, edit and share changes

```powershell
git pull --ff-only
git lfs pull
./scripts/setup_collaboration.ps1
```

Keep one checkout and pull changes into it. Only changed assets need downloading
again. Work directly on `main`; do not create branches, pull requests or worktrees.
Commit and push small, validated milestones frequently, and push completed work
before ending a task. Inspect status and remote updates first, preserve concurrent
edits, and stage only the milestone's files. Commit related source and asset
changes together. Do not force-push or rewrite shared history. Coordinate editing of
Blender, Cascadeur and other binary assets because Git cannot merge their
contents. Do not use `git lfs fetch --all` for everyday development.

Run the relevant suites described in `AGENTS.md` before sharing gameplay changes.
Keep generated builds, caches, credentials and validation output ignored.
Preserve `.import` and `.uid` files: they are part of reproducible Godot imports.
The attributes preserve file bytes across checkouts because generation receipts
and art provenance hash source files; avoid unrelated line-ending conversions.

## Export a playable build

After setup and import:

```powershell
./scripts/build_collaboration.ps1
```

The command creates a new timestamped directory under `builds`, prepares the
dependency receipt, exports, and copies the runtime DLLs, native wind library
and license notices. It prints the executable path and writes file hashes in
`BUILD.json`. An existing nonempty output directory is rejected to avoid mixing
old and new exports. Use `-OutputDirectory builds/my-playtest` for a specific new
directory. Run the command normally; it owns its validation guard.

This build generates its default mountain on first launch. See
[Windows packaging](WINDOWS_PLAYTEST.md) for optional prepared default-mountain
caches. Source play also generates or rebuilds its own version-validated caches;
personal saves and caches are not in Git.

## Storage and monthly cost

The September 11 committed snapshot contains about 20.49 GiB of unique LFS data,
including the Windows toolchain, plus 21.4 MiB of current ordinary Git files.
Existing ordinary Git history is additional. GitHub
Free includes 10 GiB storage and 10 GiB of monthly LFS downloads per owner.
At the published metered rates, the snapshot costs approximately $0.74
per full month in storage, and one complete download adds approximately $0.92
after that month's free bandwidth. Taxes and other account usage are separate.

The owner has authorized up to $5/month for LFS. Configure the existing Git LFS
budget with **Stop usage when budget limit is reached** enabled and keep usage
alerts on. The $5 budget and hard stop were verified on September 11, 2026;
the account's live Billing page is authoritative. Reaching the limit can block
LFS transfers.

Each changed binary version occupies its full size in LFS history. Deleting a
file from the current checkout does not remove its older stored versions.
Avoid committing repeated large temporary art iterations; use local authoring
backups and commit useful milestones. GitHub Pro does not increase the included
LFS allowance. Keep Actions and Codespaces outside the development workflow
unless separately budgeted.

Sources: [GitHub LFS billing](https://docs.github.com/en/billing/concepts/product-billing/git-lfs),
[pricing calculator](https://github.com/pricing/calculator), and
[budgets](https://docs.github.com/en/billing/concepts/budgets-and-alerts).

## Updating the shared toolchain

The bundle's `toolchain.json` records every file hash and the archive hash.
Rebuild, validate and activate custom engine changes using
[FidelityFX validation](FIDELITYFX.md) before replacing the bundle. Include the
matching editor, runtime dependencies, activation receipt and all license
notices. Commit the updated ZIP and manifest together. Collaborators rerun setup
after pulling to install exactly that toolchain. Never commit SDK source trees,
compiler output, credentials or machine-specific configuration from `.tools`.

## Setup verification

On September 11, 2026, a separate checkout of `38ee712` materialized its LFS
assets from the local object store, installed the bundled toolchain and completed
a fresh Godot import. The physics suite passed 56 checks and the runtime suite
passed 191 checks. The build helper produced a 10.12 GiB Windows folder.
Launching that folder's executable and PCK passed seven gameplay/rendering checks
with FSR 4.1.1 and frame generation on the RX 9070; gameplay and settings captures
were inspected. Test saves were isolated and the laboratory run was unranked.

This verifies the committed snapshot's setup and packaging on this Windows PC.
It does not establish performance or controller acceptance on another computer.
Local evidence is under `artifacts/github_collaboration_audit/` and
`artifacts/guarded/collaboration_*`; generated evidence is intentionally ignored.
