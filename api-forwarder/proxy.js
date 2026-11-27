// 本机统一代理（系统级 / 全流量）
// 单一端口（默认 8633）同时支持两种代理协议，客户端按自身能力二选一：
//   1) HTTP/HTTPS 代理 —— 普通 HTTP 转发 + CONNECT 隧道
//      （对应 Windows「设置 - 代理 - 使用代理服务器」，浏览器 / Cursor 等 Electron 应用自动走这里）
//   2) SOCKS5 代理 —— CONNECT 命令（对应“把 TCP 流量全部走代理”的客户端）
// 首个字节为 0x05 视为 SOCKS5，否则按 HTTP 代理处理。
//
// 用户态运行，无需管理员。仅允许白名单源 IP（默认本机 + TARGET 10.40.62.6）。
// 日志仅记录连接元数据，不记录请求正文 / Token / 敏感内容。

'use strict';

const net = require('net');
const http = require('http');
const { URL } = require('url');

const LISTEN_HOST = process.env.PROXY_BIND || '0.0.0.0';
const LISTEN_PORT = Number(process.env.PROXY_PORT || 8633);
const ALLOW_IPS = (process.env.PROXY_ALLOW || '127.0.0.1,::1,10.40.62.6')
  .split(',')
  .map((s) => s.trim())
  .filter(Boolean);

const ts = () => new Date().toISOString().replace('T', ' ').replace('Z', '');
const log = (...a) => console.log(`[${ts()}]`, ...a);

let connId = 0;
let active = 0;

function normIp(ip) {
  if (!ip) return '';
  return ip.startsWith('::ffff:') ? ip.slice(7) : ip;
}

function isAllowed(ip) {
  const n = normIp(ip);
  if (!n) return false;
  if (ALLOW_IPS.includes('*')) return true;
  return ALLOW_IPS.includes(n);
}

// 解析 "host:port" / "[ipv6]:port"
function parseHostPort(s, defPort) {
  if (!s) return null;
  let host = s;
  let port = defPort;
  if (s[0] === '[') {
    const end = s.indexOf(']');
    if (end === -1) return null;
    host = s.slice(1, end);
    const rest = s.slice(end + 1);
    if (rest.startsWith(':')) port = Number(rest.slice(1));
  } else {
    const idx = s.lastIndexOf(':');
    if (idx > -1 && s.indexOf(':') === idx) {
      host = s.slice(0, idx);
      port = Number(s.slice(idx + 1));
    }
  }
  if (!host) return null;
  if (!port) port = defPort;
  return { host, port };
}

// --------------------------- HTTP / HTTPS 代理 ---------------------------

const httpServer = http.createServer(onHttpRequest);
httpServer.on('connect', onHttpConnect);
httpServer.on('clientError', (err, socket) => {
  try { socket.destroy(); } catch {}
});

// CONNECT 隧道：HTTPS、WebSocket(wss) 等都经这里
function onHttpConnect(req, clientSocket, head) {
  const id = ++connId;
  const remote = `${normIp(clientSocket.remoteAddress)}:${clientSocket.remotePort}`;
  const t = parseHostPort(req.url, 443);
  if (!t) {
    try { clientSocket.end('HTTP/1.1 400 Bad Request\r\n\r\n'); } catch {}
    return;
  }
  active++;
  log(`#${id} CONNECT ${remote} -> ${t.host}:${t.port} (active=${active})`);

  const upstream = net.connect(t.port, t.host, () => {
    clientSocket.write('HTTP/1.1 200 Connection Established\r\nProxy-Agent: vibe-local-proxy\r\n\r\n');
    if (head && head.length) upstream.write(head);
    upstream.pipe(clientSocket);
    clientSocket.pipe(upstream);
  });

  let done = false;
  const finish = () => {
    if (done) return;
    done = true;
    active = Math.max(0, active - 1);
    log(`#${id} CLOSE ${t.host}:${t.port} (active=${active})`);
  };

  upstream.on('error', (err) => {
    log(`#${id} UPSTREAM ERROR ${t.host}:${t.port} ${err.code || ''} ${String(err.message || '').trim()}`);
    try { clientSocket.end('HTTP/1.1 502 Bad Gateway\r\n\r\n'); } catch {}
    finish();
  });
  clientSocket.on('error', () => upstream.destroy());
  upstream.on('close', finish);
  clientSocket.on('close', () => upstream.destroy());
}

