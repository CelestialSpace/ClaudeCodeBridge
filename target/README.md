# 01. 文件清单与对应路径

本目录存放了从本机（`10.40.111.234`）导出的 Cursor 激活相关文件，用于在 TARGET（`10.40.62.6`）上复制同等激活状态。

> ⚠️ 敏感提醒：`target/activation/` 和 `target/patches/` 包含可复用的授权凭据（Token、已打补丁的程序文件），**已加入 `.gitignore`，不会随仓库推送到 GitHub**。请通过离线方式（U 盘、局域网共享、远程桌面文件传输）复制到 TARGET，不要提交到远程仓库。

## 一、激活凭据目录（activation）

| 源文件（本机） | 仓库内路径 | TARGET 部署路径 | 说明 |
|---|---|---|---|
| `C:\Users\zhut\.augpro.json` | `target/activation/.augpro.json` | `C:\Users\<TARGET用户名>\.augpro.json` | XOR 37 混淆的 JSON，包含 `CURSOR_TOKEN`、`API_WORKER_URL`、`CODE_POOL_AT` 等 |
| `C:\Users\zhut\api-worker\.auth` | `target/activation/api-worker/.auth` | `C:\Users\<TARGET用户名>\api-worker\.auth` | api-worker 与 Cursor 之间的鉴权 Token（纯文本） |
| `C:\Users\zhut\AppData\Roaming\Cursor\User\settings.json` | `target/activation/cursor-settings.json` | `C:\Users\<TARGET用户名>\AppData\Roaming\Cursor\User\settings.json` | Cursor 用户配置，需保留其中的 `cursor.general.disableHttp2: true` 等键 |

## 二、Cursor 程序补丁目录（patches）

下列文件来自本机 Cursor 安装目录，Vibe助手 对其打过激活补丁。部署到 TARGET 时需保持相对目录结构。

| 源文件（本机） | 仓库内路径 | TARGET 部署路径 |
|---|---|---|
| `...\Cursor\resources\app\out\vs\workbench\workbench.desktop.main.js` | `target/patches/out/vs/workbench/workbench.desktop.main.js` | `C:\Users\<TARGET用户名>\AppData\Local\Programs\Cursor\resources\app\out\vs\workbench\workbench.desktop.main.js` |
| `...\Cursor\resources\app\out\vs\workbench\workbench.desktop.main.js.bak` | `target/patches/out/vs/workbench/workbench.desktop.main.js.bak` | 同上 `.bak` |
| `...\Cursor\resources\app\out\vs\workbench\workbench.glass.main.js` | `target/patches/out/vs/workbench/workbench.glass.main.js` | `...\out\vs\workbench\workbench.glass.main.js` |
| `...\Cursor\resources\app\out\vs\workbench\workbench.glass.main.js.bak` | `target/patches/out/vs/workbench/workbench.glass.main.js.bak` | 同上 `.bak` |
| `...\Cursor\resources\app\out\vs\workbench\api\node\extensionHostProcess.js` | `target/patches/out/vs/workbench/api/node/extensionHostProcess.js` | `...\out\vs\workbench\api\node\extensionHostProcess.js` |
| `...\Cursor\resources\app\out\vs\workbench\api\node\extensionHostProcess.js.bak` | `target/patches/out/vs/workbench/api/node/extensionHostProcess.js.bak` | 同上 `.bak` |
| `...\Cursor\resources\app\extensions\cursor-always-local\dist\main.js` | `target/patches/extensions/cursor-always-local/dist/main.js` | `...\extensions\cursor-always-local\dist\main.js` |
| `...\Cursor\resources\app\extensions\cursor-always-local\dist\main.js.bak` | `target/patches/extensions/cursor-always-local/dist/main.js.bak` | 同上 `.bak` |
| `...\Cursor\resources\app\extensions\cursor-agent-host\dist\main.js` | `target/patches/extensions/cursor-agent-host/dist/main.js` | `...\extensions\cursor-agent-host\dist\main.js` |
| `...\Cursor\resources\app\extensions\cursor-agent-host\dist\main.js.bak` | `target/patches/extensions/cursor-agent-host/dist\main.js.bak` | 同上 `.bak` |

> 路径中的 `<TARGET用户名>` 指 TARGET 上登录的 Windows 用户名（通常是 `zhut`）。

## 三、注意：API_WORKER_URL 需要修改

