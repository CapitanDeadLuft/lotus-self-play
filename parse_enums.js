const fs = require('fs');
let s = fs.readFileSync('D:/hake/lotus/umbrella_api/enums.md', 'utf8');
s = s.replace(/<mark[^>]*>/g, '').replace(/<\/mark>/g, '').replace(/`/g, '');
const lines = s.split('\n');
const enums = {};
let cur = null;
for (const l of lines) {
  const h = l.match(/^##\s+Enum\.([A-Za-z0-9_]+)/);
  if (h) { cur = h[1]; enums[cur] = {}; continue; }
  if (cur) {
    const m = l.match(/^\|\s*([A-Za-z0-9_]+)\s*\|\s*(-?\d+)\s*\|/);
    if (m) enums[cur][m[1]] = parseInt(m[2]);
  }
}
let out = '-- enums.lua — generated from official Umbrella API v2.0 enums\nlocal Enum = {}\n';
for (const [name, kv] of Object.entries(enums)) {
  out += 'Enum.' + name + ' = {\n';
  for (const [k, v] of Object.entries(kv)) out += '  ' + k + ' = ' + v + ',\n';
  out += '}\n';
}
out += 'return Enum\n';
fs.writeFileSync('D:/hake/lotus/src/enums.lua', out);
console.log('generated enums.lua: ' + Object.keys(enums).length + ' enums');
console.log('names: ' + Object.keys(enums).join(', '));
console.log('UnitOrder.STOP=' + enums.UnitOrder.DOTA_UNIT_ORDER_STOP + ' CAST_NO_TARGET=' + enums.UnitOrder.DOTA_UNIT_ORDER_CAST_NO_TARGET + ' TRAIN_ABILITY=' + enums.UnitOrder.DOTA_UNIT_ORDER_TRAIN_ABILITY);