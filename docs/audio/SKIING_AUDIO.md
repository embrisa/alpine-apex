# Procedural skiing and crash audio

The existing Windows wind addon also supplies `AlpineSfxStream`: two independent
ski/contact voices, one crash-slide layer and eight bounded transient voices.
All new sound is synthesized; no recordings or external audio service is used.
The existing wind synthesis, source recording, voice library and rain remain.

## Playing and tuning

Settings → Audio contains Wind and Riding sound modes, wind volume, Snow,
Impacts, Equipment and Near-miss gains, and Adaptive mix. F7 still compares only
wind. Riding Original uses the original ski/edge loops and disables new SFX.
Missing native support also selects that fallback with an explanatory status.
M mutes game audio. New preferences use `user://riding_audio_v1.cfg`; existing
wind and voice preference files are retained. Scripted fixtures do not use or
write personal preferences or records.

Snow is driven per ski by surface-relative velocity, lateral slip, edge angle,
load in Newtons, snow depth and penetration in metres, and authoritative material.
The existing six snow-condition profiles shape brightness and granular texture;
they add no physical surface types or terrain generation. Rock scraping is a
separate timbre. Stationary and unsupported contacts release to silence.
Fresh paired landings form one compression impact; the decaying landing-force
display cannot retrigger it. Equipment detail follows rapid supported load changes.

## Natural equipment contacts and hard impacts

Rock, tree and generic hard impacts use a broadband compression thud, a short
material knock and a brief grit/bark contact texture. The former fixed pitched
impact oscillators are removed from these materials. Snow impacts retain their
existing synthesis. Incoming contact speed controls strength and brightness.

Equipment has four audio profiles: binding rattle, carbon-shaft tick, metal
clink and mixed equipment knock. Metal clinks use eight damped, inharmonic modes
at approximately 5.8–14.4 kHz. Frequencies, relative strengths and decay times
were guided by measurements of the user's downloaded small-carabiner reference;
the game synthesizes these modes and includes no PCM from that recording. The
first lower-frequency audition was revised after the user described it as glassy.
Rattles excite a short, irregular sequence of the same metal modes, with reduced
strength and shorter decays; metal profiles have a tiny noise attack and no noise tail.

`equipment_audio_contacts.gd` reads the final rendered pole/ski poses during
riding and visible, unfrozen crashes. Twelve audio-only capsule segments describe
carbon shafts, metal tips/edges/fittings and composite ski surfaces, with four
equipment owners and six possible owner pairs. These are approximate acoustic
proxies, not new physical collision shapes. Whole-skier translation is removed
before a swept relative-motion test, bounded to 24 conservative-advancement steps
per candidate. Stationary overlaps stay quiet. Relative closing speed must exceed
0.12 m/s; an owner pair rearms after 80 ms clear of a 2 cm separation margin.
The controller coalesces events over 25 ms and prioritizes actual piece-to-piece
contact over a same-jolt load-change rattle.

Pause/mute, teleports, long frame gaps, restarts, crash handovers and motion-mode
changes clear equipment histories and pending sounds. The observer cannot change
poses, joints, collision shapes, forces, simulation randomness or recordings.
The existing Equipment gain controls all four profiles; settings are unchanged.

The shared 10 Hz presentation survey supplies both voice candidates and near-miss
metadata. Swishes select the closest confirmed pass, retain the original query
and clearance budgets, and use a separate 250 ms cooldown. Voice enablement and
speech cooldowns cannot suppress or duplicate the survey.

During crashes, the existing fifteen physical bones report at most four contacts
each. The capture callback only reads Jolt state. Actual collider metadata selects
snow, rock, wood or generic hard contact. Terrain contacts sample the authoritative
material and depth at the contact position. Contact onset per body/collider is
rearmed after 80 ms separation; simultaneous contacts on one collider group over
60 ms, selecting the strongest impact. A new limb can strike while another limb
remains on the ground. Sliding follows sustained tangential motion. Jolt contact
impulses are estimates, so severity also uses incoming contact velocity and bounds
the impulse contribution. No joints, collision geometry or forces are changed.

Riding uses restrained skier-relative stereo. Crash impacts/sliding use the
presentation camera's frame. Crash wind uses current ragdoll motion/head orientation.
Visible, unfrozen crashes remain audible after skiing stops; hidden menus, loading,
pause, focus loss, restart, retirement and frozen ragdolls fade and discard events.

Adaptive mixing reduces wind by up to 3 dB under strong contact and 5 dB for impacts
or speech, with a 30 ms attack and 350 ms recovery. Requests use their maximum,
not their sum. Native output removes DC and softly bounds at −6 dBFS; the master
bus has a single −1 dBFS safety limiter. Normal mix levels leave headroom.

## Native interface and thread ownership

The DLL name, GDExtension entry point, `AlpineWindStream` API and dependency pin
are preserved. `AlpineSfxStream` adds:

- `set_ski_controls(index, forward_m_s, lateral_m_s, edge_radians, load_n,
  depth_m, penetration_m, condition, material, supported)`.
