#!/usr/bin/env node
// upload-attacks.sh icin test dosyalarini uretir (kod degil, yalniz veri). ASCII disinda bayt icerir.
'use strict';
const fs = require('node:fs');
const path = require('node:path');
const dir = process.argv[2] || '.';
fs.mkdirSync(dir, { recursive: true });

// 1) Gercek JPEG magic bayti YOK, duz metin -- Content-Type header'i "image/jpeg" olarak SAHTE beyan edilecek.
fs.writeFileSync(path.join(dir, 'fake-text-as-jpeg.bin'), 'Bu dosya bir JPEG degildir. <script>alert(1)</script>\n');

// 2) JPEG magic + EXIF APP1 (GPS tag "GPSLatitude" metnini iceren basit bir EXIF simulasyonu).
//    Gercek bir EXIF ayristirici gerektirmez; sadece "GPS" baytlarinin ciktida hala var olup olmadigina bakariz.
const jpegHeader = Buffer.from([0xff, 0xd8, 0xff, 0xe1]); // SOI + APP1 (EXIF) marker
const exifBlob = Buffer.concat([Buffer.from('Exif\0\0GPSLatitude=41.0,GPSLongitude=40.5 TEST-GPS-MARKER', 'ascii')]);
const lenBuf = Buffer.alloc(2);
lenBuf.writeUInt16BE(exifBlob.length + 2, 0);
const eoi = Buffer.from([0xff, 0xd9]);
fs.writeFileSync(path.join(dir, 'exif-gps.jpg'), Buffer.concat([jpegHeader, lenBuf, exifBlob, eoi]));

// 3) Gercek SVG (XSS yuku) -- image/svg+xml olarak reddedilmesi beklenir (izinli tur degil).
fs.writeFileSync(path.join(dir, 'xss.svg'), '<svg xmlns="http://www.w3.org/2000/svg" onload="alert(1)"><script>alert(2)</script></svg>\n');

// 4) GIF/HTML polyglot: GIF89a magic bayti + HTML/JS govdesi (polyglot saldirisi klasigi).
fs.writeFileSync(path.join(dir, 'polyglot.gif'),
  Buffer.concat([Buffer.from('GIF89a', 'ascii'), Buffer.from('/*<html><body><script>alert(3)</script></body></html>*/', 'ascii')]));

// 5) Asiri buyuk dosya (3 MB; avatar sinirinin 2 MB uzerinde).
fs.writeFileSync(path.join(dir, 'oversized.bin'), Buffer.alloc(3 * 1024 * 1024, 0x41));

// 6) Yol gezintisi deneyen dosya adi (sunucu adi kendisi uretir; istemci adi yalniz log/baslikta gorulebilir).
fs.writeFileSync(path.join(dir, '..-..-..-etc-passwd.jpg'), Buffer.from([0xff, 0xd8, 0xff, 0xd9]));

console.log('fixtures written to', dir);
