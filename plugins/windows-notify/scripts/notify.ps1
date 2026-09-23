<#
.SYNOPSIS
    Shows a Windows toast notification for a Claude Code hook event.

.DESCRIPTION
    Invoked by the windows-notify plugin's Stop and Notification hooks.
    Reads the hook payload from stdin (to recover the project directory) and
    raises a toast through the Windows notification platform.

    This script is deliberately ASCII-only. Windows PowerShell 5.1 reads .ps1
    files using the system ANSI code page unless they carry a UTF-8 BOM, so any
    non-ASCII literal here would corrupt quote pairing on non-Western locales.
    Message text is overridable via environment variables instead.

.PARAMETER Kind
    'done'  - a turn finished
    'input' - Claude is waiting on the user

.NOTES
    Always exits 0. A notification is a convenience; it must never turn into a
    hook failure that interrupts the user's session.
#>
[CmdletBinding()]
param(
    [ValidateSet('done', 'input')]
    [string]$Kind = 'done'
)

# AppID decides the name and icon shown in Action Center. We default to the
# stock Windows PowerShell AppID because it needs no installation step. If the
# user has opted in by running register-appid.ps1, prefer the real one.
$CustomAppId    = 'ClaudeCode.Notify'
$FallbackAppId  = '{1AC14E77-02E7-4E5D-B744-2EB1AE5198B7}\WindowsPowerShell\v1.0\powershell.exe'

function Get-AppId {
    try {
        if (Test-Path "HKCU:\SOFTWARE\Classes\AppUserModelId\$CustomAppId") { return $CustomAppId }
    } catch { }
    return $FallbackAppId
}

function Get-HookPayload {
    # Only read stdin when it is actually redirected. Reading an interactive
    # console would block until EOF and hang the hook.
    if (-not [Console]::IsInputRedirected) { return $null }
    try {
        $raw = [Console]::In.ReadToEnd()
        if ([string]::IsNullOrWhiteSpace($raw)) { return $null }
        return $raw | ConvertFrom-Json
    } catch {
        return $null
    }
}

function Invoke-AudibleFallback {
    param([bool]$Silent)
    if ($Silent) { return }
    try {
        [System.Media.SystemSounds]::Asterisk.Play()
        # Play() is asynchronous; give it a moment before the process exits.
        Start-Sleep -Milliseconds 400
    } catch {
        try { [Console]::Beep(880, 200) } catch { }
    }
}

# --- Opt-out ------------------------------------------------------------
if ($env:CLAUDE_NOTIFY_DISABLED -eq '1') { exit 0 }

$silent = ($env:CLAUDE_NOTIFY_SILENT -eq '1')

# --- Context ------------------------------------------------------------
$payload = Get-HookPayload
$cwd = if ($payload -and $payload.cwd) { $payload.cwd } else { (Get-Location).Path }

$project = try { Split-Path $cwd -Leaf } catch { $cwd }
if ([string]::IsNullOrWhiteSpace($project)) { $project = $cwd }

$title = if ($env:CLAUDE_NOTIFY_TITLE) { $env:CLAUDE_NOTIFY_TITLE } else { 'Claude Code' }

if ($Kind -eq 'input') {
    $headline = if ($env:CLAUDE_NOTIFY_TEXT_INPUT) { $env:CLAUDE_NOTIFY_TEXT_INPUT } else { 'Waiting for your input' }
    $sound    = 'ms-winsoundevent:Notification.IM'
} else {
    $headline = if ($env:CLAUDE_NOTIFY_TEXT_DONE) { $env:CLAUDE_NOTIFY_TEXT_DONE } else { 'Turn complete' }
    $sound    = 'ms-winsoundevent:Notification.Default'
}

$subtitle = '{0} - {1}' -f $project, (Get-Date -Format 'HH:mm:ss')

# --- Compose ------------------------------------------------------------
function ConvertTo-XmlText {
    param([string]$Text)
    return [System.Security.SecurityElement]::Escape($Text)
}

$audioNode = if ($silent) { '<audio silent="true"/>' } else { '<audio src="' + $sound + '"/>' }

$toastXml = @"
<toast>
  <visual>
    <binding template="ToastGeneric">
      <text>$(ConvertTo-XmlText $title)</text>
      <text>$(ConvertTo-XmlText $headline)</text>
      <text>$(ConvertTo-XmlText $subtitle)</text>
    </binding>
  </visual>
  $audioNode
</toast>
"@

# --- Show ---------------------------------------------------------------
try {
    [void][Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime]
    [void][Windows.Data.Xml.Dom.XmlDocument, Windows.Data.Xml.Dom.XmlDocument, ContentType = WindowsRuntime]

    $doc = New-Object Windows.Data.Xml.Dom.XmlDocument
    $doc.LoadXml($toastXml)

    $toast = New-Object Windows.UI.Notifications.ToastNotification $doc
    [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier((Get-AppId)).Show($toast)
} catch {
    # No notification platform (Server Core, stripped images, policy). Degrade
    # to a sound rather than failing silently.
    Invoke-AudibleFallback -Silent $silent
}

exit 0
