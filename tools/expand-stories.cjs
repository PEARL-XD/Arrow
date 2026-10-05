// Deterministic content authoring: twenty genuinely new fully occupied boards.
// The archived v0.8 pack is the input; never expand an already-expanded pack.
const fs = require('node:fs');
const path = require('node:path');
const {generate} = require('./author-levels.cjs');
const E = require('./reference-engine.cjs');
const root = path.join(__dirname, '..');
const old = JSON.parse(fs.readFileSync(path.join(root,'assets/legacy-campaign-v08.json'),'utf8'));
if(old.length !== 41) throw Error('Expected archived 41-board campaign');
const additions = [
  [['Lantern Steps','lantern',13],['Petal Passage','flower',15],['Festival Ribbon','ribbon',17],['A Waiting Flame','lantern',21],['The Glass Threshold','arch',23]],
  [['A Still Fountain','fountain',21],['The Silver Petal','flower',23],['Ribbon Around the Roots','ribbon',25],['The Sleeping Greenhouse','arch',27],['A Breath of Spring','flower',29]],
  [['A Ticket for Midnight','ticket',29],['The Crooked-Eared Rabbit','rabbit',31],['Three Missing Notes','note',33],['One Minute to Midnight','clock',35],['An Honest Melody','note',37]],
  [['The Rose Road','flower',35],['Things Carried Home','lantern',37],['Whispers Under the Arch','arch',39],['A Promise in the Dark','ribbon',41],['A Place at the Table','heart',43]],
];
const offsets=[0,1,3,4,6,7,9,11,13,14];
const slots=[2,5,8,10,12];
const bossNames=['The Lantern Keeper','The Thorn Crown','The Clockwork Maestro','The Shadow Weaver'];
function mask(n,shape) {
  if(shape==='heart') {
    const cells=[],m=(n-1)/2;
    for(let y=0;y<n;y++) for(let x=0;x<n;x++) {
      const u=(x-m)/(m+.2),v=(y-m)/(m+.2);
      if((u*u+(-v+.15)**2-.7)**3-u*u*(-v+.15)**3<=0) cells.push([x,y]);
    }
    return cells;
  }
  const cells=[],m=(n-1)/2;
  for(let y=0;y<n;y++) for(let x=0;x<n;x++) {
    const u=(x-m)/m,v=(y-m)/m,a=Math.abs(u),b=Math.abs(v);
    const keep=shape==='lantern' ? (a<=.72&&b<=.58||a<=.38&&b<=1) :
      shape==='flower' ? (Math.hypot(u,v)<.44||[[0,-.55],[.55,0],[0,.55],[-.55,0]].some(([cx,cy])=>Math.hypot(u-cx,v-cy)<.43)) :
      shape==='arch' ? (u*u+v*v<=1&&v<0||v>=0&&a>=.45&&a<=.95) :
      shape==='ribbon' ? (a<.34||b>.52&&a<.85&&b<.84) :
      shape==='fountain' ? (v<-.45&&a<.2||v>=-.45&&v<-.25&&a<.7||v>=-.25&&v<.3&&a<.2||v>=.3&&b<.75&&a<.9) :
      shape==='ticket' ? (a<.95&&b<.65&&!(a>.75&&b<.2)) :
      shape==='rabbit' ? (u*u+((v-.35)/.65)**2<.8||v<-.05&&v>-.98&&a>.2&&a<.48) :
      shape==='note' ? (Math.hypot((u+.4)/.6,(v-.55)/.4)<1||u>.02&&u<.24&&v>-.9&&v<.6||v<-.62&&v>-.9&&u>.02&&u<.8) :
      shape==='clock' ? (u*u+v*v<.95) : false;
    if(keep) cells.push([x,y]);
  }
  return cells;
}
const result=[],report=[];
for(let c=0;c<4;c++) {
  const chapter=Array(15);
  for(let s=0;s<10;s++) chapter[offsets[s]]=structuredClone(old[c*10+s]);
  for(let j=0;j<5;j++) {
    const [name,shape,size]=additions[c][j],local=slots[j],progress=(c*15+local)/59;
    let best;
    for(let trial=0;trial<10;trial++) {
      const seed=912047+c*1000003+j*7919+trial*131071;
      const level=generate({name,shape,size,mask:mask(size,shape),length:9+progress*30,bend:.15+progress*.62,depthBias:progress*2.4,
        difficulty:c===0?(local<8?'Beginner':'Easy'):c===1?'Medium':c===2?'Hard':'Expert'},seed);
      const m=E.validateLevel(level);
      if(Math.min(...m.directions)===0) continue;
      const score=-m.singles*20-Math.abs(m.depth-(4+progress*22))*3;
      if(!best||score>best.score) best={level,m,score,seed};
    }
    if(!best) throw Error(`No candidate for ${name}`);
    chapter[local]={...best.level,seed:best.seed};
    console.log(`New ${c+1}.${local+1}: ${name}, ${best.m.cells} dots, ${best.m.arrows} arrows`);
  }
  chapter[14].name=bossNames[c];chapter[14].isBoss=true;chapter[14].difficulty='Chapter boss';
  for(let local=0;local<15;local++) {
    const level=chapter[local];level.campaignIndex=c*15+local+1;level.storyRevision=2;
    const m=E.validateLevel(level);
    if(level.secondPhase) E.validateLevel(level.secondPhase);
    report.push({level:level.campaignIndex,name:level.name,shape:level.shape,...m,solution:undefined});
    result.push(level);
  }
}
result.push({...old[40],campaignIndex:61,storyRevision:2});
E.validateLevel(result[60]);
fs.writeFileSync(path.join(root,'assets/levels.json'),JSON.stringify(result));
fs.writeFileSync(path.join(root,'docs/campaign-v1-metrics.json'),JSON.stringify(report,null,2));
