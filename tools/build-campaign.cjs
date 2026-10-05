// Offline, deterministic content authoring. Every selected board is independently
// solved and checked before it enters the mobile asset pack.
const fs = require('node:fs');
const path = require('node:path');
const {generate, maskFor} = require('./author-levels.cjs');
const E = require('./reference-engine.cjs');
const approved = require('./approved-boards.json');

function mask(n, shape) {
  if (['rounded','cross','star','diamond'].includes(shape)) return maskFor(n,shape);
  const points=[], mid=(n-1)/2;
  const polygons={
    rocket:[[0,-1],[.5,-.35],[.5,.35],[.85,.85],[.35,.7],[.25,1],[-.25,1],[-.35,.7],[-.85,.85],[-.5,.35],[-.5,-.35]],
    cat:[[-.8,-1],[-.15,-.6],[.15,-.6],[.8,-1],[.85,.35],[.55,.85],[-.55,.85],[-.85,.35]],
    tree:[[0,-1],[.65,-.3],[.35,-.3],[.85,.3],[.5,.3],[1,.8],[.2,.8],[.2,1],[-.2,1],[-.2,.8],[-1,.8],[-.5,.3],[-.85,.3],[-.35,-.3],[-.65,-.3]],
    fish:[[-1,0],[-.55,-.6],[.25,-.55],[.6,-.2],[1,-.65],[1,.65],[.6,.2],[.25,.55],[-.55,.6]],
    bolt:[[.1,-1],[.75,-1],[.2,-.1],[.75,-.1],[-.65,1],[-.15,.15],[-.75,.15]],
    crown:[[-1,-.75],[-.45,-.1],[0,-1],[.45,-.1],[1,-.75],[.8,.8],[-.8,.8]],
  };
  function inside(x,y,poly) {
    let result=false;
    for(let i=0,j=poly.length-1;i<poly.length;j=i++) {
      const a=poly[i],b=poly[j];
      if((a[1]>y)!==(b[1]>y)&&x<(b[0]-a[0])*(y-a[1])/(b[1]-a[1])+a[0]) result=!result;
    }
    return result;
  }
  for(let y=0;y<n;y++) for(let x=0;x<n;x++) {
    const u=(x-mid)/(mid+.2),v=(y-mid)/(mid+.2);
    const keep=shape==='circle' ? u*u+v*v<=1 :
      shape==='heart' ? Math.pow(u*u+Math.pow(-v+.15,2)-.7,3)-u*u*Math.pow(-v+.15,3)<=0 :
      shape==='butterfly' ? (Math.pow(Math.abs(u)-.48,2)/.27+v*v/.9<=1 || Math.abs(u)<.16&&Math.abs(v)<.9) :
      shape==='ring' ? u*u+v*v<=1 && u*u+v*v>=.16 :
      shape==='hexagon' ? Math.abs(u)<.9 && Math.abs(v)+Math.abs(u)*.58<1.05 :
      inside(u,v,polygons[shape]);
    if(keep) points.push([x,y]);
  }
  return points;
}
// Composite calibration index, not a claim about measured human difficulty.
const challenge=m=>m.depth*5+m.turns*.12+m.arrows*.65+m.cells*.03+(1-m.available/m.arrows)*12;
const shapeList=['rounded','circle','diamond','heart','cross','hexagon','cat','rocket',
  'butterfly','fish','tree','star','crown','bolt','ring'];
const names={rounded:'Weave',circle:'Orbit',diamond:'Prism',heart:'Heartbeat',cross:'Crossroads',
  hexagon:'Honeycomb',cat:'Whiskers',rocket:'Liftoff',butterfly:'Wings',fish:'Current',
  tree:'Evergreen',star:'Starlight',crown:'Royal maze',bolt:'Spark',ring:'Halo'};
const generated=[];
for(let i=0;i<35;i++) {
  const t=i/34, shape=shapeList[i%shapeList.length];
  let size=Math.round(10+t*29);
  // Thin silhouettes need additional grid resolution, not a rectangular backdrop.
  if(['star','bolt','fish','tree','rocket'].includes(shape)) size+=6;
  const cfg={name:names[shape],shape,size,mask:mask(size,shape),length:Math.round(7+t*29),
    bend:.1+t*.68,depthBias:t*2.5,difficulty:''};
  let best;
  const target=22+t*210;
  for(let j=0;j<12;j++) {
    const seed=500003+i*100003+j*7919;
    const level=generate(cfg,seed), m=E.validateLevel(level);
    if(Math.min(...m.directions)===0) continue;
    const score=-Math.abs(challenge(m)-target)-m.singles*9;
    if(!best||score>best.score) best={level,m,score,seed};
  }
  if(!best) throw Error(`No valid candidate for ${shape}`);
  best.level.seed=best.seed;generated.push(best.level);
  console.log(`Authored ${i+1}/35 ${shape} ${best.m.arrows} arrows, depth ${best.m.depth}, ${best.m.singles} singles`);
}
const levels=[...generated,...approved].map(level=>({level,m:E.validateLevel(level)}))
  .sort((a,b)=>challenge(a.m)-challenge(b.m));
const usedNames=new Map();
const report=[];
levels.forEach(({level,m},i)=>{
  const count=(usedNames.get(level.name)||0)+1;usedNames.set(level.name,count);
  if(count>1) level.name+=` ${count}`;
  level.difficulty=i<8?'Beginner':i<16?'Easy':i<24?'Medium':i<32?'Hard':'Expert';
  level.campaignIndex=i+1;
  report.push({level:i+1,name:level.name,shape:level.shape,difficulty:level.difficulty,
    ...m,solution:undefined,challenge:Number(challenge(m).toFixed(2))});
});
const boss = require('./boss-board.json');
E.validateLevel(boss);
fs.writeFileSync(path.join(__dirname,'../assets/levels.json'),JSON.stringify([...levels.map(x=>x.level),boss]));
fs.mkdirSync(path.join(__dirname,'../docs'),{recursive:true});
fs.writeFileSync(path.join(__dirname,'../docs/level-metrics.json'),JSON.stringify(report,null,2));
console.table(report.map(({level,name,cells,arrows,depth,turns,challenge})=>({level,name,cells,arrows,depth,turns,challenge})));