- `set_slide_controls(speed_m_s, intensity, pan, material, condition)`.
- `set_mix(Vector4(snow, impacts, equipment, near_miss), enabled)`.
- `push_event(kind, material, speed_m_s, pan, detail) -> bool`.
- `push_equipment_event(profile, speed_m_s, pan, detail) -> bool`.
- `reset()` and `diagnostics()`.

Event kinds are landing=0, impact=1, equipment=2, near-miss=3. Audio materials
are snow=0, rock=1, wood=2, generic=3. Conditions retain `snow_condition.gd` IDs.
Pan is −1 left to +1 right; detail and category gains are bounded 0–1.
Equipment profile IDs are binding-rattle=0, shaft-tick=1, metal-clink=2 and
mixed-knock=3. Existing `push_event(EQUIPMENT, ...)` calls remain valid and select
binding rattles. Unknown profile IDs are rejected by the new bridge. Old DLLs
can still receive generic equipment events while a replacement is staged.

One active playback is allowed per SFX resource. Scalar atomic mailboxes carry
continuous controls; a 64-entry single-producer/single-consumer ring carries
complete events. Overflow drops the incoming event and increments a counter.
Reset advances a generation, invalidating pending events without racing queue
cursors. Each playback owns its random/filter histories; no simulation RNG or
replay state is used. Callback work allocates nothing, locks nothing, and accesses
no Nodes, files or logging. Eight transient slots prioritize impacts above equipment
and swishes. Diagnostics expose callback p99, events, queue/voice drops, contact
report counts, per-bone capture timing and observation costs outside the callback.
Equipment diagnostics additionally expose submitted/contact counts, observer
maximum time and sweep-budget exhaustion. Modal ringing and sub-strikes stay
inside the same eight transient slots and respect reset generations/voice priority.

## Current equipment/impact validation

```powershell
./scripts/build_wind.ps1 -Test
.tools/wind/build/Release/sfx_dsp_test.exe artifacts/natural_audio/after/offline
./godotw.ps1 --headless --script tests/equipment_audio_suite.gd
./godotw.ps1 --headless --script tests/sfx_audio_suite.gd
./godotw.ps1 --headless --script tests/sfx_audio_suite.gd '--' --sfx-disable-native
./godotw.ps1 --script tests/natural_audio_playtest.gd
./godotw.ps1 --script tests/sfx_lab_playtest.gd '--' --quiet-audio
./godotw.ps1 --script tests/natural_audio_benchmark.gd '--' --version=13 --benchmark-label=natural_audio_after_quiet --benchmark-resolution=3840x2160 --graphics-quality=high --render-scale=0.75 --upscaler=fsr2 --fps-limit=120 --terrain-gi=off --ui-staged-loading
```

Run engine workloads sequentially through the guarded runner. The new benchmark
uses the validated shared v13 cache and two fixed-pose sites in the full rendered
mountain, with repeated native impacts/equipment sounds. It measures audio cost,
not traversal or a minimum FPS floor. Performance fixtures mute only their output
bus; device callbacks still run. The rendered audition records the bus before
that output gain so review remains user-controlled. No personal records or audio
preferences are written. An already running game keeps its loaded DLL; a newly
installed binary takes effect on the next launch.

Current auditions, source hashes and measured validation are in
`artifacts/natural_audio/AUDITIONS.md` and `validation.json`. Signal and contact
checks, rendered/device evidence, isolated performance and user listening/skiing
acceptance are separate. The older reproduction commands below retain their
explicit v12 fixtures and are not the default v13 benchmark.

## Reproducing evidence

```powershell
./scripts/build_wind.ps1 -Test
.tools/wind/build/Release/sfx_dsp_test.exe artifacts/sfx/offline
./godotw.ps1 --headless --script tests/sfx_audio_suite.gd
./godotw.ps1 --headless --script tests/sfx_audio_suite.gd '--' --sfx-disable-native
./godotw.ps1 --headless --script tests/sfx_ragdoll_suite.gd
./godotw.ps1 --script tests/sfx_device_playtest.gd
./godotw.ps1 --script tests/sfx_lab_playtest.gd
./godotw.ps1 --script tests/sfx_settings_playtest.gd
./scripts/benchmark_sfx.ps1 -Mode original
./scripts/benchmark_sfx.ps1 -Mode procedural
./scripts/benchmark_sfx.ps1 -Mode procedural -Capture
```

Builds never close existing applications; an engine holding the DLL must finish
before the binary can be installed. Keep other GPU/encoding/build jobs out of
matched timing windows. Benchmarks use unranked v12 terrain at 3840×2160 output,
High, 75% FSR2, 120 FPS cap and GI off. Captures include readback overhead and
are separate from timing evidence. The scripted crash is labelled as a fixture. The shorter laboratory capture defaults
to 1920×1080 (`--audio-capture-4k` requests 4K); the UI-only capture is 4K.

A short 1080p laboratory recording and a separate 4K settings capture completed;
neither substitutes for the requested full-mountain comparison.

Acceptance separates automated signal/behavior checks, rendered/device evidence,
hardware performance and user listening/skiing. Auditions and recorded PCM cannot
establish long-session comfort. See `artifacts/sfx/VALIDATION.md` for the measured
results and any remaining gates for this working tree.
