# Development priorities

Alpine Apex already has six-face generated mountains, summit free skiing,
mountain libraries and sharing, open-route race authoring, local personal bests
and ghosts, weather, procedural audio, and an articulated skier. Current defaults
are mountain v14 and the versioned custom ski solver. The laboratory remains a controlled test tool.

## Improve the game within Godot

Follow [the engine and performance strategy](ENGINE_STRATEGY.md) throughout
development. Improve the subsystem being touched using current measurements:
reduce repeated work, use packed data, cache reusable preparation, schedule
bounded jobs and introduce native C++ where it produces a useful gain. Record
completed improvements and the next evidenced bottleneck in the subsystem page
so later tasks can continue from the actual result.

Generation/loading and terrain/forest preparation are recurring opportunities;
deeper simulation or renderer changes depend on their measured cost. The strategy
lists investigation targets and acceptance measures, without committing every
task to a rewrite. Godot source changes remain available when extension APIs are
insufficient. A full custom runtime and speculative portability infrastructure
are outside the current roadmap. Performance work supports the acceptance
priorities below and continues alongside ordinary features.

## Finish acceptance of the current game

1. **Skiing feel.** Playtest turn initiation, sustained carving, reversals,
   tuck-to-turn transitions, jumps, switch skiing and forgiving clean landings.
   Test keyboard and actual controllers; verify dead zones, triggers and haptics.
2. **Mountain routes.** Survey and ski all six faces and multiple seeds. Routes
   should split, rejoin, narrow and open up while snow remains dominant. The v13
   branching survey passes, but its test pilot still crashes/stalls on several
   faces. One completed route is not mountain-wide skiing acceptance.
3. **PC performance.** Measure complete descents on the current mountain and
   dense forests on the target Ryzen 5 5600X / RX 9070 / 16 GB PC at 4K High.
   Frame p95/p99, rendering CPU/GPU cost, loading and memory need separate evidence.
   Historical shared-load v13 runs missed the full frame-time gate; use the newer
   [FPS procedure and results](FPS_OPTIMIZATION.md) for current investigation.
4. **Presentation comfort.** Review continuous motion, knee/boot fitting, deep
   tuck, chase/first-person readability, live menu transitions and reduced motion.
   Listen to the natural/readable skiing, crash, wind and reaction mix in play.
5. **Racing loop.** Confirm route discovery, race authoring, retries, splits and
   ghost readability are useful during ordinary player runs.

Automated, rendered, performance, listening and player acceptance are distinct.
See [validation](VALIDATION.md) and the relevant subsystem documents for methods.
Do not use old screenshots or passing laboratory tests as a current acceptance claim.

## Later increments

Expand mountain families, authoring controls, spawn options and optional race
rules only through scoped work. Add streaming or background scene construction
when measurements justify it. Keep open-route races available without mandatory
checkpoints, and preserve the authoritative 4 m support surface.

[Online competition](ONLINE_COMPETITION.md) records future options: local mastery,
friend ghosts and leaderboards, shared challenges and eventual private group
skiing. Movement stays responsive and local; solo play stays offline-capable.
Dedicated movement servers depend on demand and funding. This direction does not
authorize speculative networking or backend work.

Snowboarding belongs in a separate movement/equipment model over shared rider
input and terrain contracts. Physics, response, racing depth and frame rate
continue to take priority over extra systems.
