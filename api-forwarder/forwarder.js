// api-worker LAN forwarder (userspace, no admin required for non-privileged port)
// 读取同目录 config.ini：[forwarder] 段配置监听地址与上游 api-worker 地址。
const net = require('net');
const cfg = require('./config');

const LISTEN_HOST = cfg.forwarder.listenHost;
const LISTEN_PORT = cfg.forwarder.listenPort;
const UPSTREAM_HOST = cfg.forwarder.upstreamHost;
const UPSTREAM_PORT = cfg.forwarder.upstreamPort;

const timestamp = () => new Date().toISOString().replace('T', ' ').replace('Z', '');
const log = (...args) => {
  if (cfg.log.enabled) console.log(`[${timestamp()}]`, ...args);
};
let connectionId = 0;
let activeConnections = 0;

const server = net.createServer((client) => {
  const id = ++connectionId;
  const remote = `${client.remoteAddress}:${client.remotePort}`;
  activeConnections++;
  log(`#${id} CONNECT ${remote} (active=${activeConnections})`);

  const upstream = net.createConnection({ host: UPSTREAM_HOST, port: UPSTREAM_PORT });
  upstream.on('connect', () => {
    log(`#${id} UPSTREAM connected -> ${UPSTREAM_HOST}:${UPSTREAM_PORT}`);
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
  log(`config: ${cfg.path} (${cfg.found ? 'loaded' : 'not found, using defaults'})`);
  log(`api-worker forwarder listening on ${LISTEN_HOST}:${LISTEN_PORT} -> ${UPSTREAM_HOST}:${UPSTREAM_PORT}`);
  log('Press Ctrl+C to stop. Connection metadata only; request bodies are not logged.');
});
server.on('error', (err) => {
  log('FORWARDER ERROR', err.code || '', err.message);
  process.exitCode = 1;
});
server.listen(LISTEN_PORT, LISTEN_HOST);
