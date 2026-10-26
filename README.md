# ChatGPT Proxy Bridge · 桌面代理桥

**让 ChatGPT 桌面版带着本地代理启动，缓解部分 Windows 环境中的 `reconnecting…` / `waiting for work`。**

Windows 10/11 · Windows PowerShell 5.1 · 无第三方脚本依赖 · 无需管理员权限 · MIT

适用于：已安装 ChatGPT 桌面版，也有可用的本地 HTTP/混合代理，但桌面版普通聊天或 Work 仍然反复重连。原始案例中，Windows 系统代理已经开启，工作通道仍超时；显式代理启动后，用户反馈重连提示消失。**这是特定环境已验证的绕行方案，不能保证解决所有网络、账号或服务端问题。**

## 让 AI 一次设置

把下面这段话和项目地址发给能操作你电脑的 AI：

> 请帮我安装 https://github.com/cym9196/chatgpt-proxy-bridge 。先阅读仓库的 AGENTS.md、README.md 和 docs/AI-SETUP.md，检查 Windows 上可用的本地 HTTP/混合代理，运行安装并完成 CheckOnly 验证，生成桌面快捷方式。不要结束我正在使用的 ChatGPT，也不要改系统代理、TUN、DNS、WinHTTP 或永久环境变量。最后告诉我如何完全退出应用后通过新图标验证普通聊天和 Work。

AI 必须具有本地文件与命令执行能力；仅能聊天的 AI 可以指导你操作，不能直接安装。仓库中的 [AI 配置指南](docs/AI-SETUP.md) 给出了可直接执行的步骤。

## 自己安装

1. 开启你的代理客户端，确认 HTTP/混合代理端口可用。
2. 下载仓库 ZIP 并解压，双击 **Install.cmd**。
3. 等当前聊天或任务完成后，从 ChatGPT 菜单中选择“退出”。仅关闭窗口可能还在后台运行。
4. 双击桌面的 **ChatGPT Proxy Bridge**。以后先开代理客户端，再用这个图标打开 ChatGPT。

如果自动找到的端口不对，在项目文件夹打开 PowerShell，明确指定，例如：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Install.ps1 -ProxyUrl http://127.0.0.1:7890
```

`7890` 只是常见端口示例，请使用自己的客户端显示的 HTTP/混合端口。支持 `localhost`、`127.0.0.1` 和 `[::1]` 回环地址；暂不支持带认证的代理、远程代理或 SOCKS URL。系统 PAC 规则不会被解析。

安装器优先尝试明确指定的地址；未指定时，依次检查已有 Bridge 设置、已开启的 Windows 系统代理、代理环境变量和常见端口。**自动检测只确认本地端口监听，不证明节点可用或端口确为 HTTP 代理。** 发现不符合实际的候选时，请手动指定。

## 它做了什么

- 自动查找当前安装的 `OpenAI.Codex` / `OpenAI.ChatGPT` 包，每次启动重新解析版本路径；也支持 `-AppPath` 指定其他布局的 `ChatGPT.exe` / `Codex.exe`。
- 为新应用进程提供 `HTTP_PROXY`、`HTTPS_PROXY`、`ALL_PROXY`、`WS_PROXY`、`WSS_PROXY` 和仅包含本地地址的 `NO_PROXY`。
- 同时传入 Chromium 参数 `--proxy-server=http://回环地址:端口`。
- 将启动文件保存在 `%LOCALAPPDATA%\ChatGPTProxyBridge`，创建普通桌面快捷方式，隐藏启动控制台。

安装不需要修改代理订阅或节点规则；不改 TUN、系统 DNS、WinHTTP、路由、防火墙、永久环境变量或应用安装文件；不关闭证书验证，也不读取登录凭证。已有进程不会被强制关闭。代理设置仅作用于由此入口启动的应用及继承环境的子进程，是否被具体网络组件采用取决于应用版本。

## 检查与排查

只检查应用位置和代理端口，不启动 ChatGPT：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$env:LOCALAPPDATA\ChatGPTProxyBridge\Start-ChatGPT.ps1" -CheckOnly
```

本地诊断默认不访问外网、不读取应用日志：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$env:LOCALAPPDATA\ChatGPTProxyBridge\Diagnose.ps1"
```

加上 `-Network` 可对两个固定公开端点做匿名 HTTP 请求；加上 `-Network -CompareDirect` 对比直连与代理。不发送账号凭证，不验证已登录的 WebSocket 会话。401/403 仅代表可能收到服务器响应，不能据此宣称 Work 已恢复。

如果原图标能打开而新图标报错，检查代理客户端和端口；如果仅 Work 重连，分别记录普通聊天和 Work 的表现。更多说明见 [故障排查](docs/TROUBLESHOOTING.md)。

## 更新、改端口与卸载

下载新版后重新运行 `Install.cmd` 即可覆盖 Bridge 自己的文件。端口变化时重新运行 `Install.ps1 -ProxyUrl ...`。自动发现的商店应用会在每次启动时重新定位；手动 `-AppPath` 在安装目录变化后需要更新。

退出 ChatGPT 后使用原图标，即可恢复原先的启动方式。卸载 Bridge：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$env:LOCALAPPDATA\ChatGPTProxyBridge\Uninstall.ps1"
```

卸载只移除 Bridge 自己的文件和对应快捷方式；不结束应用、不移除 ChatGPT、不删除未知文件。

## 测试与原理

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tests\Run-Tests.ps1
```

测试覆盖代理地址限制、端口选择、子进程环境隔离、安装与重复安装、检查模式和卸载保留未知文件；不启动真实 ChatGPT、不需要代理订阅。GitHub Actions 在 Windows PowerShell 5.1 与 PowerShell 7 下运行同一套测试。

详见 [原理与验证边界](docs/HOW-IT-WORKS.md)。项目为独立社区工具，与 OpenAI 或代理客户端厂商无隶属关系；不包含代理节点或服务。OpenAI 的通用[故障排查文档](https://learn.chatgpt.com/docs/reference/troubleshooting)不构成本工具有效性的保证。

## English

ChatGPT Proxy Bridge is a Windows per-launch proxy workaround for some ChatGPT desktop reconnect loops. It discovers a local HTTP/mixed proxy, creates a desktop shortcut, supplies explicit child-process proxy variables and Chromium's proxy argument, and leaves global Windows settings untouched. Start your proxy client, run `Install.cmd`, fully quit ChatGPT, then use the new shortcut. Read [English setup](docs/SETUP-EN.md) or ask a local AI agent to follow [AGENTS.md](AGENTS.md). One original user confirmed recovery; compatibility with other app versions and environments must be tested.
