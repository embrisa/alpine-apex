I want you to develop a 3D alpine ski-racing game called **Alpine Apex**.

The game should take inspiration from the freedom, scale, atmosphere (you can look a the existing reference images in this folder to see what I kind of want), and downhill movement of games such as *Steep*, but Alpine Apex should have its own identity centered much more strongly around:

- high-speed downhill racing
- physics-driven skill expression
- procedural mountains
- player-created races
- replayability
- extremely responsive controls
- high frame rates
- a strong sensation of acceleration and speed

Do not treat this primarily as an open-world exploration game. The mountain is the playground, but **racing, mastering terrain, and finding the fastest possible line are the core of the game**.

---

# 1. Core Design Philosophy

The most important part of Alpine Apex is the skiing physics.

The game should be relatively easy to understand but have a very high skill ceiling.

A new player should be able to point downhill and ski.

An expert player should be dramatically faster because they understand how to:

- choose the best downhill line
- preserve momentum
- minimize unnecessary turning
- minimize airtime
- avoid losing contact with the snow
- carve efficiently
- use terrain intelligently
- control the skier at extremely high speeds
- pass close to trees, rocks, ravines, cliffs, and other obstacles
- anticipate terrain far ahead
- take calculated risks

The fastest theoretical route should often also be the most dangerous route.

The game should reward players for maintaining a clean, direct **fall-line-oriented trajectory** down the mountain.

The player should constantly make decisions between:

**maximum speed vs maximum control.**

---

# 2. Physics and Skill Expression

Physics are the highest gameplay priority.

Do not make skiing feel like an animation-driven character controller where the skier simply plays canned turning animations.

Movement should emerge primarily from physical variables.

Important concepts should include:

- gravity
- slope angle
- velocity
- acceleration
- ski direction
- skier direction
- edge angle
- turn radius
- friction
- lateral grip
- snow surface
- weight transfer
- terrain contact
- compression
- airtime
- landing forces
- momentum

A steep straight slope should allow the skier to accelerate to extremely high speeds.

Turning should generally cost speed.

Sharper turns should cost more speed than shallow turns.

Sliding sideways should create substantially more drag than clean carving.

Going uphill should rapidly consume momentum.

Airtime should usually be undesirable for pure racing because the player cannot accelerate from the slope while airborne.

However, small jumps and terrain transitions may allow advanced players to exploit terrain if they manage them correctly.

Landing poorly should destabilize the skier.

Large impacts should potentially cause crashes.

Terrain compression should matter. A player who understands dips, crests, transitions, and ravines should be able to maintain better snow contact and speed.

The system should create situations where a skilled player can travel at **120–150+ km/h through terrain that is extremely difficult to control**, while a less skilled player needs to slow down.

This high-speed control should be one of the central sources of skill expression.

---

# 3. The Fall Line

The concept of the **fall line** should be fundamental to the game's racing physics.

Generally, the closer the player's movement is aligned with the downhill gravitational direction of the slope, the greater their potential acceleration should be.

Players should intuitively learn:

- straight downhill = maximum acceleration
- shallow carving = small speed loss
- aggressive turning = significant speed loss
- sideways skidding = large speed loss
- uphill movement = rapid speed loss
- airtime = temporary loss of slope acceleration

Do not artificially force players onto a predefined racing line.

The terrain itself should create the racing line.

Players should discover faster routes naturally through repeated runs.

---

# 4. Speed Must Feel Dramatically Different

An extremely important goal is that different speeds should feel genuinely different.

Going 20 km/h and going 140 km/h must not feel like the same movement with a larger number on the HUD.

Design perceptual speed ranges approximately like:

### 0–30 km/h

Relaxed and highly controllable.

The player can easily make corrections.

Environmental movement feels slow.

Minimal wind.

Minimal camera effects.

### 30–60 km/h

Clearly moving quickly.

Snow begins spraying more aggressively.

Wind becomes noticeable.

Terrain passes faster.

### 60–90 km/h

Fast skiing.

Peripheral movement becomes much more noticeable.

Wind intensity increases.

The player needs to anticipate turns.

Terrain features approach quickly.

### 90–120 km/h

Very fast.

Small mistakes become dangerous.

Trees and objects produce strong peripheral motion.

Snow particles, wind, camera behavior, and audio should communicate substantial velocity.

