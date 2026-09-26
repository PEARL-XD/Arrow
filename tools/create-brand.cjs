// Original code-drawn icon; no downloaded or borrowed assets.
const fs=require('node:fs');
const path=require('node:path');
const sharp=require(process.argv[2] || 'sharp');
const root=path.join(__dirname,'..');
const svg=Buffer.from(`<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1024 1024"><rect width="1024" height="1024" fill="#506bdf"/><path d="M282 739V552H490V350H738M615 227L738 350L615 473" fill="none" stroke="#fff" stroke-width="70" stroke-linecap="round" stroke-linejoin="round"/></svg>`);
(async()=>{
  for(const [density,size] of Object.entries({mdpi:48,hdpi:72,xhdpi:96,xxhdpi:144,xxxhdpi:192})) {
    await sharp(svg).resize(size,size).png().toFile(path.join(root,`android/app/src/main/res/mipmap-${density}/ic_launcher.png`));
  }
  const dir=path.join(root,'ios/Runner/Assets.xcassets/AppIcon.appiconset');
  const icons=JSON.parse(fs.readFileSync(path.join(dir,'Contents.json'),'utf8'));
  for(const icon of icons.images) {
    const size=parseFloat(icon.size)*parseFloat(icon.scale);
    await sharp(svg).resize(size,size).png().toFile(path.join(dir,icon.filename));
  }
  console.log('Created Android and iOS launcher icons.');
})().catch(error=>{console.error(error);process.exitCode=1;});