// 普通 HTTP 转发（请求行是绝对 URI，例如 GET http://host/path）
function onHttpRequest(req, res) {
  const id = ++connId;
  const remote = `${normIp(req.socket.remoteAddress)}:${req.socket.remotePort}`;
  let u;
  try {
    u = new URL(req.url);
  } catch {
    try { res.writeHead(400); res.end('bad request'); } catch {}
    return;
  }
  if (u.protocol !== 'http:') {
    try { res.writeHead(400); res.end('only absolute http:// here; use CONNECT for https'); } catch {}
    return;
  }
  const port = Number(u.port) || 80;
  log(`#${id} HTTP ${remote} ${req.method} -> ${u.hostname}:${port}${u.pathname || '/'}`);

  const headers = Object.assign({}, req.headers, { host: u.host });
  const preq = http.request(
    { host: u.hostname, port, method: req.method, path: (u.pathname || '/') + (u.search || ''), headers },
    (pres) => {
      try { res.writeHead(pres.statusCode || 502, pres.headers); } catch {}
      pres.pipe(res);
    }
  );
  preq.on('error', (err) => {
    log(`#${id} HTTP UPSTREAM ERROR ${u.hostname}:${port} ${err.code || ''} ${String(err.message || '').trim()}`);
    try { res.writeHead(502); res.end(); } catch {}
  });
  req.pipe(preq);
}

// ------------------------------- SOCKS5 代理 -------------------------------

function socksReply(socket, code) {
  // VER=5, REP, RSV=0, ATYP=IPv4, BND.ADDR=0.0.0.0, BND.PORT=0
  try { socket.write(Buffer.from([0x05, code, 0x00, 0x01, 0, 0, 0, 0, 0, 0])); } catch {}
}

