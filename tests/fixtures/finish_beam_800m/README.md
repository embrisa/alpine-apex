# Finish beam comparison fixture

Frozen production race_beams.gd and race_beam.gdshader from the shared-main
baseline of AA-20260911-232811. Only the script's shader preload points here.
The base shader stays shared because this task does not change it.

Used explicitly by finish_beam_suite.gd to check stable start geometry/style
and race_beams_playtest.gd for matched old/proposed finish captures and timing.
This is a current visual regression comparator, not a runtime compatibility path.
Do not import it into production or silently update it with production tuning.
