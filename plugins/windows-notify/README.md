# windows-notify

Claude Code runs unattended for minutes at a time, and on Windows it finishes in
silence. This plugin raises a native Windows toast when a turn completes or when
Claude is waiting on you.

Claude Code's built-in `preferredNotifChannel` setting only supports iTerm2,
kitty, ghostty and the terminal bell — none of which produce an OS-level
notification on Windows. This plugin fills that gap with `Stop` and
`Notification` hooks.

## Requirements

- Windows 10 or 11
- Windows PowerShell 5.1 (`powershell.exe`, ships with Windows)

PowerShell 7 (`pwsh`) is **not** used, and that is deliberate: loading the WinRT
notification types is more awkward there. The hook pins `powershell.exe`.

## Install

```
claude plugin marketplace add https://github.com/a136-byte/claude-code-plugins.git
claude plugin install windows-notify@a136-byte-plugins
```

Restart Claude Code, or run `/reload-plugins`.

Use the full HTTPS URL rather than the `owner/repo` shorthand. The shorthand
clones over SSH, which requires a key registered with GitHub; the HTTPS form
needs no credentials at all for a public repository.

## What you get

| Hook event     | When it fires                      | Toast                     |
| -------------- | ---------------------------------- | ------------------------- |
| `Stop`         | A turn finished                    | "Turn complete"           |
| `Notification` | Claude needs confirmation or input | "Waiting for your input"  |

Each toast shows the project folder name and the time. Both hooks run with
`async: true`, so they never add latency to your session.

## Configuration

Set these in the `env` block of `~/.claude/settings.json`:

```json
{
  "env": {
    "CLAUDE_NOTIFY_TITLE": "Claude",
    "CLAUDE_NOTIFY_SILENT": "1"
  }
}
```

| Variable                   | Effect                                          |
| -------------------------- | ----------------------------------------------- |
| `CLAUDE_NOTIFY_DISABLED=1` | Suppress all notifications without uninstalling |
| `CLAUDE_NOTIFY_SILENT=1`   | Show toasts without a sound                     |
| `CLAUDE_NOTIFY_TITLE`      | Override the toast title (default "Claude Code")|
| `CLAUDE_NOTIFY_TEXT_DONE`  | Override the "Turn complete" line               |
| `CLAUDE_NOTIFY_TEXT_INPUT` | Override the "Waiting for your input" line      |

The text overrides exist so you can localize without editing the script — see
the encoding note below for why editing it is a trap.

## Optional: show "Claude Code" instead of "Windows PowerShell"

Out of the box the toast borrows the stock Windows PowerShell AppID, so Action
Center attributes it to PowerShell. This needs no setup, which is why it is the
default. To get a proper identity:

```powershell
& "$env:USERPROFILE\.claude\plugins\..\scripts\register-appid.ps1"
```

Or from a clone of this repo:

```powershell
.\plugins\windows-notify\scripts\register-appid.ps1
.\plugins\windows-notify\scripts\register-appid.ps1 -IconPath C:\path\to\icon.ico
```

It writes one key under `HKEY_CURRENT_USER` — no admin rights, no machine-wide
change. `notify.ps1` detects it automatically on the next notification. Undo
with `-Unregister`.

## Notes for contributors

**`notify.ps1` is ASCII-only, on purpose.** Windows PowerShell 5.1 reads `.ps1`
files using the system ANSI code page unless the file carries a UTF-8 BOM. On a
non-Western locale (GBK, Shift-JIS, ...) a non-ASCII string literal shifts the
byte stream enough to break quote pairing, and the script dies with a parser
error that points at an unrelated line. If you need different wording, use the
`CLAUDE_NOTIFY_TEXT_*` variables rather than editing the literals.

**The script always exits 0.** A missing notification platform (Server Core,
stripped images, group policy) degrades to a system sound. A notification is a
convenience and must never fail a user's turn.

**stdin is only read when redirected.** `[Console]::In.ReadToEnd()` on an
interactive console would block until EOF and hang the hook.

## License

MIT
