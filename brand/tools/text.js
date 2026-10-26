// Yazi -> SVG yol (path). Yazi tipi dosyasi repoya KONMAZ; olusan yollar source/wordmark.json'da onbellekte.
// Onbellek yoksa Windows'taki Times New Roman Bold (veya FONT_FILE) okunur; yoksa hata verir.
const fs = require('fs');
const path = require('path');

const CACHE = path.join(__dirname, '..', 'source', 'wordmark.json');
const UNIT = 1000;
// Yaziyi logodaki kalin serif harflere en yakin yapan yazi tipi: Times New Roman Bold
const TEXTS = {
  name: { text: 'B\u00dc Kamp\u00fcs', tracking: 0 },
  tagline: { text: 'B\u0130NG\u00d6L \u00dcN\u0130VERS\u0130TES\u0130', tracking: 110 },
};

function generate() {
  const opentype = require('opentype.js');
  const candidates = [process.env.FONT_FILE, 'C:\\Windows\\Fonts\\timesbd.ttf', '/usr/share/fonts/truetype/msttcorefonts/Times_New_Roman_Bold.ttf'].filter(Boolean);
  const file = candidates.find((f) => fs.existsSync(f));
  if (!file) throw new Error('Yazi tipi bulunamadi: FONT_FILE=<bold serif .ttf> verin veya source/wordmark.json kullanin');
  const font = opentype.loadSync(file);
  const upm = font.unitsPerEm;
  const out = {};
  for (const [key, { text, tracking }] of Object.entries(TEXTS)) {
    let x = 0;
    const ds = [];
    let prev = null;
    let x1 = Infinity, y1 = Infinity, x2 = -Infinity, y2 = -Infinity;
    for (const ch of text) {
      const g = font.charToGlyph(ch);
      if (prev) x += font.getKerningValue(prev, g) * (UNIT / upm);
      if (ch !== ' ') {
        const p = g.getPath(x, 0, UNIT);
        const bb = p.getBoundingBox();
        x1 = Math.min(x1, bb.x1); y1 = Math.min(y1, bb.y1); x2 = Math.max(x2, bb.x2); y2 = Math.max(y2, bb.y2);
        ds.push(p.toPathData(1));
      }
      x += g.advanceWidth * (UNIT / upm) + tracking;
      prev = g;
    }
    const capH = font.charToGlyph('B').getPath(0, 0, UNIT).getBoundingBox();
    out[key] = { d: ds.join(' '), box: { x1, y1, x2, y2 }, capHeight: -capH.y1 };
  }
  fs.writeFileSync(CACHE, JSON.stringify(out));
  return out;
}

function loadWordmark() {
  if (fs.existsSync(CACHE) && !process.env.REGEN_WORDMARK) return JSON.parse(fs.readFileSync(CACHE, 'utf8'));
  return generate();
}

/**
 * Yazi blogu: `key` ('name'|'tagline'), ink genisligi `inkW` px olacak sekilde olcekli.
 * Donus: { svg(x,y,fill): x = ink solu, y = taban cizgisi }, scale, capH(px), inkW, descent(px), ascent(px)
 */
function block(wm, key, { fontSize, inkW }) {
  const w = wm[key];
  const inkUnits = w.box.x2 - w.box.x1;
  const s = inkW ? inkW / inkUnits : fontSize / UNIT;
  return {
    scale: s,
    inkW: inkUnits * s,
    capH: w.capHeight * s,
    ascent: -w.box.y1 * s,
    descent: w.box.y2 * s,
    fontSize: s * UNIT,
    svg(x, y, fill) {
      return `<path transform="translate(${(x - w.box.x1 * s).toFixed(2)} ${y.toFixed(2)}) scale(${s.toFixed(5)})" fill="${fill}" d="${w.d}"/>`;
    },
  };
}

module.exports = { loadWordmark, block };
