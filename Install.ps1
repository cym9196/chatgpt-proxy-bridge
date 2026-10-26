[CmdletBinding()]
param(
    [string]$ProxyUrl,
    [string]$AppPath,
    [string]$InstallDirectory = (Join-Path $env:LOCALAPPDATA 'ChatGPTProxyBridge'),
    [switch]$NoShortcut
)
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'Bridge.Core.psm1') -Force
try {
    $destination = [IO.Path]::GetFullPath($InstallDirectory)
    if ($destination.TrimEnd('\') -eq $PSScriptRoot.TrimEnd('\')) { throw 'Choose an installation directory outside the source folder.' }
    $markerPath = Join-Path $destination 'installation.json'
    $previous = $null
    if (Test-Path -LiteralPath $destination) {
        if (-not (Test-Path -LiteralPath $markerPath -PathType Leaf)) { throw 'Installation directory already exists without a Bridge marker. Choose another directory.' }
        $previous = Get-Content -LiteralPath $markerPath -Raw -Encoding UTF8 | ConvertFrom-Json
        if ($previous.project -ne 'chatgpt-proxy-bridge') { throw 'Directory belongs to a different application.' }
    }
    $old = Read-BridgeSettings -Directory $destination
    $savedProxy = if ($old) { [string]$old.proxy_url } else { '' }
    $chosenProxy = Resolve-BridgeProxy -ProxyUrl $ProxyUrl -SavedProxy $savedProxy
    if (-not $AppPath -and $old -and $old.app_path) { $AppPath = [string]$old.app_path }
    $application = Find-BridgeApp -AppPath $AppPath
    $shortcutPath = if ($previous) { [string]$previous.shortcut_path } else { '' }
    $newShortcut = $null
    if (-not $NoShortcut) {
        $shortcutPath = Join-Path ([Environment]::GetFolderPath('Desktop')) 'ChatGPT Proxy Bridge.lnk'
        $shell = New-Object -ComObject WScript.Shell
        if (Test-Path -LiteralPath $shortcutPath) {
            $existing = $shell.CreateShortcut($shortcutPath)
            $expectedLauncher = Join-Path $destination 'Start-ChatGPT.ps1'
            if ($existing.Arguments -notlike ('*"' + $expectedLauncher + '"*') -or
                [IO.Path]::GetFileName($existing.TargetPath) -ne 'powershell.exe') {
                throw 'Desktop shortcut already exists and is not managed by this installation.'
            }
        }
        $newShortcut = $shell.CreateShortcut($shortcutPath)
    }
    New-Item -ItemType Directory -Path $destination -Force | Out-Null
    $payload = @('Bridge.Core.psm1', 'Start-ChatGPT.ps1', 'Diagnose.ps1', 'Uninstall.ps1')
    # Marker first: a partially completed installation can be repaired by rerunning this installer.
    [ordered]@{project='chatgpt-proxy-bridge';version='1.0.0';shortcut_path=$shortcutPath} |
        ConvertTo-Json | Set-Content -LiteralPath $markerPath -Encoding UTF8
    foreach ($file in $payload) { Copy-Item -LiteralPath (Join-Path $PSScriptRoot $file) -Destination (Join-Path $destination $file) -Force }
    [ordered]@{schema_version=1;proxy_url=$chosenProxy;app_path=$AppPath} |
        ConvertTo-Json | Set-Content -LiteralPath (Join-Path $destination 'settings.json') -Encoding UTF8
    if ($newShortcut) {
        $newShortcut.TargetPath = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
        $newShortcut.Arguments = '-NoLogo -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File "' + (Join-Path $destination 'Start-ChatGPT.ps1') + '"'
        $newShortcut.WorkingDirectory = $destination
        $newShortcut.IconLocation = $application.Path + ',0'
        $newShortcut.Description = 'Launch ChatGPT with your local proxy. Start the proxy client first.'
        $newShortcut.WindowStyle = 7
        $newShortcut.Save()
    }
    [pscustomobject]@{status='installed';version='1.0.0';proxy=$chosenProxy;application=$application.Path;
        directory=$destination;shortcut=$shortcutPath;application_launched=$false;global_settings_changed=$false} | ConvertTo-Json
    Write-Host '安装完成。先打开代理客户端，再双击桌面 ChatGPT Proxy Bridge。应用仍在运行时，请先从菜单完全退出。'
} catch { Write-Error $_.Exception.Message; exit 1 }
