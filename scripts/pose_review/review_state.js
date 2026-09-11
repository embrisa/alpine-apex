/* Data-only feedback. This module also runs under Node for persistence tests. */
(function(root,factory){const api=factory();if(typeof module==='object'&&module.exports)module.exports=api;else root.PoseReviewState=api;})(globalThis,()=>{
  'use strict';
  const VERSION=1;
  const emptyRecord=()=>({status:'unrated',score:null,comment:''});
  function keysFor(data){return [...data.poses.flatMap(p=>[p.id+'.overall',...data.regions.map(r=>p.id+'.'+r.id)]),...data.sequences.map(s=>s.id+'.motion')];}
  function fresh(data){return {version:VERSION,evidenceId:data.evidenceId,reviewer:'user',updatedAt:null,records:Object.fromEntries(keysFor(data).map(k=>[k,emptyRecord()]))};}
  function validate(value,data){
    if(!value||value.version!==VERSION||value.reviewer!=='user')throw Error('Unsupported feedback format.');
    if(value.evidenceId!==data.evidenceId)throw Error('This feedback belongs to a different capture revision. Open that revision to review it.');
    if(!value.records||Array.isArray(value.records)||typeof value.records!=='object')throw Error('Missing feedback records.');
    const valid=new Set(keysFor(data));const result=fresh(data);
    for(const [key,record] of Object.entries(value.records)){
      if(!valid.has(key))throw Error('Unknown pose or body region: '+key);
      if(!record||!['unrated','scored','unjudgeable'].includes(record.status)||typeof record.comment!=='string'||record.comment.length>12000)throw Error('Invalid feedback for '+key);
      if(record.status==='scored'&&(!Number.isFinite(record.score)||record.score<0||record.score>10||!Number.isInteger(record.score*2)))throw Error('Scores must be 0–10 in half-points: '+key);
      if(record.status!=='scored'&&record.score!==null)throw Error('Unrated and unjudgeable scores must be empty: '+key);
      result.records[key]={status:record.status,score:record.score,comment:record.comment};
    }
    result.updatedAt=typeof value.updatedAt==='string'?value.updatedAt:null;
    return result;
  }
  function difference(agent,record){return typeof agent==='number'&&record?.status==='scored'&&Math.abs(agent-record.score)>=2;}
  function counts(state){const records=Object.values(state.records);return {rated:records.filter(r=>r.status!=='unrated').length,total:records.length};}
  return {VERSION,fresh,validate,difference,counts,keysFor};
});
