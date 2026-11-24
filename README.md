# 本机 AI 中转 / 工具集

本仓库管理「本机 Vibe助手 api-worker 对外中转」相关的脚本与工具。

## 目录结构

```
api-forwarder/     # api-worker 局域网转发器（8634 → 9182）
tools/             # 辅助脚本（如 Claude Code 断点续传下载）
_scratch/          # 调研/临时文件（不入库）
```

## 快速开始

见 [api-forwarder/README.md](api-forwarder/README.md)。

## 关键背景

- api-worker：Vibe助手 内置代理，监听 `127.0.0.1:9182`，OpenAI + Anthropic 兼容。
- 暴露方式：本机防火墙既有规则放行 `8634`（任意程序入站），故转发器监听 8634。
- TARGET 使用：`http://10.40.111.234:8634/v1/...`，无需 API Key（沿用本机登录会话）。
- 注意：`8634` 无鉴权，仅内网临时使用。
