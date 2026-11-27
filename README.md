# ClaudeCodeBridge

本仓库管理「本机（Vibe助手）→ 内网 TARGET」的两类中转，均为**用户态、非特权端口、无需管理员**：

1. **API 转发**：`api-forwarder/forwarder.js`，`0.0.0.0:8634 -> 127.0.0.1:9182`
   TARGET 上的 Claude Code / 兼容客户端通过 `http://<本机IP>:8634` 使用本机 Vibe 账号的模型。
2. **系统级代理**：`api-forwarder/proxy.js`，`0.0.0.0:8633`，单端口同时支持 HTTP(S) CONNECT 与 SOCKS5。
   用于 TARGET 浏览器/Cursor 等需要出公网的场景（浏览器登录、官网访问）。

TARGET（Cursor 激活文件、部署脚本）见 [target/README.md](target/README.md)。

## 目录结构

```
api-forwarder/     # 8634 API 转发器 + 8633 统一代理（HTTP CONNECT / SOCKS5）
target/            # Cursor 激活部署包、部署脚本与说明
tools/             # 辅助脚本
_scratch/          # 调研/临时文件（不入库）
```

## 快速开始

- API 转发：双击 `api-forwarder/start-forwarder.cmd`（或 `start-forwarder.vbs` 后台运行）。
- 代理：双击 `api-forwarder/start-proxy.cmd`（或 `start-proxy.vbs` 后台运行）。
- 需要 Node.js：优先使用脚本同目录的 `node.exe`（便携版），其次 PATH 中的 `node`，
  最后回退到本机 Vibe 自带的 `api-worker-electron\resources\bin\node.cmd`。

## 关键背景

- api-worker：Vibe助手 内置代理，监听 `127.0.0.1:9182`，OpenAI + Anthropic 兼容。
- 端口：防火墙既有规则已放行入站 TCP `8633/8634`（任意程序），通常无需新增规则。
- 注意：8633/8634 均无鉴权，8633 仅按 `PROXY_ALLOW` 源 IP 白名单限制，仅限内网临时使用。
