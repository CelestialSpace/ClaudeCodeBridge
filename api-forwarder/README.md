# api-worker LAN forwarder

本机 Vibe助手 的 api-worker 默认只监听 `127.0.0.1:9182`（本地回环），局域网其他机器无法直接访问。
本目录的脚本把本机的 api-worker 暴露为全网卡可访问端口，无需管理员权限。

## 文件

| 文件 | 用途 |
|---|---|
| `forwarder.js` | Node.js TCP 转发器：`0.0.0.0:8634 → 127.0.0.1:9182`，带连接日志 |
| `start-forwarder.cmd` | 在可见命令行窗口中启动转发器（便于查看日志） |
| `start-forwarder.vbs` | 后台隐藏启动转发器（适合放入 Startup 实现开机自启） |

## 使用

1. 确保本机 Vibe助手 已登录并运行（api-worker 监听 `127.0.0.1:9182`）。
2. 双击 `start-forwarder.cmd`（看日志）或 `start-forwarder.vbs`（后台）。
3. TARGET 机器访问：`http://<本机内网IP>:8634/v1/models`、`/v1/chat/completions`、`/v1/messages`

## 为什么是 8634

本机防火墙规则中已存在“Net ManagementV V3 TCP”，允许任意程序入站于 8634（TCP/UDP），无需手动新增防火墙规则。9183 等其他端口会被防火墙拦截。

## 安全

8634 对局域网内所有人开放且不校验鉴权，会消耗你本机 Vibe助手 账号额度。仅临时使用，不用时关闭转发器窗口即可。
