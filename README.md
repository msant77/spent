# spent

Tiny CLI to log time per folder. Each invocation appends one row to a CSV log file (`.spent-MM-YYYY.log`) in the current directory, partitioned by the entry's start month.

## Usage

```
spent <duration> [-t TYPE] [#REF|!REF] [-m MESSAGE] [-st "DD-MM-YY HH:MM"] [-et "DD-MM-YY HH:MM"]
```

| Argument | Required | Notes |
|----------|----------|-------|
| `<duration>` | yes | `2h`, `30m`, `4h30m`, `90m` |
| `-t TYPE` | no | `dev`, `test`, `plan`, `call`, `prompt`, `message`, `other` |
| `#N` / `!N` | no | Issue (`#`) or merge-request (`!`) reference |
| `-m MESSAGE` | no | Free-text note |
| `-st` | no | Start time, format `DD-MM-YY HH:MM` |
| `-et` | no | End time, same format |

When `-st`/`-et` are omitted:

| `-st` | `-et` | Result |
|-------|-------|--------|
| —     | —     | `et = now`, `st = now - duration` |
| set   | —     | `et = st + duration` |
| —     | set   | `st = et - duration` |
| set   | set   | used as-is |

## Examples

```sh
spent 2h -t dev "#42" -m "fix CSV escaping"
spent 30m -t plan -m "scope review"
spent 1h -st "29-04-26 09:00" -et "29-04-26 10:00" -t call -m "kickoff"
spent 5m -m 'note with "quotes" and, commas'
```

## Install

```sh
./install.sh
```

Symlinks `spent` to `~/.local/bin/spent`. If that's not on your `PATH`, the script tells you the line to add to `~/.zshrc`.

## Output format

CSV (RFC 4180), all fields always quoted. Header is written once when a file is first created.

```csv
duration,type,ref,message,start,end
"2h","dev","#42","fix CSV escaping","29-04-26 14:00","29-04-26 16:00"
"30m","plan","","scope review","29-04-26 16:30","29-04-26 17:00"
```

## Develop

```sh
brew install bats-core shellcheck
shellcheck spent install.sh
bats tests/
```

Bash 3.2 compatible. macOS-only (uses BSD `date -j`).

## Roadmap

- v1 (this release): append-only
- v2: `spent report` — sum hours by type/issue for the current folder + month
