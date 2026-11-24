// api-worker LAN forwarder (userspace, no admin required for non-privileged port)
// 8634 命中既有防火墙放行规则 "Net ManagementV V3 TCP"（任意程序入站）
const net = require('net');

const LISTEN_PORT = Number(process.env.LISTEN_PORT || 8634);
const TARGET_HOST = '127.0.0.1';
const TARGET_PORT = 9182;

const timestamp = () => new Date().toISOString().replace('T', ' ').replace('Z', '');
const log = (...args) => console.log(`[${timestamp()}]`, ...args);
let connectionId = 0;
let activeConnections = 0;

const server = net.createServer((client) => {
  const id = ++connectionId;
  const remote = `${client.remoteAddress}:${client.remotePort}`;
  activeConnections++;
  log(`#${id} CONNECT ${remote} (active=${activeConnections})`);

  const upstream = net.createConnection({ host: TARGET_HOST, port: TARGET_PORT });
  upstream.on('connect', () => {
    log(`#${id} UPSTREAM connected -> ${TARGET_HOST}:${TARGET_PORT}`);
    client.pipe(upstream);
    upstream.pipe(client);
  });
  upstream.on('error', (err) => {
    log(`#${id} UPSTREAM ERROR ${err.code || ''} ${err.message}`.trim());
    client.destroy();
  });
  client.on('error', (err) => {
    log(`#${id} CLIENT ERROR ${err.code || ''} ${err.message}`.trim());
    upstream.destroy();
  });
  client.on('close', () => {
    activeConnections = Math.max(0, activeConnections - 1);
    log(`#${id} CLOSED (active=${activeConnections})`);
  });
});

server.on('listening', () => {
  log(`api-worker forwarder listening on 0.0.0.0:${LISTEN_PORT} -> ${TARGET_HOST}:${TARGET_PORT}`);
  log('Press Ctrl+C to stop. Connection metadata only; request bodies are not logged.');
});
server.on('error', (err) => {
  log('FORWARDER ERROR', err.code || '', err.message);
  process.exitCode = 1;
});
server.listen(LISTEN_PORT, '0.0.0.0');
