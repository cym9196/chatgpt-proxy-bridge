[CmdletBinding()]
param([switch]$CheckOnly, [switch]$NoGui)
$ErrorActionPreference = 'Stop'
try {
    Import-Module (Join-Path $PSScriptRoot 'Bridge.Core.psm1') -Force
    $settings = Read-BridgeSettings -Directory $PSScriptRoot
    if (-not $settings) { throw 'Run Install.cmd first / 请先运行 Install.cmd。' }
    $proxy = ConvertTo-BridgeProxy $settings.proxy_url
    $app = Find-BridgeApp -AppPath $settings.app_path
    $reachable = Test-BridgePort $proxy
    $running = @(Get-BridgeRunningApp -AppPath $app.Path).Count -gt 0
    if ($CheckOnly) {
        [pscustomobject]@{status=$(if ($reachable) {'ready'} else {'proxy_unreachable'});proxy=$proxy;
            application=$app.Path;package=$app.Package;version=$app.Version;proxy_port_reachable=$reachable;
            application_running=$running;application_launched=$false;global_settings_changed=$false} | ConvertTo-Json
        if (-not $reachable) { exit 1 }
        exit 0
    }
    if (-not $reachable) { throw '本地代理未启动或端口已改变。请先打开代理客户端；端口改变后重新运行 Install.ps1 -ProxyUrl http://127.0.0.1:端口。' }
    if ($running) {
        $message = '请先在 ChatGPT 菜单中选择“退出”，等待应用完全关闭，再使用此图标启动。仅关闭窗口可能仍在后台运行。'
        if ($NoGui) { Write-Host $message } else { Show-BridgeMessage $message }
        exit 2
    }
    $startInfo = New-BridgeStartInfo -AppPath $app.Path -ProxyUrl $proxy
    $null = [Diagnostics.Process]::Start($startInfo)
} catch {
    if ($CheckOnly -or $NoGui) { Write-Error $_.Exception.Message }
    else {
        Add-Type -AssemblyName PresentationFramework
        [Windows.MessageBox]::Show(('启动未完成：' + $_.Exception.Message), 'ChatGPT Proxy Bridge') | Out-Null
    }
    exit 1
}
