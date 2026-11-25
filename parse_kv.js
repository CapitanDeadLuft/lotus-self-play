// parse_kv.js — parse Source KeyValues text to JSON (for XHelpers.xkv).
const fs = require('fs');
const path = require('path');
const dir = 'D:/hake/lotus/gamedata';

function parseKV(text) {
  let i = 0; const n = text.length;
  function skipWS() {
    while (i < n) {
      const c = text[i];
      if (c === ' ' || c === '\t' || c === '\r' || c === '\n') { i++; }
      else if (c === '/' && text[i + 1] === '/') { while (i < n && text[i] !== '\n') i++; }
      else break;
    }
  }
  function readToken() {
    skipWS();
    if (i >= n) return null;
    const c = text[i];
    if (c === '{' || c === '}') { i++; return c; }
    if (c === '"') {
      i++; let s = '';
      while (i < n && text[i] !== '"') {
        if (text[i] === '\\') { i++; const e = text[i]; s += (e === 'n' ? '\n' : e === 't' ? '\t' : e); i++; }
        else { s += text[i]; i++; }
      }
      i++; return { str: s };
    }
    // bare token
    let s = '';
    while (i < n && !' \t\r\n{}"'.includes(text[i])) { s += text[i]; i++; }
    return { str: s };
  }
  function parseBlock() {
    const obj = {};
    while (true) {
      const key = readToken();
      if (key === null || key === '}') break;
      if (typeof key === 'object' && key.str !== undefined) {
        const k = key.str;
        const val = readToken();
        if (val === '{') { obj[k] = parseBlock(); }
        else if (val && typeof val === 'object') { obj[k] = val.str; }
        else if (val === '}') { break; }
        else { obj[k] = ''; }
      }
    }
    return obj;
  }
  // top level: "Root" { ... }
  const root = readToken();
  const brace = readToken();
  if (brace === '{') return parseBlock();
  return {};
}

for (const f of ['npc_abilities.txt', 'items.txt', 'npc_units.txt', 'npc_heroes.txt', 'neutral_items.txt']) {
  const fp = path.join(dir, f);
  if (!fs.existsSync(fp)) continue;
  const text = fs.readFileSync(fp, 'utf8');
  const obj = parseKV(text);
  const out = path.join(dir, f.replace('.txt', '.json'));
  fs.writeFileSync(out, JSON.stringify(obj));
  const topKeys = Object.keys(obj);
  console.log(f, '->', topKeys.length, 'top keys; first:', topKeys.slice(0, 3).join(', '));
  // check DOTAAbilities
  if (obj.DOTAAbilities) console.log('  DOTAAbilities entries:', Object.keys(obj.DOTAAbilities).length);
}