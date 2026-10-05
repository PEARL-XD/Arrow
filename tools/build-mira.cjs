// Re-author only chapter one. Later approved boards remain byte-for-byte data equivalents.
const fs = require('node:fs');
const path = require('node:path');
const {generate} = require('./author-levels.cjs');
const E = require('./reference-engine.cjs');
const root = path.join(__dirname, '..');
const target = path.join(root, 'assets/levels.json');
const levels = JSON.parse(fs.readFileSync(target, 'utf8'));
const legacy = path.join(root, 'assets/legacy-chapter-one.json');
if (!fs.existsSync(legacy)) fs.writeFileSync(legacy, JSON.stringify(levels.slice(0,10)));
function mask(n, shape) {
  const cells=[], m=(n-1)/2;
  for(let y=0;y<n;y++) for(let x=0;x<n;x++) {
    const u=(x-m)/m, v=(y-m)/m, a=Math.abs(u), b=Math.abs(v);
    const keep = shape==='lantern' ? (a<=.72 && b<=.58 || a<=.38 && b<=1) :
      shape==='arch' ? (a*a+v*v<=1 && v<0 || v>=0 && a>=.45 && a<=.95) :
      shape==='leaf' ? (u*u/0.72 + v*v<1 && !(u>.15 && v>.55)) :
      shape==='butterfly' ? ((a-.52)**2/.21+v*v/.85<=1 || a<.15&&b<.9) :
      shape==='envelope' ? (a<=.95 && b<=.65 && !(v<-.35 && a>.7)) :
      shape==='kite' ? (a/0.85+b<=1) :
      shape==='flower' ? (Math.hypot(u,v)<.44 || [[0,-.55],[.55,0],[0,.55],[-.55,0]].some(([cx,cy])=>Math.hypot(u-cx,v-cy)<.43)) :
      shape==='key' ? (Math.hypot(u,v+.45)<.52 || a<.16&&v>-.2 || v>.6&&v<.85&&u>0&&u<.6) :
      (a<=.9 && b<=.9 && (v<-.5 || a>.55 || a<.13));
    if(keep) cells.push([x,y]);
  }
  return cells;
}
const configs=[
  ['A Little Light','lantern',11,9,.12,3],
  ['The Village Arch','arch',13,10,.16,4],
  ['Grandmother’s Garden','leaf',13,13,.2,5],
  ['Silver Wings','butterfly',15,14,.25,6],
  ['The Torn Message','envelope',15,15,.3,7],
  ['Empty Festival','kite',19,18,.4,8],
  ['Flowers in the Dark','flower',19,20,.46,9],
  ['A Key of Light','key',23,22,.5,10],
  ['Locked from Within','gate',23,24,.56,11],
  ['The Lantern Keeper','lantern',23,27,.62,12],
];
const report=[];
function author(c, index, salt=0) {
  const [name,shape,size,length,bend,depth]=c;
  let best;
  for(let j=0;j<18;j++) {
    const seed=830071+index*100003+j*7919+salt;
    const level=generate({name,shape,size,length,bend,depthBias:index*.16,
      difficulty:index<8?'Beginner':index===9?'Chapter boss':'Easy',mask:mask(size,shape)},seed);
    const m=E.validateLevel(level);
    if(Math.min(...m.directions)===0 || (index<5 && m.arrows>25)) continue;
    const score=-Math.abs(m.depth-depth)*4-m.singles*15-Math.abs(m.arrows-(8+index*2))*.3;
    if(!best || score>best.score) best={level,m,score,seed};
  }
  if(!best) throw Error(`No candidate for ${name}`);
  Object.assign(best.level,{seed:best.seed,campaignIndex:index+1,storyRevision:1});
  report.push({level:index+1,name,...best.m,solution:undefined});
  return best.level;
}
configs.forEach((c,i)=>levels[i]=author(c,i));
levels[9].isBoss=true;
levels[9].secondPhase=author(['The Heart of the Lantern','lantern',23,29,.67,14],9,991237);
levels[9].secondPhase.isBoss=true;
fs.writeFileSync(target,JSON.stringify(levels));
fs.writeFileSync(path.join(root,'docs/mira-metrics.json'),JSON.stringify(report,null,2));
console.table(report.map(({level,name,cells,arrows,depth,turns,singles})=>({level,name,cells,arrows,depth,turns,singles})));