The player must plan their line several seconds ahead.

### 120–150 km/h

Extreme racing speed.

The environment should feel like it is rushing toward the player.

Trees pass frighteningly quickly.

Terrain changes become difficult to react to.

Subtle instability and physical forces become more noticeable.

Players need excellent control and terrain awareness.

### 150+ km/h

Exceptional / extreme speed.

This should feel genuinely dangerous.

The sensation should communicate:

**"I am barely controlling this."**

Do not accomplish this only by increasing camera FOV.

Use a combination of:

- environmental parallax
- wind audio
- ski noise
- snow spray
- particle movement
- camera behavior
- subtle FOV changes
- terrain vibration
- controller vibration
- nearby-object motion
- skier animation
- snow trails
- wind distortion where appropriate
- audio pitch/intensity
- increasingly rapid terrain traversal

Effects must enhance speed without making high-level competitive gameplay visually unreadable.

Avoid excessive motion blur.

---

# 5. Camera

The camera is extremely important.

It should remain readable and controllable even at extreme speeds.

The camera should communicate:

- acceleration
- compression
- airtime
- hard carving
- impacts
- extreme velocity

Experiment with:

- dynamic but restrained FOV
- slight camera lag
- terrain-following behavior
- subtle vibration
- predictive framing
- leaning during carving
- vertical movement during compression
- landing impact response

Avoid excessive cinematic effects that interfere with competitive control.

Gameplay readability always takes priority.

---

# 6. Procedurally Generated Mountains

Players must be able to generate mountains.

Mountains should preferably be generated deterministically from a seed.

Example:

`Mountain Seed: 849205174`

Entering the same seed should reconstruct the same mountain.

Players should be able to:

- generate a random mountain
- regenerate using a seed
- save mountains locally
- name mountains
- load saved mountains
- export mountains
- import mountains
- share mountain seeds
- potentially share compact mountain files

Generated mountains should contain meaningful skiing terrain rather than pure random noise.

Possible terrain features include:

- large peaks
- ridges
- valleys
- bowls
- cliffs
- ravines
- forests
- rock formations
- open snowfields
- steep faces
- rolling hills
- narrow passages
- frozen rivers
- natural jumps
- drops
- gullies

The generator should prioritize **interesting downhill decisions**.

Terrain should create multiple possible racing lines.

Avoid mountains that feel like uniform procedural noise.

Large-scale terrain structure should make geological and visual sense.

---

# 7. Mountain Generation Parameters

Eventually allow players to influence generation parameters such as:

- mountain size
- elevation
- steepness
- snow amount
- tree density
- tree line
- cliff frequency
- ravine frequency
- valley size
- terrain roughness
- open terrain vs forest
- weather
- biome
- time of day

A simple first version can expose only a seed and a few presets.

Example presets:

- Alpine
- Extreme
- Forest
- Open
- Technical
- High Speed

---

# 8. Free Roam

Every mountain should support a Free Roam mode.

The player can start anywhere practical on the mountain and ski without an active race.

Free Roam is also where players can create races.

Players should be able to explore terrain and discover interesting racing routes themselves.

Fast restart and repositioning are important.

Avoid forcing players to repeatedly travel long distances just to retry something.

---

# 9. Player-Created Races

Players must be able to create races directly inside the world.

At minimum:

1. Enter race creation mode.
2. Select a starting position.
3. Select a finishing position.
4. Save the race.
5. Race it.
6. Share it with other players.

A race should reference both:

- the mountain
- the race definition

Example:

Mountain seed:

`849205174`

Race:

`Ravine Rush`

Start:

`X/Y/Z`

Finish:

`X/Y/Z`

Optional race features can later include:

- checkpoints
- gates
- mandatory passages
- maximum checkpoint width
- allowed equipment
- weather preset
- time-of-day preset

However, a race should NOT require checkpoints.

One of the most interesting race types should simply be:

**Start here. Finish there. Find the fastest route.**

This allows route discovery itself to become part of the competitive game.

---

# 10. Race Sharing

Races should be:

- saveable
- loadable
- exportable
- importable
- shareable

Prefer a format that can eventually support simple share codes.

A race definition should be lightweight.

If the mountain is deterministic, sharing a race may only require:

- mountain generation version
- mountain seed
- start position
- finish position
- optional checkpoints
- race rules
- weather
- time of day

