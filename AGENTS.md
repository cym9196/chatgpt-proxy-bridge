# AI setup instructions

This repository is ChatGPT Proxy Bridge, a Windows-only, per-launch local HTTP-proxy workaround for ChatGPT desktop reconnection problems. Read README.md and docs/AI-SETUP.md before setup. The successful original case is described in docs/HOW-IT-WORKS.md; do not promise a universal fix.

When a user asks to set it up, execute the local setup rather than only explaining it:

1. Confirm Windows and read the scripts before executing them. Use the current user's normal shell; no administrator privileges are needed.
2. Use `powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File .\Install.ps1`. It detects a listening local proxy from the current settings, system proxy, environment and common ports. A listening port is only a candidate, not proof of proxy compatibility. If the actual HTTP/mixed port is known, supply `-ProxyUrl http://127.0.0.1:PORT` instead. Do not select a SOCKS-only port. Do not request subscription URLs or node credentials.
3. Run `powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "$env:LOCALAPPDATA\ChatGPTProxyBridge\Start-ChatGPT.ps1" -CheckOnly`. This does not launch or exit the app. Report its actual result.
4. Do not kill or restart ChatGPT while hosting an active chat. Ask the user to finish tasks, fully exit from the app menu, and reopen using the new desktop shortcut. A second instance can reuse the original process and miss the proxy environment. Do not call the solution verified until the user confirms both the affected chat/Work flow and the disappearance of reconnects.
5. If necessary, run the installed `Diagnose.ps1 -Network` (optional anonymous network checks). Do not read auth files, cookies, tokens, entire chat logs, or private proxy configs. A 401/403 response is not an authenticated WebSocket handshake. Diagnose ordinary chat and Work separately.

Keep all proxy environment variables scoped to the new child process. Never persist them to Windows user/system settings. Do not change TUN, WinHTTP, DNS, routing, firewall rules, TLS validation, installed app files, or startup tasks as part of setup. Do not launch an external app from a hidden background task unless the user requests it; the desktop shortcut hides only the launcher console.

Uninstall only with the installed Uninstall.ps1. Preserve unknown files and existing shortcuts. Do not publish local settings.json, installation.json, proxy configurations, logs, or tokens. Run tests/Run-Tests.ps1 after code changes. Source PowerShell files use UTF-8 BOM for Windows PowerShell 5.1 Chinese text compatibility.
