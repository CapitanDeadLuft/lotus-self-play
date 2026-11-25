// extract_map.js — extract entity lumps from Dota map vpk (game/dota/maps/dota.vpk).
const fs = require('fs');
const path = require('path');
const MAP = 'E:/SteamLibrary/steamapps/common/dota 2 beta/game/dota/maps/dota.vpk';
const buf = fs.readFileSync(MAP);
const sig = buf.readUInt32LE(0);
const ver = buf.readUInt32LE(4);
if (sig !== 0x55AA1234) { console.log('bad signature', sig.toString(16)); process.exit(1); }
const treeSize = buf.readUInt32LE(8);
const headerSize = (ver === 2) ? 28 : 12;
const treeStart = headerSize;
const treeEnd = treeStart + treeSize;
const outDir = process.argv[2] || 'D:/hake/lotus/gamedata/map_entities';
const wanted = {};
for (const w of process.argv.slice(3)) wanted[w.toLowerCase()] = w;
const found = {};
let p = treeStart;
function readStr() { const e = buf.indexOf(0, p); const s = buf.toString('latin1', p, e); p = e + 1; return s; }
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
      found[key] = { archiveIndex, archiveOffset, entryLength, preload: Buffer.from(preload), full };
    }
  }
}
fs.mkdirSync(outDir, { recursive: true });
console.log('total entries', Object.keys(found).length);
let n = 0;
for (const [key, info] of Object.entries(found)) {
  if (wanted.size && !Object.keys(wanted).some(w => key.includes(w))) continue;
  let data;
  if (info.archiveIndex === 0x7FFF) {
    const start = treeEnd + info.archiveOffset;
    data = Buffer.concat([info.preload, buf.subarray(start, start + info.entryLength)]);
  } else {
    // external archive for map vpk? unlikely; report
    console.log('EXTERNAL', info.archiveIndex, info.full);
    continue;
  }
  const outName = path.join(outDir, info.full.replace(/[\/\\]/g, '_'));
  fs.writeFileSync(outName, data);
  console.log('extracted', outName, data.length, 'bytes');
  n++;
}
console.log('done', n);