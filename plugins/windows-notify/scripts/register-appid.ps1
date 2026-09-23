<#
.SYNOPSIS
    Optional: register a dedicated AppUserModelID so toasts are attributed to
    "Claude Code" instead of "Windows PowerShell".

.DESCRIPTION
    Without this, notify.ps1 borrows the stock Windows PowerShell AppID, which
    works with zero setup but shows the PowerShell name and icon in Action
    Center. Running this script writes a single key under HKEY_CURRENT_USER
    (no admin rights, no machine-wide change) and notify.ps1 picks it up
    automatically on the next notification.

    Fully reversible: re-run with -Unregister.

.PARAMETER IconPath
    Optional path to a .ico file to show alongside the notification. Windows
    requires a local file; it is read at display time, so keep it somewhere
    permanent.

.PARAMETER Unregister
    Remove the key and fall back to the PowerShell AppID.

.EXAMPLE
    .\register-appid.ps1
    .\register-appid.ps1 -IconPath C:\Users\me\claude.ico
    .\register-appid.ps1 -Unregister
#>
[CmdletBinding()]
param(
    [string]$IconPath,
    [switch]$Unregister
)

$ErrorActionPreference = 'Stop'

$AppId = 'ClaudeCode.Notify'
$Key   = "HKCU:\SOFTWARE\Classes\AppUserModelId\$AppId"

if ($Unregister) {
    if (Test-Path $Key) {
        Remove-Item -Path $Key -Recurse -Force
        Write-Host "Unregistered $AppId. Toasts will fall back to the Windows PowerShell identity."
    } else {
        Write-Host "$AppId was not registered; nothing to do."
    }
    return
}

if (-not (Test-Path $Key)) {
    New-Item -Path $Key -Force | Out-Null
}

New-ItemProperty -Path $Key -Name 'DisplayName' -Value 'Claude Code' -PropertyType String -Force | Out-Null

if ($IconPath) {
    $resolved = (Resolve-Path -LiteralPath $IconPath).Path
    if ([System.IO.Path]::GetExtension($resolved).ToLowerInvariant() -ne '.ico') {
        throw "IconPath must point to a .ico file. Got: $resolved"
    }
    New-ItemProperty -Path $Key -Name 'IconUri' -Value $resolved -PropertyType String -Force | Out-Null
    Write-Host "Icon set to $resolved"
}

Write-Host "Registered $AppId under HKCU. Toasts will now be attributed to 'Claude Code'."
Write-Host "Undo at any time with: .\register-appid.ps1 -Unregister"
