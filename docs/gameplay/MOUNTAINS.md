# Player-generated mountains

The game opens on **Default Mountain, seed 849205174 / v15, Standard richness**.
The complete physical mountain is ready before skiing. Generation settings are
independent of Low/Balanced/High graphics quality.

## Creation and sharing

Open **Mountains / Create & Library**, enter a seed and choose Light (0.5x),
Standard (1x), Rich (2x), Extreme (5x), or Custom. Advanced controls independently
set tree population, mineral density, snow-feature density and landform complexity
from 0.5x to 5x. Tree spacing ranges from 0.5x to 2x and defaults to 1x. It scales
minimum separation and clearance together while retaining non-overlap, protected
drop areas and woodland openings.

The panel estimates generation, additional time to ski and peak RAM, distinguishing
available caches from fresh work. Loading displays stage progress and remaining
estimates and can be cancelled. A cancelled preview retains the previous mountain;
startup offers Retry or Quit after joining workers. Requested and achieved tree
and mineral counts expose placement saturation. One million trees is a capacity
target, not a guarantee for every natural recipe.

Name and save locally, export a compact `.apexmountain` file, or choose **Ski This
Mountain**. Full files carry all canonical settings. **Copy Seed** shares seed and
version; seed-only entry selects Standard. Incompatible schemas, versions, engine
identities and fingerprints are rejected without migrations. Mountain schema is 2,
race schema is 4, and the local mountain library uses `user://mountains_v2/`.
Names are metadata, not filesystem paths.

## Skiing and authority

The support surface remains 6,144 x 6,144 m with 4 m triangles, six faces, roughly
2 km of vertical and a 2,850 m radial return zone. Richness changes feature counts
and distribution while retaining meaningful sizes and bounded snow heights.
Mineral foundations follow the [geology contract](../world/GEOLOGY_V11.md).

At the summit choose a heading with steering, then drop onto the nearby rim at
rest. Gravity and the independent 120 Hz solver own movement. There is no racing
line attractor. Terrain, contact, tracks, seating, survey and crash geometry share
the physical grid. Cosmetic snow and distant scenery cannot change it. Free skiing
stays unranked; custom races carry the complete mountain reference and distinct
record identities. Loading preserves graphics, weather, time of day and modified
physics settings. See [wilderness rules](../world/WILDERNESS.md) and [snow traction](../world/PLANTED_SNOW.md).

## Loading and validation

V15 uses packed tree data, bounded deterministic jobs, final material/collision
caching, and separate terrain/scenery preparation caches. Recipe entries share a
2 GiB default budget with the default protected and other recipes evicted by last
use. Completed files publish atomically. Source, engine, settings and integrity
checks apply to both local and packaged caches.

See [GENERATION_V15.md](../development/GENERATION_V15.md) for implementation, measurements and
validation, and [WINDOWS_PLAYTEST.md](../development/WINDOWS_PLAYTEST.md) for export manifests
and bundles. Explicit v14/v13 APIs remain comparison fixtures; old saved recipes
are not reconstructed. Automated geometry and capacity checks do not establish
visual quality, performance-target compliance or user skiing acceptance.
