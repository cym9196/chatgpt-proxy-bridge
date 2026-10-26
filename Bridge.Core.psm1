Set-StrictMode -Version 2.0

function ConvertTo-BridgeProxy {
    param([Parameter(Mandatory)][string]$Value)
    $proxyUri = $null
    if (-not [Uri]::TryCreate($Value.Trim(), [UriKind]::Absolute, [ref]$proxyUri)) {
        throw 'Proxy must be an absolute URL such as http://127.0.0.1:7890.'
    }
    $proxyHost = $proxyUri.DnsSafeHost.Trim('[', ']').ToLowerInvariant()
    $parsedAddress = $null
    if ([Net.IPAddress]::TryParse($proxyHost, [ref]$parsedAddress)) { $proxyHost = $parsedAddress.ToString() }
    if ($proxyUri.Scheme -ne 'http' -or $proxyHost -notin @('localhost', '127.0.0.1', '::1') -or
        $proxyUri.UserInfo -or $proxyUri.Query -or $proxyUri.Fragment -or $proxyUri.AbsolutePath -ne '/' -or
        $proxyUri.Port -lt 1 -or $proxyUri.Port -gt 65535) {
        throw 'Use a local HTTP or mixed proxy port. Remote proxies, credentials and SOCKS URLs are not supported.'
    }
    if ($proxyHost -eq '::1') { $proxyHost = '[::1]' }
    return 'http://{0}:{1}' -f $proxyHost, $proxyUri.Port
}

function Test-BridgePort {
    param([Parameter(Mandatory)][string]$ProxyUrl, [int]$TimeoutMs = 1500)
    $proxyUri = [Uri](ConvertTo-BridgeProxy $ProxyUrl)
    $client = New-Object Net.Sockets.TcpClient
    try {
        $pending = $client.ConnectAsync($proxyUri.DnsSafeHost.Trim('[', ']'), $proxyUri.Port)
        return ($pending.Wait($TimeoutMs) -and $client.Connected)
    } catch { return $false } finally { $client.Dispose() }
}

function Get-BridgeProxyCandidates {
    param([string]$ProxyUrl, [string]$SavedProxy)
    if ($ProxyUrl) { return ,(ConvertTo-BridgeProxy $ProxyUrl) }
    $candidates = New-Object 'Collections.Generic.List[string]'
    if ($SavedProxy) { $candidates.Add($SavedProxy) }
    $systemProxy = Get-ItemProperty -LiteralPath 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings' -ErrorAction SilentlyContinue
    if ($systemProxy -and $systemProxy.PSObject.Properties['ProxyEnable'] -and $systemProxy.ProxyEnable -eq 1 -and
        $systemProxy.PSObject.Properties['ProxyServer']) {
        foreach ($part in ([string]$systemProxy.ProxyServer -split ';')) {
            $address = $part.Trim()
            if ($address -match '^(?:http|https)=(.+)$') { $address = $Matches[1] }
            elseif ($address.Contains('=')) { continue }
            if ($address -and -not $address.Contains('://')) { $address = 'http://' + $address }
            if ($address) { $candidates.Add($address) }
        }
    }
    foreach ($name in @('HTTPS_PROXY', 'HTTP_PROXY', 'ALL_PROXY')) {
        $value = [Environment]::GetEnvironmentVariable($name, 'Process')
        if ($value) { $candidates.Add($value) }
    }
    foreach ($port in @(7890, 7897, 10809, 8080)) { $candidates.Add(('http://127.0.0.1:{0}' -f $port)) }
    $seen = @{}
    foreach ($candidate in $candidates) {
        try { $normalized = ConvertTo-BridgeProxy $candidate } catch { continue }
        if (-not $seen.ContainsKey($normalized)) { $seen[$normalized] = $true; $normalized }
    }
}

function Resolve-BridgeProxy {
    param([string]$ProxyUrl, [string]$SavedProxy)
    foreach ($candidate in @(Get-BridgeProxyCandidates -ProxyUrl $ProxyUrl -SavedProxy $SavedProxy)) {
        if (Test-BridgePort $candidate) { return $candidate }
    }
    throw 'No reachable local proxy found. Start your proxy client, then specify its HTTP/mixed port with -ProxyUrl.'
}

function Find-BridgeApp {
    param([string]$AppPath)
    if ($AppPath) {
        $item = Get-Item -LiteralPath $AppPath -ErrorAction Stop
        if ($item.PSIsContainer -or $item.Name -notin @('ChatGPT.exe', 'Codex.exe')) {
            throw '-AppPath must point to ChatGPT.exe or Codex.exe.'
        }
        return [pscustomobject]@{ Path = $item.FullName; Package = 'custom'; Version = 'unknown' }
    }
    foreach ($packageName in @('OpenAI.Codex', 'OpenAI.ChatGPT')) {
        $packages = @(Get-AppxPackage -Name $packageName -ErrorAction SilentlyContinue | Sort-Object Version -Descending)
        foreach ($package in $packages) {
            foreach ($relative in @('app\ChatGPT.exe', 'ChatGPT.exe', 'app\Codex.exe', 'Codex.exe')) {
                $candidate = Join-Path $package.InstallLocation $relative
                if (Test-Path -LiteralPath $candidate -PathType Leaf) {
                    return [pscustomobject]@{ Path = $candidate; Package = $package.Name; Version = [string]$package.Version }
                }
            }
        }
    }
    throw 'ChatGPT desktop app not found. Install it first, or provide -AppPath for a different installation layout.'
}

function Read-BridgeSettings {
    param([Parameter(Mandatory)][string]$Directory)
    $settingsPath = Join-Path $Directory 'settings.json'
    if (-not (Test-Path -LiteralPath $settingsPath -PathType Leaf)) { return $null }
    $settings = Get-Content -LiteralPath $settingsPath -Raw -Encoding UTF8 | ConvertFrom-Json
    if ($settings.schema_version -ne 1) { throw 'Unsupported settings version. Reinstall from a matching project version.' }
    $null = ConvertTo-BridgeProxy $settings.proxy_url
    return $settings
}

function New-BridgeStartInfo {
    param([Parameter(Mandatory)][string]$AppPath, [Parameter(Mandatory)][string]$ProxyUrl)
    $normalized = ConvertTo-BridgeProxy $ProxyUrl
    $info = New-Object Diagnostics.ProcessStartInfo
    $info.FileName = $AppPath
    $info.WorkingDirectory = Split-Path -Parent $AppPath
    $info.UseShellExecute = $false
    $info.Arguments = '--proxy-server=' + $normalized
    foreach ($name in @('HTTP_PROXY', 'HTTPS_PROXY', 'ALL_PROXY', 'WS_PROXY', 'WSS_PROXY')) {
        $info.EnvironmentVariables[$name] = $normalized
    }
    $info.EnvironmentVariables['NO_PROXY'] = 'localhost,127.0.0.1,::1'
    return $info
}

function Get-BridgeRunningApp {
    param([string]$AppPath)
    $name = [IO.Path]::GetFileNameWithoutExtension($AppPath)
    return @(Get-Process -Name $name -ErrorAction SilentlyContinue)
}

function Show-BridgeMessage {
    param([string]$Message)
    Add-Type -AssemblyName PresentationFramework
    [Windows.MessageBox]::Show($Message, 'ChatGPT Proxy Bridge') | Out-Null
}

Export-ModuleMember -Function ConvertTo-BridgeProxy, Test-BridgePort, Get-BridgeProxyCandidates, Resolve-BridgeProxy,
    Find-BridgeApp, Read-BridgeSettings, New-BridgeStartInfo, Get-BridgeRunningApp, Show-BridgeMessage
