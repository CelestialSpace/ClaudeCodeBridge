# ClaudeCodeBridge / api-forwarder

本目录做两件事，都用**用户态、非特权端口、无需管理员**实现：

1. **API 转发（LAN 暴露本机 Vibe 的 api-worker）**：`0.0.0.0:8634 -> 127.0.0.1:9182`
   TARGET(10.40.62.6) 上的 Claude/Code 通过 `http://本机:8634` 调用本机 Vibe 账号的模型。
2. **系统级代理（TARGET 全流量经本机出网）**：本机 `0.0.0.0:8633`，**同一端口同时支持 HTTP(S) 代理与 SOCKS5 代理**。
   解决 CURSOR 在 TARGET 首次登录需要联网（浏览器登录）等场景——TARGET 把系统代理指向本机 8633 即可。

本机内网地址（示例）：`10.40.111.234`，TARGET：`10.40.62.6`。

## 文件

| 文件 | 用途 |
|---|---|
| `forwarder.js` | TCP 转发器：`0.0.0.0:8634 -> 127.0.0.1:9182`（API） |
| `proxy.js` | **统一代理**：`0.0.0.0:8633`，按首字节自动区分 HTTP 代理(含 CONNECT 隧道) 与 SOCKS5 |
| `start-forwarder.cmd/.vbs` | 启动 API 转发器（可见窗口 / 后台隐藏） |
| `start-proxy.cmd/.vbs` | 启动统一代理（可见窗口 / 后台隐藏） |

## 运行环境

只需 **Node.js**（`proxy.js` / `forwarder.js` 仅用内置模块，无 `npm install`）。启动脚本按以下顺序查找 node：

1. 脚本同目录的 `node.exe`（便携版，推荐打包时附带）；
2. PATH 中的 `node`；
3. 本机 Vibe 自带的 `%LOCALAPPDATA%\Programs\api-worker-electron\resources\bin\node.cmd`。

在新机器上部署：复制 `proxy.js`、`forwarder.js` 与对应 `start-*.cmd/.vbs`（可加 `node.exe`），
修改 `start-*.cmd`/`.vbs` 中的 `PROXY_ALLOW`（允许访问的源 IP）后运行。

## 快速开始（代理）

1. 双击 `start-proxy.vbs`（后台隐藏）或 `start-proxy.cmd`（看日志）。
2. 看到日志 `Unified proxy (HTTP CONNECT + SOCKS5) listening on 0.0.0.0:8633` 即成功。
3. 开机自启：把 `start-proxy.vbs` 的快捷方式放进 `shell:startup`。

环境变量（可选，脚本已设默认）：`PROXY_PORT`(8633) `PROXY_BIND`(0.0.0.0) `PROXY_ALLOW`(允许的源 IP，逗号分隔，`*` 放行全部)。
## TARGET（10.40.62.6）端设置

本机代理地址：`10.40.111.234:8633`（以本机实际内网 IP 为准；本机多网卡时选与 TARGET 互通的网段）。

### 方式 A：Windows 系统代理（推荐，浏览器 / Cursor 等 Electron 应用自动生效）
- 设置 > 网络和 Internet > 代理 > 手动设置代理 > 使用代理服务器：
  - 地址 `10.40.111.234`，端口 `8633`，保存。
- 或 控制面板 > Internet 选项 > 连接 > 局域网(LAN)设置 > 为 LAN 使用代理服务器：地址/端口同上。
- 该设置走 HTTP(S) 代理，HTTPS 通过 CONNECT 隧道，足以覆盖浏览器登录与 Cursor 联网。

### 方式 B：SOCKS5（需要“所有 TCP 流量”走代理的客户端）
- Internet 选项 > 局域网设置 > 高级 > “套接字(SOCKS)”填 `10.40.111.234`，端口 `8633`。
- 或客户端里直接填 `socks5://10.40.111.234:8633`（无认证）。

### 方式 C：命令行临时测试（仅当前进程）
```
set HTTP_PROXY=http://10.40.111.234:8633
set HTTPS_PROXY=http://10.40.111.234:8633
set ALL_PROXY=socks5://10.40.111.234:8633
```

## 验证

- 本机自测：`curl -x http://127.0.0.1:8633 https://example.com`，`curl -x socks5://127.0.0.1:8633 https://example.com`，均应返回网页。
- TARGET 端口连通：`Test-NetConnection 10.40.111.234 -Port 8633`（TcpTestSucceeded=True）。
- TARGET 穿透：`curl -x http://10.40.111.234:8633 https://cursor.com` 返回 200。
- CURSOR 首次登录：本机代理运行中，在 TARGET 浏览器打开 https://cursor.com 完成登录，再回到 Cursor 应用。

## 防火墙

本机既有规则 “Net ManagementV V3 TCP” 已放行入站 TCP 8633/8634（任意程序、任意远端地址），通常无需新增规则。
若 TARGET 连不上，确认该规则已启用；仍不行时用管理员 PowerShell 执行：
```
netsh advfirewall firewall add rule name="vibe proxy 8633" dir=in action=allow protocol=TCP localport=8633
```

## 安全

- 8633 会把 TARGET 的出网流量经本机转发，未做鉴权，仅按 `PROXY_ALLOW` 源 IP 白名单（默认 `127.0.0.1,::1,10.40.62.6`）。
- 不要长期对不可信网络开放；用完收紧 `PROXY_ALLOW` 或关闭代理。
- 日志只记录连接元数据（对端、目标 host:port、状态），不记录正文 / Token。

## 说明

- 单端口分流：首字节为 `0x05` 走 SOCKS5，否则按 HTTP 代理（CONNECT 隧道 / 普通 HTTP 转发）。
- `authenticator.cursor.sh` 根路径 `/` 在本机直连时同样会超时，属目标站点行为，非代理问题；真实登录走带参数的特定路径。
- 前提：本机可直连外网（cursor.com、api2.cursor.sh、google.com 等已实测可达）。