本机的 `.augpro.json` 中：

```json
"API_WORKER_URL":"http://127.0.0.1:9182"
```

复制到 TARGET 后，**必须改为指向本机中转端口**，否则 TARGET 上的 Cursor 会尝试连自己不存在的 9182：

```json
"API_WORKER_URL":"http://10.40.111.234:8634"
"API_WORKER_HOST":"10.40.111.234:8634"
"LS_URL":"http://10.40.111.234:8634"
```

（前提：本机 `0.0.0.0:8634 → 127.0.0.1:9182` 转发器正在运行，且 TARGET 能访问 `10.40.111.234:8634`。）

---

# 02. 部署步骤

在 TARGET（`10.40.62.6`）上执行：

1. **关闭正在运行的 Cursor**（任务管理器结束 `Cursor.exe`）。
2. **复制激活凭据**：
   - 把 `target/activation/.augpro.json` 放到 `C:\Users\<用户名>\.augpro.json`。
   - 把 `target/activation/api-worker/.auth` 放到 `C:\Users\<用户名>\api-worker\.auth`（若目录不存在则新建）。
   - 把 `target/activation/cursor-settings.json` 的内容合并到 `C:\Users\<用户名>\AppData\Roaming\Cursor\User\settings.json`，确保包含：
     ```json
     "cursor.general.disableHttp2": true,
     "cursor.general.disableHttp1SSE": false
     ```
3. **修改 `.augpro.json`**：将其中的 `API_WORKER_URL` / `API_WORKER_HOST` / `LS_URL` 由 `127.0.0.1:9182` 改为 `10.40.111.234:8634`。
4. **复制补丁文件**：把 `target/patches/` 下的所有文件，按相同相对路径覆盖到 TARGET 的 Cursor 安装目录下（通常是 `C:\Users\<用户名>\AppData\Local\Programs\Cursor\resources\app\`）。
5. **确认本机转发器运行**：本机 `api-forwarder` 监听 `0.0.0.0:8634`，可通过 `curl http://10.40.111.234:8634/v1/models` 验证。
6. **启动 Cursor**：TARGET 上启动 Cursor，应能看到“已激活”状态，AI 请求将走本机中转。

## 回退方案

若补丁在 TARGET 上因 Cursor 版本差异失效，可改用：
- 在 TARGET 装 **VS Code + Claude Code 插件**，设置 `ANTHROPIC_BASE_URL=http://10.40.111.234:8634`；
- 或直接在 TARGET 浏览器/Cursor 设置里把 OpenAI/Anthropic Base URL 指向 `http://10.40.111.234:8634/v1`（不依赖补丁，但可能无法覆盖 Composer/Agent 等自有协议流量）。

---

# 03. 激活原理与注意事项

## 激活是“静态文件 + 时间窗口”，而非纯实时在线校验

Vibe助手 对 Cursor 的激活机制分两层：

### 1. 静态凭据文件（一次性写入）
- `.augpro.json`：XOR 37 混淆后的 JSON，包含 `CURSOR_TOKEN`、`API_WORKER_URL`、`CODE_POOL_AT` 等。这是 Cursor 启动时读取的“已登录/已激活”凭据。
- `api-worker\.auth`：api-worker 与 Cursor 之间的鉴权 Token。

### 2. 时间窗口有效性（CODE_POOL_AT）
`.augpro.json` 中的 `CODE_POOL_AT` 是一个**过期时间戳**（例如 `1800189638330`，对应 2027 年左右）。Vibe助手 启动 Cursor 时会写入该时间；Cursor 读取后判断是否在有效期内。

- **未过期**：Cursor 认为激活有效，无需弹出登录框。
- **已过期**：激活状态失效，Cursor 会要求重新登录，需重新从 Vibe助手 获取新 Token 并覆盖 `.augpro.json`。

### 3. 是否实时？
- **不是实时在线校验**：Cursor 本身不会每次请求都去问 Vibe助手 “我还激活吗？”；它只读取本地 `.augpro.json`。
- **但有效期是静态绑定的**：Token 和过期时间在 Vibe助手 界面操作时生成并写入，之后直到过期前都有效。若 Vibe助手 后台吊销了该 Token，本地 `.augpro.json` 不会自动失效（除非过期或被重新写入）。

## 注意事项