Use versioned serialization formats so future updates do not unnecessarily break old mountains and races.

---

# 11. Timing and Competitive Racing

Timing should be extremely precise.

Support accurate race times down to at least milliseconds.

The game should be built with future competitive features in mind such as:

- personal bests
- local leaderboards
- online leaderboards
- ghosts
- friends' ghosts
- world records
- split times
- checkpoint comparisons
- replay files
- racing against previous runs

These systems do not all need to exist in the first prototype.

However, architecture should avoid making them unnecessarily difficult to add later.

---

# 12. Controls

Initial platforms:

- Windows
- macOS
- Linux

Input support from the beginning:

- keyboard
- PlayStation 4 controller
- PlayStation 5 controller

The input architecture should not depend on a particular controller model.

Use an abstraction that can later support:

- Xbox controllers
- Steam Input
- other standard gamepads

Controller input should support analog steering.

Possible control concepts:

Left stick:

- skier direction / weight / carving

Triggers:

- tuck / braking / edge control depending on final control design

Buttons:

- restart
- camera
- race interactions
- menu

Do not overcomplicate controls simply for realism.

The depth should primarily emerge from physics.

**Simple controls + deep physics** is preferable to complex controls + shallow physics.

---

# 13. Performance

High frame rate is a major priority.

Target responsive gameplay first.

The skiing should feel excellent at:

- 60 FPS minimum target
- 120 FPS strongly supported
- 144 FPS+
- high-refresh-rate displays

Do not tie physics behavior to rendering frame rate.

Physics must behave consistently across different frame rates.

Use fixed-step simulation or another appropriate deterministic/stable technique.

Input latency should be kept extremely low.

Profile performance continuously.

Large mountains should use techniques such as:

- terrain LOD
- mesh chunking
- distance culling
- hierarchical LOD
- GPU instancing
- efficient vegetation rendering
- asynchronous terrain generation/loading
- streaming where necessary
- pooled VFX systems

Avoid architectural choices that make 120+ FPS unrealistic.

---

# 14. Visual Direction

Visual style:

**realistic, clean, cold, dramatic alpine environments.**

The game should emphasize:

- enormous mountain vistas
- bright snow
- strong sunlight
- cold blue shadows
- atmospheric fog
- snowstorms
- low visibility weather
- golden sunrise
- orange sunset
- crisp clear alpine days
- dense forests
- wind-driven snow

The visuals should look impressive, but gameplay visibility remains important.

---

# 15. Weather

Weather should strongly influence atmosphere.

Potential conditions:

- clear
- partly cloudy
- overcast
- light snowfall
- heavy snowfall
- blizzard
- fog
- high winds

Weather can affect:

- visibility
- lighting
- snow particles
- wind
- audio
- snow surface
- potentially physics later

Do not make complex dynamic snow physics a requirement for the initial prototype.

---

# 16. VFX

VFX are important because they help sell velocity and physical interaction.

Important effects:

- ski-edge snow spray
- powder trails
- landing bursts
- windblown snow
- snow particles
- tree snow
- atmospheric fog
- cloud movement
- sunlight scattering
- snow sparkle
- trail marks

Snow spray should react to:

- speed
- edge angle
- turn sharpness
- snow type
- skidding
- landing force

At high speed, the skier should leave a visually powerful trail without overwhelming the screen.

---

# 17. Audio

Audio should contribute heavily to speed perception.

Important sounds:

- skis cutting through snow
- carving
- skidding
- powder
- wind
- jumps
- landings
- impacts
- trees rushing past
- clothing movement
- environmental ambience

Wind intensity should increase substantially with velocity.

The difference between 30 km/h and 140 km/h should be immediately recognizable even with the HUD disabled.

---

# 18. Snowboard Support

The initial focus is skiing.

However, architecture should avoid assuming that every player character must always use skis.

Snowboarding may be added later.

Separate concepts where practical:

- rider
- equipment
- movement model
- animation
- input interpretation

Do not implement snowboard physics during the first prototype unless needed.

Simply avoid architecture that would make it extremely difficult later.

---

# 19. Crashes

Crashes should occur because the physical situation becomes unsustainable rather than because the game arbitrarily decides the player has failed.

Potential crash causes:

- hitting trees
- hitting rocks
- excessive landing force
- losing balance
- extreme sideways forces
- bad edge transitions
- terrain collisions

