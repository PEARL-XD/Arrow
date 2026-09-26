// Offline authoring. The browser loads fixed, validated level data; no random fallback.
const E = require('./reference-engine.cjs');
const { DIRS, key } = E;
function rng(seed) { return () => { seed = (Math.imul(seed, 1664525) + 1013904223) >>> 0; return seed / 4294967296; }; }
function maskFor(n, shape) {
  const result = [], mid = (n - 1) / 2;
  const vertices = Array.from({length: 10}, (_, i) => {
    const a = -Math.PI / 2 + i * Math.PI / 5, r = (i % 2 ? .49 : 1) * (mid + .6);
    return [mid + Math.cos(a) * r, mid + Math.sin(a) * r];
  });
  function inStar(x,y) {
    let inside = false;
    for (let i=0,j=9;i<10;j=i++) {
      const a=vertices[i],b=vertices[j];
      if ((a[1]>y)!==(b[1]>y) && x<(b[0]-a[0])*(y-a[1])/(b[1]-a[1])+a[0]) inside=!inside;
    }
    return inside;
  }
  for(let y=0;y<n;y++) for(let x=0;x<n;x++) {
    const dx=Math.abs(x-mid),dy=Math.abs(y-mid);
    const keep = shape==='star' ? inStar(x,y) : shape==='cross' ? dx<=mid*.48||dy<=mid*.48
      : shape==='diamond' ? dx+dy<=mid+1 : shape==='rounded' ? Math.hypot(Math.max(0,dx-mid*.65),Math.max(0,dy-mid*.65))<=mid*.35+.1 : true;
    if(keep) result.push([x,y]);
  }
  return result;
}
function generate(config, seed) {
  const random=rng(seed), n=config.size, mask=config.mask || maskFor(n, config.shape), left=new Set(mask.map(key)), paths=[], removedOwners=new Map(), depths=[];
  const neighbors=c=>DIRS.map(d=>[c[0]+d[0],c[1]+d[1]]);
  while(left.size) {
    const heads=[];
    for(const k of left) {
      const c=k.split(',').map(Number);
      DIRS.forEach(([dx,dy],direction)=>{
        for(let x=c[0]+dx,y=c[1]+dy;x>=0&&y>=0&&x<n&&y<n;x+=dx,y+=dy) if(left.has(key([x,y]))) return;
        heads.push({c,direction});
      });
    }
    let best=null;
    const desired = 2 + Math.floor(Math.pow(random(), .65) * config.length);
    for(let attempt=0;attempt<80;attempt++) {
      const head=heads[Math.floor(random()*heads.length)], [dx,dy]=DIRS[head.direction];
      const cells=[head.c], taken=new Set([key(head.c)]);
      const second=[head.c[0]-dx,head.c[1]-dy];
      if(left.has(key(second))) {cells.push(second);taken.add(key(second));}
      while(cells.length>1 && cells.length<desired) {
        const last=cells.at(-1),prev=cells.at(-2);
        const options=neighbors(last).filter(c=>left.has(key(c))&&!taken.has(key(c)));
        if(!options.length) break;
        const scores=options.map(c=>{
          const straight=c[0]-last[0]===last[0]-prev[0]&&c[1]-last[1]===last[1]-prev[1];
          const degree=neighbors(c).filter(v=>left.has(key(v))&&!taken.has(key(v))).length;
          return {c,score:random()*2+(straight?1-config.bend:config.bend)*2+(degree===1?.6:0)};
        }).sort((a,b)=>b.score-a.score);
        cells.push(scores[0].c);taken.add(key(scores[0].c));
      }
      let lonely=0;
      const touched=new Set(cells.flatMap(neighbors).map(key));
      for(const k of touched) if(left.has(k)&&!taken.has(k)) {
        if(!neighbors(k.split(',').map(Number)).some(c=>left.has(key(c))&&!taken.has(key(c)))) lonely++;
      }
      const p={id:paths.length,cells:[...cells].reverse(),direction:head.direction};
      let depth=1;
      for(let x=head.c[0]+dx,y=head.c[1]+dy;x>=0&&y>=0&&x<n&&y<n;x+=dx,y+=dy) {
        const owner=removedOwners.get(key([x,y]));
        if(owner!==undefined) depth=Math.max(depth,depths[owner]+1);
      }
      const score=cells.length - lonely*25 - (cells.length===1?60:0) + Math.min(E.turns(p),6)*config.bend + Math.min(depth,30)*config.depthBias + random()*.5;
      if(!best||score>best.score) best={...p,score,depth};
    }
    best.cells.forEach(c=>{left.delete(key(c));removedOwners.set(key(c),best.id);});
    depths.push(best.depth);
    paths.push({id:best.id,cells:best.cells,direction:best.direction});
  }
  return {name:config.name,difficulty:config.difficulty,shape:config.shape,width:n,height:n,mask,paths};
}
const configs=[
  {name:'First weave',difficulty:'Very easy',shape:'rounded',size:20,length:20,bend:.12,depthBias:0},
  {name:'Cross currents',difficulty:'Easy',shape:'cross',size:25,length:24,bend:.35,depthBias:.35},
  {name:'Starfall',difficulty:'Medium',shape:'star',size:35,length:26,bend:.50,depthBias:.9},
  {name:'Labyrinth',difficulty:'Hard',shape:'rounded',size:29,length:34,bend:.65,depthBias:1.5},
  {name:'Constellation',difficulty:'Very hard',shape:'star',size:45,length:38,bend:.75,depthBias:2.8}
];
module.exports={generate,configs,maskFor};
if(require.main===module) {
  if(process.argv.includes('--select')) {
    const selected=[];
    const desiredDepth=[4,8,14,23,30], desiredCount=[34,42,50,65,75];
    for(let i=0;i<configs.length;i++) {
      let best;
      for(let j=0;j<50;j++) {
        const seed=101+i*199+j*7919, level=generate(configs[i],seed), metrics=E.validateLevel(level);
        if(metrics.arrows<30 || Math.min(...metrics.directions)<3) continue;
        const score=-Math.abs(metrics.depth-desiredDepth[i])*3-Math.abs(metrics.arrows-desiredCount[i])*.4
          -metrics.singles*7-(i>1?metrics.available*1.3:0);
        if(!best||score>best.score) best={level,metrics,seed,score};
      }
      selected.push(best);
    }
    console.log(JSON.stringify(selected));
    process.exit(0);
  }
  for(let i=0;i<configs.length;i++) {
    const level=generate(configs[i],101+i*199), m=E.validateLevel(level);
    console.log(configs[i].name,JSON.stringify({...m,solution:undefined}));
  }
}
