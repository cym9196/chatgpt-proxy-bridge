[CmdletBinding()]
param([string]$ProxyUrl, [string]$AppPath, [switch]$Network, [switch]$CompareDirect)
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'Bridge.Core.psm1') -Force
try {
    if ($CompareDirect -and -not $Network) { throw '-CompareDirect requires -Network.' }
    $settings = Read-BridgeSettings -Directory $PSScriptRoot
    if ($settings) {
        if (-not $ProxyUrl) { $ProxyUrl = [string]$settings.proxy_url }
        if (-not $AppPath) { $AppPath = [string]$settings.app_path }
    }
    $proxy = Resolve-BridgeProxy -ProxyUrl $ProxyUrl
    $app = Find-BridgeApp -AppPath $AppPath
    $report = [ordered]@{version='1.0.0';proxy=$proxy;proxy_port_reachable=$true;package=$app.Package;
        app_version=$app.Version;application_running=(@(Get-BridgeRunningApp $app.Path).Count -gt 0);
        authenticated_websocket_tested=$false;application_launched=$false;global_settings_changed=$false;
        note='An open local port is not proof of a working HTTP proxy or a successful authenticated connection.'}
    if ($Network) {
        $curl = Get-Command curl.exe -ErrorAction Stop
        $checks = @()
        foreach ($endpoint in @('https://codex-cloud-backend.chatgpt.com/', 'https://chatgpt.com/backend-api/codex/responses')) {
            $routes = @('proxy')
            if ($CompareDirect) { $routes += 'direct' }
            foreach ($route in $routes) {
                $info = New-Object Diagnostics.ProcessStartInfo
                $info.FileName = $curl.Source
                $info.UseShellExecute = $false
                $info.CreateNoWindow = $true
                $info.RedirectStandardOutput = $true
                $info.RedirectStandardError = $true
                # Fixed endpoints and validated loopback proxy: no user-supplied shell command is executed.
                $routeOptions = if ($route -eq 'proxy') {'--proxy ' + $proxy + ' --noproxy ""'} else {'--noproxy "*"'}
                $info.Arguments = '--disable --silent --output NUL --write-out "%{http_code}" --connect-timeout 4 --max-time 6 ' + $routeOptions + ' ' + $endpoint
                $process = New-Object Diagnostics.Process
                $process.StartInfo = $info
                $null = $process.Start()
                $status = $process.StandardOutput.ReadToEnd().Trim()
                $null = $process.StandardError.ReadToEnd()
                $process.WaitForExit()
                $checks += [pscustomobject]@{endpoint=$endpoint;route=$route;curl_exit_code=$process.ExitCode;http_status=$status}
                $process.Dispose()
            }
        }
        $report['network_checks'] = $checks
        $report['interpretation'] = '401/403 can demonstrate a server response without authentication. They do not establish a successful signed-in WebSocket or Work session.'
    }
    [pscustomobject]$report | ConvertTo-Json -Depth 5
} catch { Write-Error $_.Exception.Message; exit 1 }
