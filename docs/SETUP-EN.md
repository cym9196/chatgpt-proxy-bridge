# Windows setup

1. Start your existing local proxy client. Use its HTTP or mixed port, not a SOCKS-only listener.
2. Download and extract this repository. Review the scripts, then run `Install.cmd`. No administrator privileges or third-party PowerShell modules are required.
3. Finish your active work, fully quit ChatGPT from its menu, and launch the new **ChatGPT Proxy Bridge** desktop shortcut.

To select a specific port:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Install.ps1 -ProxyUrl http://127.0.0.1:7890
```

Automatic detection checks saved Bridge settings, the enabled Windows system proxy, process proxy variables, and common local ports. A listening port is only a candidate. Override it if detection picks a different service. Only loopback HTTP URLs without credentials are supported. PAC and SOCKS URLs are not supported.

Check without launching or stopping the app:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$env:LOCALAPPDATA\ChatGPTProxyBridge\Start-ChatGPT.ps1" -CheckOnly
```

For optional anonymous network probes, run the installed `Diagnose.ps1 -Network`; add `-CompareDirect` for a direct comparison. No credentials, cookies or chat logs are accessed. HTTP 401/403 is not proof of a successful authenticated WebSocket or Work session.

The installer stores files under `%LOCALAPPDATA%\ChatGPTProxyBridge`. Proxy variables are supplied only to the launched process and its children; Chromium also receives a proxy argument. Windows global proxy settings, persistent environment variables, WinHTTP, DNS, TUN, routing, firewall, TLS validation and application files are untouched. Existing ChatGPT processes are never killed.

Rerun the installer to update or change ports. Automatic Microsoft Store package discovery follows app updates. For other layouts, supply `-AppPath 'C:\Path\To\ChatGPT.exe'` and update it if the app moves. To uninstall, run the installed `Uninstall.ps1`; unknown files are preserved.

This is an independent community workaround. One original user confirmed recovery from repeated reconnects, but other app versions and network components may ignore the settings. Verify the actual affected conversation and Work flow before declaring success. Local AI agents should follow [AGENTS.md](../AGENTS.md).