function handleSocks5(clientSocket, firstChunk, remote) {
  const id = ++connId;
  active++;
  log(`#${id} SOCKS5 ${remote} (active=${active})`);

  let buf = firstChunk && firstChunk.length ? Buffer.from(firstChunk) : Buffer.alloc(0);
  let state = 'GREETING';
  let upstream = null;
  let pending = [];
  let done = false;

  const finish = () => {
    if (done) return;
    done = true;
    active = Math.max(0, active - 1);
    log(`#${id} SOCKS5 CLOSE (active=${active})`);
  };
  const cleanup = () => {
    try { if (upstream) upstream.destroy(); } catch {}
    try { clientSocket.destroy(); } catch {}
    finish();
  };

  function pump() {
    while (buf.length > 0) {
      if (state === 'GREETING') {
        if (buf.length < 2) return;
        const ver = buf[0];
        const nm = buf[1];
        if (ver !== 0x05) { cleanup(); return; }
        if (buf.length < 2 + nm) return;
        const methods = buf.slice(2, 2 + nm);
        buf = buf.slice(2 + nm);
        if (methods.includes(0x00)) {
          state = 'REQUEST';
          clientSocket.write(Buffer.from([0x05, 0x00]));
        } else {
          clientSocket.write(Buffer.from([0x05, 0xff]));
          cleanup();
          return;
        }
      } else if (state === 'REQUEST') {
        if (buf.length < 4) return;
        const ver = buf[0];
        const cmd = buf[1];
        const atyp = buf[3];
        if (ver !== 0x05 || cmd !== 0x01) {
          socksReply(clientSocket, 0x07); // command not supported
          cleanup();
          return;
        }
        let pos = 4;
        let host;
        if (atyp === 0x01) {
          if (buf.length < pos + 4 + 2) return;
          host = `${buf[pos]}.${buf[pos + 1]}.${buf[pos + 2]}.${buf[pos + 3]}`;
          pos += 4;
        } else if (atyp === 0x03) {
          if (buf.length < pos + 1) return;
          const len = buf[pos];
          if (buf.length < pos + 1 + len + 2) return;
          host = buf.slice(pos + 1, pos + 1 + len).toString('utf8');
          pos += 1 + len;
        } else if (atyp === 0x04) {
          if (buf.length < pos + 16 + 2) return;
          const parts = [];
          for (let i = 0; i < 16; i += 2) parts.push(buf.readUInt16BE(pos + i).toString(16));
          host = parts.join(':');
          pos += 16;
        } else {
          socksReply(clientSocket, 0x08); // address type not supported
          cleanup();
          return;
        }
        const port = buf.readUInt16BE(pos);
        pos += 2;
        const rest = buf.slice(pos);
        buf = Buffer.alloc(0);
        log(`#${id} SOCKS5 RELAY -> ${host}:${port}`);
        state = 'CONNECTING';

        upstream = net.connect(port, host, () => {
          socksReply(clientSocket, 0x00);
          state = 'RELAY';
          if (rest && rest.length) upstream.write(rest);
          for (const d of pending) upstream.write(d);
          pending = [];
        });
        upstream.on('data', (d) => {
          if (clientSocket.writable) clientSocket.write(d);
        });
        upstream.on('error', (err) => {
          log(`#${id} SOCKS5 UPSTREAM ERROR ${host}:${port} ${err.code || ''} ${String(err.message || '').trim()}`);
          socksReply(clientSocket, 0x04); // host unreachable
          cleanup();
        });
        upstream.on('close', () => cleanup());
      } else if (state === 'CONNECTING') {
        pending.push(buf);
        buf = Buffer.alloc(0);
        return;
      } else if (state === 'RELAY') {
        if (upstream) upstream.write(buf);
        buf = Buffer.alloc(0);
      }
    }
  }

  clientSocket.on('data', (d) => {
    buf = Buffer.concat([buf, d]);
    pump();
  });
  clientSocket.on('error', () => cleanup());
  clientSocket.on('close', () => cleanup());
  pump();
}

// ----------------------------- 协议分流入口 -----------------------------

const server = net.createServer((client) => {
  client.on('error', () => {});
  const remoteIp = normIp(client.remoteAddress);
  const remote = `${remoteIp}:${client.remotePort}`;

  if (!isAllowed(client.remoteAddress)) {
    log(`REJECT ${remote} (not in allow list)`);
    client.destroy();
    return;
  }

  client.once('data', (chunk) => {
    if (chunk[0] === 0x05) {
      handleSocks5(client, chunk, remote);
    } else {
      // 把已经读到的字节退回，交给内置 HTTP 服务器解析
      client.pause();
      client.unshift(chunk);
      httpServer.emit('connection', client);
      client.resume();
    }
  });
});

process.on('uncaughtException', (err) => log('UNCAUGHT', err && err.message ? err.message : String(err)));
process.on('unhandledRejection', (err) => log('REJECTION', err && err.message ? err.message : String(err)));

server.on('listening', () => {
  log(`Unified proxy (HTTP CONNECT + SOCKS5) listening on ${LISTEN_HOST}:${LISTEN_PORT}`);
  log(`Allowed source IPs: ${ALLOW_IPS.join(', ')}`);
  log('Use as http://<this-host>:port or socks5://<this-host>:port. Metadata-only logging.');
});
server.on('error', (err) => {
  log('PROXY ERROR', err.code || '', err.message);
  process.exitCode = 1;
});
server.listen(LISTEN_PORT, LISTEN_HOST);
