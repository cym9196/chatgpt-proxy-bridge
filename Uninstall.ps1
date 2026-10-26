[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
try {
    $directory = [IO.Path]::GetFullPath($PSScriptRoot)
    $markerPath = Join-Path $directory 'installation.json'
    if (-not (Test-Path -LiteralPath $markerPath -PathType Leaf)) { throw 'Run Uninstall.ps1 from the installed Bridge folder, not the source checkout.' }
    $marker = Get-Content -LiteralPath $markerPath -Raw -Encoding UTF8 | ConvertFrom-Json
    if ($marker.project -ne 'chatgpt-proxy-bridge') { throw 'Invalid installation marker.' }
    $shortcutRemoved = $false
    $expectedShortcut = Join-Path ([Environment]::GetFolderPath('Desktop')) 'ChatGPT Proxy Bridge.lnk'
    if ($marker.shortcut_path -eq $expectedShortcut -and (Test-Path -LiteralPath $expectedShortcut -PathType Leaf)) {
        $shell = New-Object -ComObject WScript.Shell
        $shortcut = $shell.CreateShortcut($expectedShortcut)
        $launcher = Join-Path $directory 'Start-ChatGPT.ps1'
        if ([IO.Path]::GetFileName($shortcut.TargetPath) -eq 'powershell.exe' -and $shortcut.Arguments -like ('*"' + $launcher + '"*')) {
            Remove-Item -LiteralPath $expectedShortcut
            $shortcutRemoved = $true
        }
    }
    # Delete only this fixed list. Preserve unrelated files and never recursively remove a directory.
    foreach ($file in @('Bridge.Core.psm1','Start-ChatGPT.ps1','Diagnose.ps1','settings.json','installation.json','Uninstall.ps1')) {
        $target = Join-Path $directory $file
        if (Test-Path -LiteralPath $target -PathType Leaf) { Remove-Item -LiteralPath $target }
    }
    if (@(Get-ChildItem -LiteralPath $directory -Force).Count -eq 0) { Remove-Item -LiteralPath $directory }
    [pscustomobject]@{status='uninstalled';shortcut_removed=$shortcutRemoved;application_stopped=$false;global_settings_changed=$false} | ConvertTo-Json
} catch { Write-Error $_.Exception.Message; exit 1 }
