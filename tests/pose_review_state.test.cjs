const assert=require('node:assert/strict');
const model=require('../scripts/pose_review/review_state.js');
const data={evidenceId:'capture-a',poses:[{id:'p1'},{id:'p2'}],regions:[{id:'pelvis'},{id:'head'}],sequences:[{id:'s1'}]};
const initial=model.fresh(data);assert.equal(model.counts(initial).total,7);assert.equal(model.counts(initial).rated,0);
initial.records['p1.overall']={status:'scored',score:0,comment:'Zero is a real grade.'};
initial.records['p1.pelvis']={status:'unjudgeable',score:null,comment:'Occluded'};
initial.records['p1.head']={status:'scored',score:6.5,comment:'Test <script> is plain comment text'};
const restored=model.validate(JSON.parse(JSON.stringify(initial)),data);assert.deepEqual(restored,initial);assert.equal(model.counts(restored).rated,3);
assert.equal(restored.records['p2.overall'].status,'unrated');assert.equal(restored.records['p1.overall'].score,0);
assert(model.difference(8,{status:'scored',score:6}));assert(!model.difference(8,{status:'scored',score:6.5}));assert(!model.difference(null,{status:'scored',score:1}));
for(const score of [-.5,10.5,6.1,NaN,Infinity,'8']){const bad=structuredClone(initial);bad.records['p1.head'].score=score;assert.throws(()=>model.validate(bad,data));}
assert.throws(()=>model.validate(initial,{...data,evidenceId:'capture-b'}),/different capture/);
assert.throws(()=>model.validate({...initial,reviewer:'codex'},data));
assert.throws(()=>model.validate({...initial,records:{invalid:{status:'unrated',score:null,comment:''}}},data));
assert.deepEqual(initial,restored);console.log('Pose review feedback tests passed: blank/zero, half-points, unjudgeable, roundtrip, revision isolation, reviewer isolation and disagreement threshold.');
