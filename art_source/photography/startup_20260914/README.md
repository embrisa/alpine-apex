# Startup photographs

These six JPEG masters were supplied in Downloads by the user on 2026-09-14.
Their bytes are preserved. Photographer/provider names and source IDs are retained
from those supplied filenames; no specific mountain location is asserted.

The authoritative runtime/provenance ledger is
[`assets/images/startup/manifest.json`](../../../assets/images/startup/manifest.json).
It records original and prepared SHA-256 hashes, sizes, credits and provider links.
The [Unsplash license](https://unsplash.com/license) and
[Pexels license](https://www.pexels.com/license/) permit use in applications;
individual image-page retrieval was unavailable in the automated browser. These
landscape photographs are background content, separate from the original logo.

Rebuild with a Python environment containing Pillow:

```powershell
python scripts/art/prepare_startup_photos.py
```

Preparation applies EXIF orientation and proportional downsampling within
3840 x 2160, then JPEG quality 90 with 4:4:4 chroma. It never crops or generates
image content. Run the repository's guarded editor import after changes, then
rerun preparation once to retain lossless GPU imports with mipmaps and import
again if descriptors changed. Existing descriptor UIDs are preserved.

Each launch selects one image with a private presentation RNG. Only that texture
is loaded and shared between opening and loading; the game remains offline.
