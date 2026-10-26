$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 2.0
$repository = Split-Path -Parent $PSScriptRoot
Import-Module (Join-Path $repository 'Bridge.Core.psm1') -Force
$script:checks = 0
function Assert-Bridge([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw ('FAIL: ' + $Message) }
    $script:checks++
    Write-Host ('PASS: ' + $Message)
}
function Assert-Throws([scriptblock]$Action, [string]$Message) {
    $thrown = $false
    try { $null = & $Action } catch { $thrown = $true }
    Assert-Bridge $thrown $Message
}
foreach ($file in @(Get-ChildItem -LiteralPath $repository -Recurse -File | Where-Object Extension -in @('.ps1','.psm1'))) {
    $tokens = $null; $errors = $null
    $null = [Management.Automation.Language.Parser]::ParseFile($file.FullName, [ref]$tokens, [ref]$errors)
    Assert-Bridge ($errors.Count -eq 0) ('parse ' + $file.Name)
    $bytes = [IO.File]::ReadAllBytes($file.FullName)
    Assert-Bridge ($bytes.Length -ge 3 -and $bytes[0] -eq 239 -and $bytes[1] -eq 187 -and $bytes[2] -eq 191) ('UTF-8 BOM ' + $file.Name)
}
Assert-Bridge ((ConvertTo-BridgeProxy 'http://127.0.0.1:7890/') -eq 'http://127.0.0.1:7890') 'normalize loopback proxy'
Assert-Bridge ((ConvertTo-BridgeProxy 'http://[::1]:7890') -eq 'http://[::1]:7890') 'IPv6 loopback proxy'
foreach ($invalid in @('socks5://127.0.0.1:7890','https://localhost:7890','http://example.com:7890','http://user:secret@localhost:7890','http://localhost:7890/path','http://localhost:7890/?q=x','http://localhost:7890/#x','http://localhost:99999','http://localhost:0','http://localhost:7890 --bad-option')) {
    Assert-Throws { ConvertTo-BridgeProxy $invalid } ('reject unsupported proxy ' + ($invalid -replace 'user:secret', '[credentials]'))
}
Assert-Bridge (@(Get-BridgeProxyCandidates -ProxyUrl 'http://127.0.0.1:45678').Count -eq 1) 'explicit proxy never silently falls back'
$sandbox = Join-Path ([IO.Path]::GetTempPath()) ('ChatGPT-Bridge-Test-' + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $sandbox | Out-Null
$listener = New-Object Net.Sockets.TcpListener([Net.IPAddress]::Loopback, 0)
$listener.Start(100)
try {
    $port = $listener.LocalEndpoint.Port
    $proxy = 'http://127.0.0.1:' + $port
    Assert-Bridge (Test-BridgePort $proxy) 'reachable local listener'
    $resolved = Resolve-BridgeProxy -ProxyUrl $proxy
    Assert-Bridge ($resolved -eq $proxy) 'resolve explicit reachable listener'
    $fakeApp = Join-Path $sandbox 'ChatGPT.exe'
    [IO.File]::WriteAllText($fakeApp, 'NOT AN EXECUTABLE; tests must never launch this file.')
    $before = [Environment]::GetEnvironmentVariable('HTTPS_PROXY', 'Process')
    $startInfo = New-BridgeStartInfo -AppPath $fakeApp -ProxyUrl $proxy
    Assert-Bridge ($startInfo.EnvironmentVariables['HTTPS_PROXY'] -eq $proxy) 'child receives proxy'
    Assert-Bridge ($startInfo.EnvironmentVariables['WSS_PROXY'] -eq $proxy) 'child receives WebSocket proxy'
    Assert-Bridge ($startInfo.EnvironmentVariables['NO_PROXY'] -eq 'localhost,127.0.0.1,::1') 'child bypasses local services'
    Assert-Bridge ($startInfo.Arguments -eq ('--proxy-server=' + $proxy)) 'Chromium receives explicit proxy'
    Assert-Bridge (-not $startInfo.UseShellExecute) 'launch uses explicit child environment'
    Assert-Bridge ([Environment]::GetEnvironmentVariable('HTTPS_PROXY', 'Process') -eq $before) 'parent environment unchanged'
    $destination = Join-Path $sandbox 'installed files with spaces'
    $hostExecutable = (Get-Process -Id $PID).Path
    $installer = Join-Path $repository 'Install.ps1'
    $output = & $hostExecutable -NoLogo -NoProfile -ExecutionPolicy Bypass -File $installer -ProxyUrl $proxy -AppPath $fakeApp -InstallDirectory $destination -NoShortcut
    Assert-Bridge ($LASTEXITCODE -eq 0) 'isolated installation succeeds without desktop changes'
    $settings = Read-BridgeSettings $destination
    Assert-Bridge ($settings.proxy_url -eq $proxy) 'settings store selected local proxy'
    Assert-Bridge ($settings.app_path -eq $fakeApp) 'explicit app path preserved'
    $output = & $hostExecutable -NoLogo -NoProfile -ExecutionPolicy Bypass -File $installer -InstallDirectory $destination -NoShortcut
    Assert-Bridge ($LASTEXITCODE -eq 0) 'reinstallation preserves saved settings'
    $launcher = Join-Path $destination 'Start-ChatGPT.ps1'
    $checkOutput = & $hostExecutable -NoLogo -NoProfile -ExecutionPolicy Bypass -File $launcher -CheckOnly
    Assert-Bridge ($LASTEXITCODE -eq 0) 'CheckOnly succeeds without executing fake app'
    $check = ($checkOutput -join [Environment]::NewLine) | ConvertFrom-Json
    Assert-Bridge ($check.proxy_port_reachable -and -not $check.application_launched -and -not $check.global_settings_changed) 'CheckOnly reports actual preflight only'
    $unrelated = Join-Path $destination 'keep-me.txt'
    [IO.File]::WriteAllText($unrelated, 'Preserve this user file.')
    $uninstaller = Join-Path $destination 'Uninstall.ps1'
    $output = & $hostExecutable -NoLogo -NoProfile -ExecutionPolicy Bypass -File $uninstaller
    Assert-Bridge ($LASTEXITCODE -eq 0) 'uninstall succeeds'
    Assert-Bridge (Test-Path -LiteralPath $unrelated) 'uninstall preserves unknown files'
    Assert-Bridge (-not (Test-Path -LiteralPath (Join-Path $destination 'installation.json'))) 'uninstall removes own marker'
    $unmanaged = Join-Path $sandbox 'unmanaged'
    New-Item -ItemType Directory -Path $unmanaged | Out-Null
    try {
        $ErrorActionPreference = 'Continue'
        $output = & $hostExecutable -NoLogo -NoProfile -ExecutionPolicy Bypass -File $installer -ProxyUrl $proxy -AppPath $fakeApp -InstallDirectory $unmanaged -NoShortcut 2>$null
        $refusedCode = $LASTEXITCODE
    } finally { $ErrorActionPreference = 'Stop' }
    Assert-Bridge ($refusedCode -ne 0) 'installer refuses an unmarked existing directory'
    $listener.Stop()
    Assert-Bridge (-not (Test-BridgePort $proxy -TimeoutMs 300)) 'closed listener is rejected'
} finally {
    $listener.Stop()
    # Remove only known test files, without recursive deletion or touching desktop/application state.
    foreach ($file in @('ChatGPT.exe','installed files with spaces\keep-me.txt')) {
        $path = Join-Path $sandbox $file
        if (Test-Path -LiteralPath $path -PathType Leaf) { Remove-Item -LiteralPath $path }
    }
    foreach ($relative in @('installed files with spaces','unmanaged')) {
        $path = Join-Path $sandbox $relative
        if ((Test-Path -LiteralPath $path -PathType Container) -and @(Get-ChildItem -LiteralPath $path -Force).Count -eq 0) { Remove-Item -LiteralPath $path }
    }
    if (@(Get-ChildItem -LiteralPath $sandbox -Force).Count -eq 0) { Remove-Item -LiteralPath $sandbox }
}
Write-Host ('All {0} checks passed. No real application was launched.' -f $script:checks)
