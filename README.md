# claude-code-plugins

A small Claude Code plugin marketplace.

## Use it

```
claude plugin marketplace add https://github.com/a136-byte/claude-code-plugins.git
```

Use the full HTTPS URL rather than the `owner/repo` shorthand. The shorthand
clones over SSH, which requires a key registered with GitHub; the HTTPS form
needs no credentials at all for a public repository, so it works on a machine
you have not set up yet.

Then install what you want:

```
claude plugin install windows-notify@a136-byte-plugins
```

Restart Claude Code, or run `/reload-plugins`.

## Plugins

| Plugin                                        | Platform | What it does                                                             |
| --------------------------------------------- | -------- | ------------------------------------------------------------------------ |
| [windows-notify](plugins/windows-notify/)     | Windows  | Native toast when a turn completes or Claude is waiting on you           |

## License

MIT
