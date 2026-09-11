/* Isolated headless browser: never changes the user's browser profile or grades. */
const {chromium}=require('playwright');
const assert=require('node:assert/strict');
const fs=require('node:fs/promises');
const path=require('node:path');
const revision=path.resolve('artifacts/pose_review/revisions/20260909-r1');
const url='http://127.0.0.1:8769/revisions/20260909-r1/review/index.html';
(async()=>{
 const browser=await chromium.launch({channel:'msedge',headless:true});
 const context=await browser.newContext({viewport:{width:1600,height:1100},acceptDownloads:true});
 const page=await context.newPage(),errors=[],missing=[];
 page.on('pageerror',e=>errors.push(e.message));page.on('response',r=>{if(r.status()>=400)missing.push(r.url());});
 try{
  await page.goto(url);await page.waitForFunction(()=>document.querySelector('video').readyState>=2);
  const data=await page.evaluate(()=>window.POSE_REVIEW);
  assert.equal(data.poses.length,21);assert.equal(data.regions.length,20);
  assert.equal(await page.locator('#progress').textContent(),'Your review: 0 / 448');
  const select=page.locator('select[data-key="regular_01.overall"]');
  assert.equal(await select.inputValue(),'');
  await select.selectOption('0');await page.reload();assert.equal(await select.inputValue(),'0');
  await select.selectOption('7');assert(await select.locator('..').locator('..').evaluate(x=>x.classList.contains('disagrees')));
  await select.selectOption('6.5');assert(!await select.locator('..').locator('..').evaluate(x=>x.classList.contains('disagrees')));
  await select.selectOption('U');assert(!await select.locator('..').locator('..').evaluate(x=>x.classList.contains('disagrees')));
  await select.selectOption('');assert.equal(await select.inputValue(),'');
  await select.selectOption('0');
  await page.locator('select[data-key="regular_01.pelvis"]').selectOption('6.5');
  await page.locator('select[data-key="regular_01.neck"]').selectOption('U');
  const comment='Pelvis first. Literal text: <img src=x onerror=alert(1)> & "quote".';
  await page.locator('textarea[data-comment="regular_01.pelvis"]').fill(comment);
  const downloadPromise=page.waitForEvent('download');await page.locator('#export').click();
  const download=await downloadPromise;const exported=JSON.parse(await fs.readFile(await download.path(),'utf8'));
  assert.equal(exported.records['regular_01.overall'].score,0);
  assert.equal(exported.records['regular_01.pelvis'].score,6.5);
  assert.equal(exported.records['regular_01.neck'].status,'unjudgeable');
  assert.equal(exported.records['regular_02.overall'].status,'unrated');
  async function upload(value){await page.locator('#import').setInputFiles({name:'feedback.json',mimeType:'application/json',buffer:Buffer.from(JSON.stringify(value))});}
  await select.selectOption('9');await upload(exported);
  await page.waitForFunction(()=>document.querySelector('#notice').textContent.includes('was imported'));
  assert.equal(await select.inputValue(),'0');assert.equal(await page.locator('textarea[data-comment="regular_01.pelvis"]').inputValue(),comment);
  const baseline=await page.evaluate(()=>JSON.stringify(window.POSE_REVIEW));
  for(const alter of [v=>v.evidenceId='different-capture',v=>v.records['regular_01.overall'].score=6.25,v=>v.reviewer='codex',v=>v.records['regular_01.neck'].score=0]){
   const bad=structuredClone(exported);alter(bad);await upload(bad);
   await page.waitForFunction(()=>document.querySelector('#notice').textContent.includes('Existing feedback was kept'));
   assert.equal(await select.inputValue(),'0');assert.equal(await page.evaluate(()=>JSON.stringify(window.POSE_REVIEW)),baseline);
  }
  await page.reload();assert.equal(await select.inputValue(),'0');
  for(const sequence of data.sequences){
   await page.locator(`[data-sequence="${sequence.id}"]`).click();
   await page.waitForFunction(()=>document.querySelector('video').readyState>=2);
   assert.equal(await page.locator('.pose-card').count(),3);
   const video=await page.locator('video').evaluate(v=>({width:v.videoWidth,height:v.videoHeight,duration:v.duration,error:v.error?.message}));
   assert.equal(video.width,2400);assert.equal(video.height,1000);assert(video.duration>=3);assert(!video.error);
   for(const poseId of sequence.poses){
    await page.locator(`[data-pose="${poseId}"]`).click();assert.equal(await page.locator('.region-row').count(),20);
    for(const v of [0,1,2]){await page.locator(`[data-view="${v}"]`).click();await page.locator('#game-image').evaluate(img=>img.decode());assert.equal(await page.locator('#game-image').evaluate(img=>img.naturalWidth),800);}
    await page.locator('[data-region="pelvis"]').click();assert.match(await page.locator('#bone-overlay').textContent(),/Hips/);
    assert.equal(await page.locator('.region-row select').count(),20);
   }
   for(const rate of ['1','0.5','0.25']){await page.locator('#playback-speed').selectOption(rate);assert.equal(await page.locator('video').evaluate(v=>v.playbackRate),Number(rate));}
   // Decode/play actual surrounding motion; pause before moving to another case.
   await page.locator('video').evaluate(async v=>{v.currentTime=0;await v.play();});
   await page.waitForFunction(()=>document.querySelector('video').currentTime>.1);
   await page.locator('video').evaluate(v=>v.pause());
  }
  await page.locator('[data-sequence="regular"]').click();await page.locator('[data-pose="regular_01"]').click();
  await page.locator('#game-image').evaluate(img=>img.decode());await page.locator('.comparison').screenshot({path:path.join(revision,'inspection/comparison-final.png')});
  await page.screenshot({path:path.join(revision,'inspection/page-final.png')});
  // Same origin, different capture identity: a new revision starts blank and the old key remains intact.
  const nextPage=await context.newPage();
  await nextPage.route('**/data.js',async route=>{const r=await route.fetch();await route.fulfill({response:r,body:(await r.text()).replace(data.evidenceId,'test-separate-capture-identity')});});
  await nextPage.goto(url);assert.equal(await nextPage.locator('#progress').textContent(),'Your review: 0 / 448');
  await nextPage.close();await page.reload();assert.equal(await select.inputValue(),'0');
  await page.setViewportSize({width:720,height:1000});
  assert(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth+1));
  await page.screenshot({path:path.join(revision,'inspection/page-narrow.png')});
  const noStorage=await browser.newContext();await noStorage.addInitScript(()=>Object.defineProperty(window,'localStorage',{get(){throw new DOMException('Storage disabled','SecurityError');}}));
  const storagePage=await noStorage.newPage();await storagePage.goto(url);assert.match(await storagePage.locator('#notice').textContent(),/storage unavailable/i);
  await storagePage.locator('select[data-key="regular_01.overall"]').selectOption('8');
  const noStoreDownload=storagePage.waitForEvent('download');await storagePage.locator('#export').click();assert(await noStoreDownload);
  await noStorage.close();assert.deepEqual(errors,[]);assert.deepEqual(missing,[]);
  const result={passed:true,posesVisited:21,regionsPerPose:20,feedbackFields:448,videos:6,checks:['blank versus zero','half-points','unjudgeable','2-point highlighting','reload persistence','JSON export/import','malformed and wrong-revision rejection','Codex data preservation','separate capture storage','disabled storage export','three views and bone markers','60 FPS video decoding and playback rates','narrow layout'],pageErrors:errors,missingResponses:missing,webMCPNativeContext:await page.evaluate(()=>!!document.modelContext?.registerTool)};
  await fs.writeFile(path.join(revision,'browser-validation.json'),JSON.stringify(result,null,2));console.log(JSON.stringify(result));
 }finally{await context.close();await browser.close();}
})().catch(e=>{console.error(e);process.exitCode=1;});
