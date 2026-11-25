// extract_one.js — extract arbitrary files from Dota 2 pak01 VPKs (v1-style tree in v2 header).
// usage: node extract_one.js <outDir> <path1> [path2 ...]   (paths relative to game/dota, with extension)
const fs = require('fs');
const path = require('path');
const DOTA = 'E:/SteamLibrary/steamapps/common/dota 2 beta/game/dota';
const dirPath = path.join(DOTA, 'pak01_dir.vpk');
const buf = fs.readFileSync(dirPath);
const sig = buf.readUInt32LE(0);
const ver = buf.readUInt32LE(4);
if (sig !== 0x55AA1234) { console.log('bad signature', sig.toString(16)); process.exit(1); }
const treeSize = buf.readUInt32LE(8);
const headerSize = (ver === 2) ? 28 : 12;
const treeStart = headerSize;
const treeEnd = treeStart + treeSize;
const outDir = process.argv[2] || 'D:/hake/lotus/gamedata/extra';
const wantedList = process.argv.slice(3);
const wanted = {};
for (const w of wantedList) wanted[w.toLowerCase()] = w;

const found = {};
let p = treeStart;
function readStr() { let e = buf.indexOf(0, p); const s = buf.toString('latin1', p, e); p = e + 1; return s; }
while (p < treeEnd) {
  const ext = readStr(); if (ext === '') break;
  while (p < treeEnd) {
    const dir = readStr(); if (dir === '') break;
    while (p < treeEnd) {
      const fname = readStr(); if (fname === '') break;
      const crc = buf.readUInt32LE(p); p += 4;
      const preloadBytes = buf.readUInt16LE(p); p += 2;
      const archiveIndex = buf.readUInt16LE(p); p += 2;
      const archiveOffset = buf.readUInt32LE(p); p += 4;
      const entryLength = buf.readUInt32LE(p); p += 4;
      const term = buf.readUInt16LE(p); p += 2;
      const preload = buf.subarray(p, p + preloadBytes); p += preloadBytes;
      const full = (dir === ' ' ? '' : dir + '/') + fname + '.' + ext;
      const key = full.toLowerCase();
      if (wanted[key]) found[key] = { archiveIndex, archiveOffset, entryLength, preload: Buffer.from(preload), full };
    }
  }
}
fs.mkdirSync(outDir, { recursive: true });
let n = 0;
for (const [key, info] of Object.entries(found)) {
  let data;
  if (info.archiveIndex === 0x7FFF) {
    const start = treeEnd + info.archiveOffset;
    data = Buffer.concat([info.preload, buf.subarray(start, start + info.entryLength)]);
  } else {
    const archPath = path.join(DOTA, `pak01_${String(info.archiveIndex).padStart(3, '0')}.vpk`);
    const ab = fs.readFileSync(archPath);
    data = Buffer.concat([info.preload, ab.subarray(info.archiveOffset, info.archiveOffset + info.entryLength)]);
  }
  const outName = path.join(outDir, path.basename(info.full));
  fs.writeFileSync(outName, data);
  console.log('extracted', outName, data.length, 'bytes');
  n++;
}
console.log('done. found', n, 'of', wantedList.length);
for (const w of wantedList) if (!found[w.toLowerCase()]) console.log('MISSING', w);