The system should eventually produce spectacular but believable crashes.

During early development, a simple crash state is sufficient.

---

# 20. Development Priorities

Build the game incrementally.

Do NOT begin by trying to build the entire open world, multiplayer infrastructure, progression systems, menus, customization, and graphics simultaneously.

The first objective is proving that **skiing itself is fun**.

## Milestone 1 — Ski Physics Prototype

Create:

- one simple test slope
- one skier
- gravity
- acceleration
- carving
- skidding
- friction
- basic jumping
- landing
- crashing
- keyboard input
- controller input
- speedometer

The prototype should already demonstrate the central skill loop:

**Straight downhill is fast, but controlling extreme speed is difficult.**

---

## Milestone 2 — Speed Feel

Implement:

- camera response
- wind audio
- snow spray
- speed-based VFX
- controller vibration
- high-speed environmental feedback

Test specifically at:

0–30 km/h: slow / maneuvering
30–60: ordinary skiing
60–90: fast
90–120: proper racing speed
120–150: elite downhill territory
150–165: extreme World Cup-style speed
165–200: unusually extreme terrain / game-specific risk zone
200+ km/h: exceptional, basically speed-skiing territory

Each range should feel meaningfully different.

---

## Milestone 3 — Procedural Mountain Prototype

Implement:

- deterministic seed
- terrain generation
- snow surface
- cliffs/ravines
- forests
- spawn point
- regeneration
- save/load

Generate many mountains and evaluate whether they create interesting racing terrain.

---

## Milestone 4 — Race Creation

Implement:

- free roam
- set race start
- set race finish
- race timer
- restart
- finish detection
- save race
- load race
- mountain + race serialization

---

## Milestone 5 — Competitive Loop

Add:

- personal best
- ghost
- split times
- run history
- instant restart

At this point the gameplay loop should become:

Generate mountain → discover terrain → create race → race → improve line → beat personal best → share race.

---

# 21. Main Gameplay Loop

The desired long-term experience is:

1. Generate or load a mountain.
2. Explore it.
3. Find an interesting downhill route.
4. Place a race start.
5. Place a race finish.
6. Optionally place checkpoints.
7. Race the route.
8. Discover a faster line.
9. Improve technique.
10. Push higher speeds.
11. Beat your best time.
12. Share the mountain/race.
13. Compete with other players.

The key emotional experience should be:

**"I know there is another second somewhere in this mountain."**

---

# 22. Important Design Rule

Whenever there is a conflict between features, prioritize them in roughly this order:

1. Ski physics
2. Responsive controls
3. High frame rate
4. Racing depth
5. Terrain quality
6. Sense of speed
7. Race creation
8. Procedural generation
9. VFX/audio
10. Graphics fidelity
11. Secondary systems

A beautiful mountain with mediocre skiing is a failure.

A visually simple prototype with incredible skiing is a success.

---

# 23. Technical Expectations

Before implementing major systems:

- explain the proposed architecture
- identify performance risks
- identify physics risks
- keep systems modular
- avoid premature complexity
- build systems that can be tested independently
- expose important physics values for rapid tuning
- document non-obvious decisions

Important values such as these should ideally be configurable:

- gravity multiplier
- ski friction
- edge grip
- carving strength
- skidding friction
- aerodynamic drag
- maximum effective edge angle
- steering sensitivity
- landing tolerance
- snow resistance
- camera response
- speed-effect thresholds

Create debug tools early.

Useful debug information:

- current speed
- acceleration
- slope angle
- fall-line direction
- ski heading
- velocity heading
- slip angle
- edge angle
- ground contact
- airtime
- friction force
- gravity contribution
- FPS
- physics tick rate

Visual debug arrows for velocity, gravity, surface normal, and fall-line direction would be extremely useful.

---

# 24. What I Want From You

Act as the technical and game-development partner for Alpine Apex.

Do not blindly implement large amounts of code.

For each major feature:

1. Understand its gameplay purpose.
2. Propose an implementation.
3. Identify tradeoffs.
4. Implement the smallest useful version.
5. Test it.
6. Measure it.
7. Iterate.

Always preserve the game's central identity:

**Alpine Apex is a high-speed, physics-driven downhill racing game where mastering the mountain, preserving momentum, and controlling extreme speed determine who is fastest.**