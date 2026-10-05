// Add a fixed, fully covered crown finale without regenerating any campaign board.
const fs = require('node:fs');
const path = require('node:path');
const { generate } = require('./author-levels.cjs');
const E = require('./reference-engine.cjs');
const n = 39, mid = (n - 1) / 2;
const polygon = [[-1,-.75],[-.45,-.1],[0,-1],[.45,-.1],[1,-.75],[.8,.8],[-.8,.8]];
const mask = [];
for (let y=0;y<n;y++) for(let x=0;x<n;x++) {
  const u=(x-mid)/(mid+.2),v=(y-mid)/(mid+.2);let inside=false;
  for(let i=0,j=polygon.length-1;i<polygon.length;j=i++) {
    const a=polygon[i],b=polygon[j];
    if((a[1]>v)!==(b[1]>v)&&u<(b[0]-a[0])*(v-a[1])/(b[1]-a[1])+a[0]) inside=!inside;
  }
  if(inside)mask.push([x,y]);
}
let best;
for(let i=0;i<20;i++) {
  const seed=912003+i*7919;
  const level=generate({name:'The Crown Keeper',difficulty:'Boss',shape:'crown',size:n,mask,length:42,bend:.72,depthBias:3},seed);
  const m=E.validateLevel(level);
  if(Math.min(...m.directions)<2)continue;
  const score=m.depth*3-m.singles*9-m.available*2-Math.abs(m.arrows-80)*.3;
  if(!best||score>best.score)best={level,m,score,seed};
}
if(!best)throw Error('No valid boss');
Object.assign(best.level,{isBoss:true,campaignIndex:41,seed:best.seed});
const target=path.join(__dirname,'../assets/levels.json');
const levels=JSON.parse(fs.readFileSync(target,'utf8')).filter(p=>!p.isBoss);
if(levels.length!==40)throw Error('Expected 40 existing campaign levels');
levels.push(best.level);
fs.writeFileSync(path.join(__dirname,'boss-board.json'),JSON.stringify(best.level));
fs.writeFileSync(target,JSON.stringify(levels));
fs.writeFileSync(path.join(__dirname,'../docs/boss-metrics.json'),JSON.stringify({...best.m,solution:undefined},null,2));
console.log(JSON.stringify({...best.m,solution:undefined}));
