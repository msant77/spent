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
files this folder already produces. **Each folder maps to its own Cloudflare Pages
project at its own subdomain** — `https://<slug>.<parent>/`. No git repo is involved;
JSON files are uploaded via `wrangler`.

Prerequisites:

- `wrangler` (`npm install -g wrangler`) and a `wrangler login` session.
- A parent domain on Cloudflare (e.g. `marcosantana.dev`). `spent config`
  bootstraps the Pages project for each folder by running
  `wrangler pages project create <slug> --production-branch=main`; you bind
  the `<slug>.<parent>` custom domain once in the Cloudflare dashboard.

One-time per folder:

```sh
spent config
```

This prompts for (first run only for the global pair):

- **Parent domain** — e.g. `marcosantana.dev` (global, asked once)
- **Cache directory** — defaults to `~/.local/share/spent/site/` (global)
- **Client display name** — used as the page title (per-folder)
- **Subdomain label / slug** — also doubles as the Pages project name and the
  cache subdir name. Defaults to the folder basename (slugified). Must match
  `^[a-z0-9]([a-z0-9-]*[a-z0-9])?$`.

`spent config` writes `~/.config/spent/site.conf` (global) and `./.spent-config`
(per-folder), both with mode 0600. It then copies the bundled HTML template
into `<cache>/<slug>/`, writes an empty `months.json`, and runs
`wrangler pages deploy <cache>/<slug> --project-name=<slug>` so the page is live
immediately. After the first deploy you bind `<slug>.<parent>` to the project in
the Cloudflare dashboard (Pages → `<slug>` → Custom domains).

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
to a `<YYYY-MM>.json` under `<cache>/<slug>/`, refreshes `months.json`, and
re-runs `wrangler pages deploy <cache>/<slug> --project-name=<slug>`. Only this
folder's slug subtree is deployed — sibling slugs stay untouched. Wrangler
diffs internally so unchanged files don't cross the wire.

The page fetches `months.json` on load and a per-month `<YYYY-MM>.json` when
the visitor picks a tab. The static template stays in place — only the JSON
files change between pushes.

The bundled template (`template/index.html`) is a single self-contained file:
no build step, no CDN, no framework. It renders the title `<Client> · Relatório de Horas`,
descending month tabs (`Mai 2026`, `Abr 2026`, …), a `Total no mês` line, and a
table per month with columns *Início*, *Dur.*, *Tipo*, *Ref.*, *Descrição*. The
layout is mobile-friendly and adapts to dark mode via `prefers-color-scheme`.

### Security posture

- Reports are **plain-public** — anyone with the URL sees every entry. Re-read
  message text for confidential leaks before sharing the URL.
- The slug must match `^[a-z0-9]([a-z0-9-]*[a-z0-9])?$`, validated after the
  prompt — defends against typos and path traversal.
- Config files (`~/.config/spent/site.conf`, `./.spent-config`) hold only
  routing info; **no credentials**. Wrangler manages its own session.
- Values are bash-escaped on write so awkward characters (`"`, `\`, `$`,
  backtick) round-trip cleanly through `source`.
- The customer page ships a `Content-Security-Policy` of `default-src 'self'`
  with `form-action 'none'`, `frame-ancestors 'none'`, and
  `referrer = no-referrer`.

## Roadmap

- v1   (shipped): append-only logger
- v1.1 (shipped): `spent config` — per-folder publishing setup
- v1.2 (shipped): `spent push` — publish/refresh hours JSONs to Cloudflare Pages
- v1.3 (shipped): polished customer-facing report page
