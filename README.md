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

Symlinks:
- `spent` → `~/.local/bin/spent`
- `man/spent.1` → `~/.local/share/man/man1/spent.1`

If those directories are not on your `PATH` / `MANPATH`, the script prints the line to add to `~/.zshrc`. After install, `man spent` opens the manual.

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

## Publishing reports

`spent` can publish a per-customer web page that reads the same `.spent-MM-YYYY.log`
files this folder already produces. The page is served from a Cloudflare Pages
project (set up once) and is updated by uploading JSON files via `wrangler` —
no git repo is involved.

Prerequisites:

- `wrangler` (`npm install -g wrangler`) and a `wrangler login` session.
- A Cloudflare Pages project (e.g. `spent-reports`) with a custom domain bound
  (e.g. `reports.marcosantana.dev`). Create this in the Cloudflare dashboard
  or with `wrangler pages project create`.

One-time per folder:

```sh
spent config
```

This prompts for:

- **Cloudflare Pages project name** — global, asked once
- **Public URL base** — e.g. `https://reports.marcosantana.dev`
- **Cache directory** — defaults to `~/.local/share/spent/site/`
- **Client display name** — used as the page title (per-folder)
- **URL slug** — the path under the domain (per-folder)

`spent config` writes `~/.config/spent/site.conf` (global) and `./.spent-config`
(per-folder), both with mode 0600. It then copies the bundled HTML template
into `<cache>/<slug>/`, writes an empty `months.json`, and runs
`wrangler pages deploy` so the page is live immediately.

Inspect the current config:

```sh
spent config show
```

Re-prompt the global fields:

```sh
spent config --reset-site
```

Each subsequent push:

```sh
spent push
```

`spent push` reads every `.spent-*.log` in the current folder, converts each
to a `<YYYY-MM>.json` under the slug's cache dir, refreshes `months.json`,
and re-runs `wrangler pages deploy`. Wrangler diffs internally so unchanged
files don't cross the wire.

The page fetches `months.json` on load and a per-month `<YYYY-MM>.json` when
the visitor picks a tab. The static template stays in place — only the JSON
files change between pushes.

## Roadmap

- v1   (shipped): append-only logger
- v1.1 (shipped): `spent config` — per-folder publishing setup
- v1.2 (shipped): `spent push` — publish/refresh hours JSONs to Cloudflare Pages
- v1.3 (next):    polished customer-facing report page
