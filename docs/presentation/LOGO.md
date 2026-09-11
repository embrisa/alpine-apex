# Alpine Apex vector logo

The master is [`assets/images/branding/alpine_apex.svg`](../../assets/images/branding/alpine_apex.svg).
It is drawn directly as named, editable SVG paths, including every letter and
letter counter. There are no font dependencies, embedded bitmaps, tracing,
gradients, bevels, textures or generated imagery.

The design retains the original mountain and nested summit chevrons. A small
number of snow faces defines the ridge. Two open chevrons repeat its slope;
their negative space stays separate from the snow face. The custom uppercase
lettering uses extended 100-unit caps, a 12-degree forward rake, chamfered P
bowls, clipped E/L terminals, and a directional X. Each A repeats the summit
chevron with a separate inset snow peak; it is drawn as two filled contours.
The word gap is wider than the inter-letter spacing. Colors match the interface:
snow `#EDF4F8`, ice `#A5DCED`, and a restrained ridge shadow `#42657A`.

| Asset in `assets/images/branding/` | Use |
| --- | --- |
| `alpine_apex.svg` | Editable geometry master and clean alternative, 1440 × 640 |
| `alpine_apex_compact.svg` | Settings and skiing header, 1120 × 180 |
| `alpine_apex_light.svg` | One light ink on a dark background |
| `alpine_apex_dark.svg` | One dark ink on a light background |
| `alpine_apex_mark.svg` | Standalone summit symbol, 128 × 128 |
| `alpine_apex_ice.svg` | Approved main title and loading logo, 1440 × 640 |

The compact logo uses an optically simplified summit drawing with wider open
spaces. It keeps the full wordmark readable at a 315-pixel UI width. The same
symbol supplies the actual project's `icon.svg`, replacing the default Godot
icon. The separate historical `assets/icon.svg` is not used by project startup.

Use the full logo at 400 logical pixels or wider, the compact logo at 225 pixels
or wider, and the symbol alone below that. Keep at least half a letter's cap
height clear around the lockup. Preserve aspect ratio. The full color logo is
intended for the game's dark reading areas; use the dark variant on light art.

Godot imports the SVGs as ordinary lossless textures with mipmaps. The title's
1440-pixel source width exceeds its 1248-pixel display width at the existing
4K/900-logical-height layout. No per-frame SVG rendering or logo material is
needed. The original PNG and its historical fringe-cleanup shader remain
preserved, but the shared logo factory no longer loads them.

## Editing and export

Edit the master in a vector editor or edit its named paths directly. Then run:

```powershell
python scripts/art/prepare_logo.py
python scripts/art/prepare_logo_texture.py
./godotw.ps1 --headless --editor --import
python scripts/art/prepare_interface_art.py
./godotw.ps1 --headless --editor --import
./godotw.ps1 --script scripts/art/review_logo.gd
```

Use the project's guarded runner for native review and run it when other
benchmark workloads finish. `review_logo.gd` exports transparent 2× PNGs to
`artifacts/logo/` and captures the actual title, compact settings header and
loading layouts. It uses the real UI with muted sound, isolated preferences,
and no mountain generation or personal-best session. A headless invocation
exports PNGs only. Outputs are disposable; the SVG master is the source.

## Validation

On 2026-09-08, the existing headless interface art review passed 104/104 checks
after the shared logo factory and header integration changed. The subsequent
lettering revision uses the same runtime integration. Its final guarded SVG
import and native UI review both exited successfully with no engine errors.

`artifacts/logo/review.json` records ten native RX 9070 captures: title and
settings at 1280 × 720, 1440 × 900 and 3840 × 2160, plus two loading compositions
at 720p and 4K. Inspected captures retain readable lettering, open chevrons and
clear space between the logo and adjacent controls. The exported primary PNG
is 2880 × 1280 RGBA; the background, A opening and P counter have zero alpha.

These checks concern the logo and its actual UI placement. They do not
establish skiing feel, a frame-rate benchmark, or the user's aesthetic approval.

## Approved fractured-ice finish

`python scripts/art/prepare_logo_texture.py` derives a separately named SVG from
the clean master. Explicit polygon rock strata follow the mountain faces;
smaller fractures sit inside the snow. Deterministic polygon flecks add frost.
Each letter has a separate clip region for lighter grain and shallow ice seams.
The shapes, letter openings, proportions and outer silhouette stay the same.
All texture is static vector geometry, with no bitmap, filter or shader.

The full logo is the useful place for this treatment. The small header and app
icon retain their clean drawing. The user approved the textured finish on
2026-09-08; it is now the default title and loading logo. To export and review it
in the actual title and loading UI after importing its SVG, run the guarded equivalent
of:

```powershell
./godotw.ps1 --script scripts/art/review_logo.gd '--' --logo-ice
```

The resulting transparent PNG is `artifacts/logo/alpine_apex_ice_transparent.png`;
native captures and the report use the `ice_` prefix. The shared title/loading
factory loads this SVG directly, without a runtime texture effect.

The guarded alternative import and native review passed on 2026-09-08 with no
engine errors. Ten UI captures and a 2880 × 1280 transparent PNG were produced.
The A opening, P counter and background retain zero alpha; no texture pixels
extend beyond the clean silhouette's one-pixel antialias margin. The comparison
sheet is `artifacts/logo/clean_vs_ice.png`.
