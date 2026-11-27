// 读取 config.ini 的极简解析器（无第三方依赖）。
// 查找顺序：CONFIG_PATH 环境变量 -> 脚本同目录 config.ini -> 默认值。
// 同名环境变量优先级高于配置文件，便于临时覆盖。
const fs = require('fs');
const path = require('path');

const CONFIG_PATH = process.env.CONFIG_PATH || path.join(__dirname, 'config.ini');

function parseIni(text) {
  const data = Object.create(null);
  let section = 'default';
  data[section] = Object.create(null);
  for (const rawLine of text.split(/\r?\n/)) {
    const line = rawLine.trim();
    if (!line || line.startsWith(';') || line.startsWith('#')) continue;
    if (line.startsWith('[') && line.endsWith(']')) {
      section = line.slice(1, -1).trim().toLowerCase();
      if (!data[section]) data[section] = Object.create(null);
      continue;
    }
    const eq = line.indexOf('=');
    if (eq === -1) continue;
    const key = line.slice(0, eq).trim().toLowerCase();
    const value = line.slice(eq + 1).trim();
    data[section][key] = value;
  }
  return data;
}

let ini = Object.create(null);
let found = false;
try {
  ini = parseIni(fs.readFileSync(CONFIG_PATH, 'utf8'));
  found = true;
} catch (err) {
  if (err.code !== 'ENOENT') throw err;
}

function get(section, key, def) {
  const sec = ini[section] || {};
  return sec[key] !== undefined ? sec[key] : def;
}

function env(name, def) {
  const v = process.env[name];
  return v !== undefined && v !== '' ? v : def;
}

function num(v, def) {
  const n = Number(v);
  return Number.isFinite(n) ? n : def;
}

function bool(v, def) {
  if (v === undefined || v === null || v === '') return def;
  return /^(1|true|yes|on)$/i.test(String(v).trim());
}

function splitList(v, def) {
  const items = String(v || '')
    .split(',')
    .map((s) => s.trim())
    .filter(Boolean);
  return items.length ? items : def;
}

const localIp = env('LOCAL_IP', get('network', 'local_ip', '10.40.111.234'));
const targetIp = env('TARGET_IP', get('network', 'target_ip', '10.40.62.6'));

// 代理白名单：显式 ALLOW_IPS/PROXY_ALLOW 覆盖配置；TARGET_IP 始终加入
const allowFromEnv = env('ALLOW_IPS', env('PROXY_ALLOW', get('proxy', 'allow_ips', '')));
const allowIps = splitList(allowFromEnv, ['127.0.0.1', '::1']);
if (!allowIps.includes('*') && targetIp && !allowIps.includes(targetIp)) {
  allowIps.push(targetIp);
}

module.exports = {
  path: CONFIG_PATH,
  found,
  localIp,
  targetIp,
  forwarder: {
    listenHost: env('LISTEN_HOST', get('forwarder', 'listen_host', '0.0.0.0')),
    listenPort: num(env('LISTEN_PORT', get('forwarder', 'listen_port', '8634')), 8634),
    upstreamHost: env('UPSTREAM_HOST', get('forwarder', 'upstream_host', '127.0.0.1')),
    upstreamPort: num(env('UPSTREAM_PORT', get('forwarder', 'upstream_port', '9182')), 9182),
  },
  proxy: {
    listenHost: env('PROXY_BIND', get('proxy', 'listen_host', '0.0.0.0')),
    listenPort: num(env('PROXY_PORT', get('proxy', 'listen_port', '8633')), 8633),
    allowIps,
  },
  log: {
    enabled: bool(env('LOG_ENABLED', get('log', 'enabled', 'true')), true),
  },
};
