process.noAsar = true;
const fs = require('fs');
const path = require('path');

const asarPath = process.argv[2];
const outDir = process.argv[3];

const buf = fs.readFileSync(asarPath);
const payloadSize = buf.readUInt32LE(0);
const headerSize = buf.readUInt32LE(4);
const headerBuf = buf.subarray(8, 8 + headerSize);
const strLen = headerBuf.readUInt32LE(4);
const jsonStr = headerBuf.subarray(8, 8 + strLen).toString('utf8');
const header = JSON.parse(jsonStr);

function walk(node, prefix) {
  for (const [name, entry] of Object.entries(node.files)) {
    const rel = prefix ? prefix + '/' + name : name;
    if (entry.files) {
      walk(entry, rel);
    } else {
      console.log((entry.unpacked ? 'U ' : '  ') + rel + '\t' + entry.size + '\t' + entry.offset);
    }
  }
}

if (outDir) {
  // extract everything
  fs.mkdirSync(outDir, { recursive: true });
  function extract(node, prefix) {
    for (const [name, entry] of Object.entries(node.files)) {
      const rel = prefix ? prefix + '/' + name : name;
      const full = path.join(outDir, rel);
      if (entry.files) {
        fs.mkdirSync(full, { recursive: true });
        extract(entry, rel);
      } else if (!entry.unpacked) {
        fs.mkdirSync(path.dirname(full), { recursive: true });
        const start = 8 + headerSize + Number(entry.offset);
        fs.writeFileSync(full, buf.subarray(start, start + entry.size));
      }
    }
  }
  extract(header, '');
  console.log('EXTRACTED to ' + outDir);
} else {
  walk(header, '');
}
