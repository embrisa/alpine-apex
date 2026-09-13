# Audio

## Runtime ownership

Audio observes completed simulation and final equipment/crash presentation;
it cannot change forces, terrain, replay fields or simulation RNG. The native
implementation is [native/wind](../native/wind/), exposed by
`addons/alpine_wind`. Main and presentation controllers own lifecycle and pass
bounded controls/events. Build/dependency instructions are in [Development](DEVELOPMENT.md#wind-and-sfx).

Settings retain separate Wind and Riding modes, category gains, adaptive mix and
voice controls. F7 compares only wind; M gates all game audio. Native unavailable
selects Original with an explanatory status. Wind/riding/voice preferences live
in `wind_v1.cfg`, `riding_audio_v1.cfg` and `skier_voice_v1.cfg`. Scripted fixtures
isolate personal settings/records. Pause/loading/focus loss/restart/retirement
discard obsolete pending events; visible unfrozen crashes remain audible.
Test Cases library, controls and review use `speed_effects.silence_audio()`:
native streams fade, legacy loops become quiet, and all playback resources remain
available when riding resumes. `stop_audio()` permanently retires players and is
reserved for scene replacement or exit; it cannot serve as a temporary pause.

Thunder uses three original precomputed mono clips under `assets/audio/weather/`,
reproducible with `python scripts/tools/generate_thunder_audio.py` (fixed seeds,
24 kHz PCM, 7–9 second clips, asset peak −6 dBFS). No external source audio
or runtime synthesis is involved. `storm_effects.gd` owns three positional players
and an absolute active-time event schedule. Thunder follows Wind volume and game
mute, including with lightning Off; pause/retry/camera/mode handoffs discard pending
events. Late events beyond a bounded catch-up window are skipped. Native mixer
evidence comes from `tests/storm_audio_capture.gd`; equipment listening remains
a separate acceptance step.

## Wind DSP

`procedural_wind.gd` computes `weather.wind_velocity - sim.velocity` in the
skier support/facing frame, including switch. Camera turning has no effect.
Weather Off removes ambient wind, not motion-relative airflow. No physical wind,
shelter, occlusion or propagation simulation is added.

`AlpineWindStream.set_controls(air_m_s, tuck, gust, gain, enabled)` passes scalar
atomic targets. Each playback owns noise/filter history. Three nonresonant
filtered-noise layers provide rush, turbulence and detail; smooth random knots
avoid a short loop/sinusoidal gust. Airspeed raises level/bandwidth with saturation;
tuck reduces buffeting/high frequencies; restrained stereo retains mono coherence.
Original/procedural match RMS at upright 90 km/h in still air.

The callback uses actual engine mix rate, allocates/locks/logs nothing and accesses
no Nodes/files. Adjacent-frame mailbox fields are tolerated through sample-rate
smoothing. DC removal and soft saturation bound wind to −6 dBFS, not the combined
mix. Timing uses two monotonic reads per block; sorting/allocation stays outside.
Pause/mute gate it, scene replacement retains a fading player briefly, and
settled Original pauses native playback so A/B cost is honest. Crash wind uses
ragdoll velocity/head orientation. `diagnostics()` exposes bounded timing/state.

## Skiing, equipment and crash SFX

`AlpineSfxStream` owns two contact voices, one crash-slide layer and eight
transient slots. It synthesizes snow/rock/equipment/impacts; source wind, voice
and rain remain separate. Per-ski controls use surface-relative forward/lateral
speed, edge, load N, depth/penetration m, authoritative material and one of the
existing snow-condition IDs. Unsupported/stationary contacts release to silence.
Paired landing onsets coalesce; decaying landing-force display cannot retrigger.
Load-driven binding rattles require a fresh positive loading jolt after 120 ms
of settled pressure with unchanged support. Unloading consumes the disturbance
quietly; contact loss/recovery clears readiness. Continuing pressure oscillation
cannot retrigger, and a 500 ms minimum gap lets the 430 ms native rattle finish.
Landing/obstacle onsets suppress their associated load rattle; suppressed jolts
expire without delayed playback. Actual equipment contacts keep their own gating.

Hard impacts combine broadband compression, a short material knock and grit/bark
texture. Fixed pitched hard-impact oscillators were removed. Equipment profiles
are binding-rattle, carbon-shaft tick, metal-clink and mixed-knock. Metal uses
eight damped inharmonic modes around 5.8–14.4 kHz and tiny noise attack, with no
noise tail. The user's small-carabiner reference guided modal measurements;
its PCM is not in the game. The first lower-frequency audition was rejected as glassy.

`equipment_audio_contacts.gd` observes final pole/ski transforms through twelve
audio-only capsules, four equipment owners and six pairs. Remove whole-skier
translation before bounded relative-motion sweeps (24 advancement steps/candidate).
A conservative box around each capsule's previous/current endpoints, expanded by
its radius and the full rearm margin, rejects separated pairs before closest-point
and sweep work. Keep narrow-phase contact, closing speed, coalescing and rearm
semantics unchanged; a current-pose-only box would miss crossings between frames.
Stationary overlap is silent; closing speed must exceed .12 m/s and a pair
rearms after 80 ms clear of a 2 cm margin. Coalesce over 25 ms, preferring actual
piece contact over a same-jolt load rattle. Lifecycle, teleport, long-frame-gap
and pose-mode changes clear history. These proxies are not physical shapes.

Crash callbacks read at most four contacts per each of fifteen Jolt bodies,
without changing Jolt state. Collider metadata chooses material; terrain samples
use actual contact position. Body/collider onsets rearm after 80 ms separation;
simultaneous contacts on a collider group over 60 ms, selecting the strongest.
Another limb can onset while one remains supported. Severity bounds estimated
Jolt impulse with incoming velocity. Sustained tangential motion supplies slides.
Riding stereo is skier-relative; crash SFX uses the active camera frame.

The shared 10 Hz environment survey supplies voice and near-miss candidates.
Swishes pick confirmed passes with their own 250 ms cooldown; voice disablement
or speech cooldown cannot suppress/duplicate that survey. Adaptive mix uses the
maximum request (not summed attenuation): up to 3 dB wind reduction under strong
contact, 5 dB under impact/speech, 30 ms attack and 350 ms release. SFX ceiling is
−6 dBFS; the master has one −1 dBFS safety limiter.

### Native event contract

Bridge methods: `set_ski_controls`, `set_slide_controls`, `set_mix`, `push_event`,
`push_equipment_event`, `reset`, `diagnostics`. Exact argument order/enums live
in the native bridge and presentation callers. Pan is −1 left/+1 right;
category gains/detail are bounded 0–1. Unknown equipment profiles are rejected.

One active playback per SFX resource. Scalar atomic mailboxes carry continuous
controls; a 64-entry SPSC ring carries complete events. Overflow drops the new
event and increments a counter. Reset advances a generation, invalidating pending
events without racing cursors. Eight transient slots prioritize impacts over
equipment/swishes; modal sub-strikes stay inside those slots. Private histories
never draw simulation RNG. Diagnostics distinguish callback, contact-observer,
queue/voice-drop and sweep-exhaustion costs outside the callback.

## Voice

Runtime bank: **Alpine Apex Male 1**, ElevenLabs voice `V04rTlFwpnbuqHOMNQEj`,
model `eleven_v3`. The retained 170 clips comprise 166 scripted reactions and
four breaths; category batches are source downloads, not runtime utterances.
Ten requested variants lacked usable generation and seven cuts were withheld
for transcription mismatch. Every category retains an accepted same-voice
alternative; no unrelated-line/Liam fallback. Preserve the source manifest and
review overrides rather than regenerating uncertain cuts automatically.

Routine reactions share a 60 s gap; suppressed opportunities expire without a
queue. Category cooldowns survive local restarts. Crash/eligible-result cues
can interrupt. Flight and its landing cannot generate consecutive riding lines.
`voice_events.gd` observes ticks without Node/RNG/solver writes;
`voice_environment.gd` supplies the read-only 10 Hz survey (≤24 height samples,
≤128 obstacle candidates/update); `skier_voice.gd` owns private RNG, weighted
pools, priorities and players. Thresholds/rearm windows live in those sources.

Confirmed long air, major landing/save, impact, crash/rest, low reserve, sustained
speed, actual near miss, terrain, timed start/result and rare self-talk have
explicit triggers. Uncertain terrain suppresses cues. Small-air/ordinary clean-
landing/shared-record/race-win categories are audition-only; do not announce
unimplemented authoritative events. One reaction player and one breathing
player use fixed pitch; breathing has .28 s inter-clip gaps, recovery fades and
speech ducking. Profanity is unrestricted. Delivery/breathing/mix still need
user listening; transcription cannot establish acting quality.

## Source audio and provenance

`art_source/audio/voice/male_1_v1/` retains scripts, ledgers, original downloads,
generation IDs/hashes, cut overrides and WAV masters. The generation ledger
conservatively commits **2,992/3,000 credits** (2,187 successes + 805 reserved
against failed jobs without verified refund data); no further generation is
authorized by this documentation. Local preparation makes no paid calls.
Use the source ledger, not this historical snapshot, for any later spend decision.

`scripts/art/prepare_voice_audio.py --male-1 --analyze --propose --build`,
`audit_voice_audio.py` and `voice_delivery_report.py` use the local voice-analysis
environment. Word timestamps/silence and explicit reviewed overrides define cuts;
5/15 ms edge fades, mono 48 kHz PCM16 masters and Vorbis q6 derivatives retain
unchanged bytes. Speech targets −21 dBFS RMS/−6 peak; breaths −27/−10, selecting
the conservative gain. Runtime preloads retain export dependencies.

`art_source/audio/wind/wind_forest_01.wav` is the immutable supplied 139.52 s,
48 kHz stereo master; its manifest records hashes/preparation. Add new recordings
under distinct `wind_environment_NN` names. `prepare_wind_audio.py` refuses a
different replacement master; +24.197 dB constant gain and a 250 ms cosine loop
overlap produce the q7 runtime derivative. First playback is complete; looping
resumes at .25 s. `wind_audio.gd::forest_loop()` returns a private stream per use.
Loading uses this recording with its own player, −12 dB trim plus UI volume,
independent ambience toggle and mute/fades.

Rebuild/test commands and listening gates are in [Validation](VALIDATION.md#audio-evidence).