| 项目 | 说明 |
|---|---|
| **版本绑定** | 补丁文件与本机 Cursor 3.18.25 版本绑定。若 TARGET 上的 Cursor 版本不同，补丁可能不匹配，导致启动失败或激活不生效。 |
| **无管理员权限** | 所有部署路径都在用户目录下，无需管理员权限即可写入。 |
| **网络依赖** | AI 请求最终通过本机 `10.40.111.234:8634` 转发到本机 api-worker（`127.0.0.1:9182`），再走 Vibe助手 渠道。本机必须保持联网且转发器在运行。 |
| **凭据保密** | `.augpro.json` 和 `.auth` 包含账号凭据，泄露后他人可消耗你的额度。不要上传到 GitHub、不要发给不可信的人。 |
| **更新失效风险** | Cursor 自动升级会覆盖被补丁的 JS 文件，激活会失效。建议在 TARGET 上关闭 Cursor 自动更新，或升级后重新复制补丁。 |

# 04. �Զ����ű�

## `target/update-from-local.ps1`

��**�������� Vibe���� ���� Cursor ��**���С��ű�ʹ������ڽű�Ŀ¼��·�����ѵ�ǰ Cursor �汾�ļ����ļ��Ͳ���ˢ�µ� `target/`��

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\target\update-from-local.ps1
```

Ĭ�ϲ���
- ��ǰ Cursor �汾��д�� `target/cursor-version.txt`��ĿǰΪ `3.31.15`����
- ���� `target/activation/augpro.json`���ű�����ʱ������ XOR 37 д��Ŀ���û��� `.augpro.json`����
- `target/activation/api-worker/.auth`��
- ��ǰ Cursor �� `settings.json`��
- 10 �� Cursor ����/���� JS �ļ���

�ű���Ĭ�ϰ�Ŀ�� API ��ַ����Ϊ��`http://10.40.111.234:8634`�����ַ�ı䣺

```powershell
.\target\update-from-local.ps1 -BridgeUrl 'http://�µĵ�ַ:8634'
```

## `target/deploy-to-target.ps1`

������ `target` �ļ��и��Ƶ� TARGET��Ȼ���� TARGET �� PowerShell �����У�

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\target\deploy-to-target.ps1
```

�ű���
1. ��� TARGET Cursor �汾�� `cursor-version.txt`��
2. ���� TARGET ԭ�ļ��� `resources\app\.claudecodebridge-backup`��
3. ���ǲ����ļ���
4. ������ `augpro.json` ���� XOR 37��д�� TARGET �û��� `.augpro.json`��
5. д�� `api-worker\.auth`��
6. �ϲ� `disableHttp2` / `disableHttp1SSE` ���ã������������û����á�

���汾ȷʵ��ͬ����ȷ�ϲ������ݣ���ʹ�ã�

```powershell
.\target\deploy-to-target.ps1 -SkipVersionCheck
```

�ű������� TARGET ���� Vibe���֣������� Vibe���� api-worker �� `8634` forwarder ���뱣�����С�

## �汾��������

1. ���� Cursor ���²����µ�� Vibe���� �ġ������
2. ��ȫ�˳� Cursor��
3. �������� `update-from-local.ps1`��
4. ��� `target/cursor-version.txt` �� `target/activation/augpro.json`��
5. ͨ�����߽���/���������� `target` �� TARGET��
6. TARGET ���� `deploy-to-target.ps1`��

## 05. 8633 �Ƿ���Ҫ

**ֻ�� Vibe���� Cursor ����ת��ʱ������Ҫ 8633��**

- `8634`��TARGET Cursor �Ѵ򲹶���� AI/API ���� �� ���� `127.0.0.1:9182` api-worker���������С�
- `8633`���������� TARGET Cursor ���� `cursor.com`����¼�����µȹ��������� HTTP CONNECT ������������Ǽ��� API �ı���˿ڡ�

��� TARGET Cursor �Ѿ��п��õĹ������磬�ر� 8633 ���ɡ��� TARGET ��ȫ���ܷ��ʹ����һ�Ҫ��¼/���£����������� 8633����������������� TARGET �ṩ�������ڡ�

## 06. ��ȫ

`target/activation/` �� `target/patches/` �ѱ� `.gitignore` �ų�����Ҫǿ�� `git add -f` ���ǣ�Ҳ��Ҫ�� `augpro.json`��`.auth` �򲹶��ϴ��� GitHub��`augpro.json` ����������ƾ�ݣ������ڱ������߸��ơ�
