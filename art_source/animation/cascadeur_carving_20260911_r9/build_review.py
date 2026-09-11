"""Build the optional R9 comparison page; shared playback comes from comparison.js."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
OUT = ROOT / 'artifacts/pose_review/comparisons/cascadeur-20260911-r9'
assert not (OUT / 'sealed.json').exists()
template = (ROOT / 'artifacts/pose_review/comparisons/cascadeur-20260911-r8/review.html').read_text(encoding='utf-8')
replacements = {
    'Carving — snow pressure and legs': 'Carving — deeper leg response',
    'R8 CARVING TRIAL': 'R9 CARVING TRIAL',
    'Let the legs show the pressure': 'A deeper carve: about 17 cm',
    'The loaded ski sinks farther into soft snow, and the knees bend independently to follow the different boot heights. Both versions keep the R7 hand pose. Compare the height change during loading, then play the whole turn.':
        'R9 increases the loaded ski’s sinking into soft snow. Compare it with the previous R8 profile: the knees follow the greater boot-height difference, while both versions retain the R7 hand pose.',
    'R7 · Current snow contacts': 'R8 · Previous pressure response',
    'R8 · Pressure-dependent sinking': 'R9 · Deeper carve',
    'cascadeur-20260911-r8-01-': 'cascadeur-20260911-r9-02-',
    'Right turn, frame 54: boot world-height separation is 2.8 cm with current contacts and 12.2 cm with pressure sinking. It varies through the turn; 10 cm is not a fixed target.':
        'Right turn, frame 54: boot world-height separation is 12.6 cm with R8 and 16.7 cm with R9. During the strong turn R9 reaches 16.9 cm. Terrain and ski position can make the total gap larger later.',
    'Play Cascadeur Snow Carving.cmd': 'Play Cascadeur Deep Carving.cmd',
    'Known shared issue: poles briefly intersect clothing at frames 44–45 of the tuck-to-turn sequence in both versions.':
        'Known issues: both versions retain tuck-transition pole/clothing clipping at frames 44–45. R9 adds brief pole/trouser contacts at left-turn frame 63 and reversal frame 27. This is an optional height/feel trial; visual acceptance is still open.',
    'to compare snow contacts; the R7 hand pose stays enabled.': 'to switch R9 pressure sinking on/off; the R7 hand pose stays enabled. The videos above compare R8 with R9.',
    'These saved clips use base physics model 27, the same starting setup and steering inputs on 22 cm of snow. Sinking changes physical contact, so turn timing and balance can differ. The live project has since received model-28 snow handling; its fresh coordinate check measured 2.8 cm before / 12.6 cm after at the same sample. This movie is the preserved model-27 comparison. In game the amount depends on snow depth, load and speed; firm or very thin snow keeps the current contacts.':
        'Both saved versions use physics model 28, the same starting setup and inputs on 22 cm of snow. Changing physical contact can alter turn balance and recovery. The 17 cm target is approximate: this right-turn sequence later reaches 19.1 cm as ski position and slope contribute. Firm or very thin snow keeps current contacts. Subsequent live steering-animation edits are recorded in the handoff.',
}
for old, new in replacements.items():
    assert old in template, old
    template = template.replace(old, new)
template = template.replace('<button data-action="play">', '<button id="deep-frame">Show deep carve · frame 62</button><button data-action="play">', 1)
template = template.replace("const pair=[", "document.getElementById('deep-frame').addEventListener('click',()=>{const s=document.querySelector('.playback input');s.value='62';s.dispatchEvent(new Event('input'));});\nconst pair=[", 1)
with (OUT / 'review.html').open('x', encoding='utf-8') as f:
    f.write(template)
print(OUT / 'review.html')
