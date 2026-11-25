// extract_vpk.js — extract files from Dota 2 pak01_dir.vpk (VPK v2).
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
console.log('VPK version', ver, 'treeSize', treeSize);

// wanted files (lowercase paths)
const wanted = {
  'scripts/npc/npc_abilities.txt': 'npc_abilities.txt',
  'scripts/npc/items.txt': 'items.txt',
  'scripts/npc/npc_heroes.txt': 'npc_heroes.txt',
  'scripts/npc/npc_units.txt': 'npc_units.txt',
  'scripts/npc/neutral_items.txt': 'neutral_items.txt',
};
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
      if (wanted[key]) {
        found[key] = { archiveIndex, archiveOffset, entryLength, preload: Buffer.from(preload) };
      }
    }
  }
}
const outDir = 'D:/hake/lotus/gamedata';
fs.mkdirSync(outDir, { recursive: true });
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
  const outName = wanted[key];
  fs.writeFileSync(path.join(outDir, outName), data);
  console.log('extracted', outName, data.length, 'bytes');
}
console.log('done. found', Object.keys(found).length, 'of', Object.keys(wanted).length);