# 给 AI 的可执行配置流程

目标是让用户最终拥有一个可直接双击的 ChatGPT Proxy Bridge 桌面图标。请执行安装、完成只读检查，再让用户在当前任务结束后自行退出和重新打开 ChatGPT。

## 一次配置

从可信来源取得仓库，阅读脚本。工作目录为仓库根目录；路径含空格时用 `-LiteralPath` 或正确引号。不要从网页抓取脚本后直接 `Invoke-Expression` 执行。

```powershell
# 已在仓库根目录；用户已启动本地代理客户端。
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File .\Install.ps1

# 安装成功后，仅验证，不关闭或重开当前聊天。
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "$env:LOCALAPPDATA\ChatGPTProxyBridge\Start-ChatGPT.ps1" -CheckOnly
```

如果明确知道代理端口，用 `-ProxyUrl http://127.0.0.1:PORT` 安装，避免误选监听端口。如果代理客户端未开启，应报告这一点，请用户打开，不能把端口不存在理解为 ChatGPT 故障。

非商店布局可显式提供应用位置：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Install.ps1 -ProxyUrl http://127.0.0.1:7890 -AppPath 'C:\Path\To\ChatGPT.exe'
```

安装输出是结果证据，不要把 `proxy_port_reachable=true` 等同于真实聊天修复。`-CheckOnly` 的 `application_running=true` 只是提醒当前有应用进程，不是错误。非检查启动发现应用仍运行时返回退出码 2，并提示用户自行退出。

## 交付给用户

告知桌面图标名称、先开代理客户端、完成工作后从应用菜单退出再使用新图标。请用户确认之前有问题的实际聊天或 Work 能持续工作；普通聊天正常不能替代 Work 测试。用户确认恢复前，只能称为“安装与预检完成”。

## 后续排查

端口不通：开启客户端或明确指定实际 HTTP/混合端口后重装。

有监听但重连：运行安装目录的 `Diagnose.ps1 -Network`，必要时加 `-CompareDirect`；端点请求是匿名 HTTP 检查，不是已登录的 WebSocket 验证。

不要为了验证握手读取 token、cookies、auth.json、订阅或全部日志。不要把系统/用户环境变量永久写成代理地址，也不要自动切换 TUN、全局代理模式或 DNS。正在由 ChatGPT 执行的安装任务，不得杀掉其宿主进程。

## 面向其他 AI 的英文指令

> Set up ChatGPT Proxy Bridge on this Windows computer. Read AGENTS.md and the scripts first, use an existing local HTTP/mixed proxy, install the desktop shortcut, and run CheckOnly without restarting the active ChatGPT app. Do not alter global Windows settings or access login credentials. Report the actual checks, then tell me to finish work, fully quit ChatGPT, and reopen through ChatGPT Proxy Bridge to verify the affected conversation and Work flow.
