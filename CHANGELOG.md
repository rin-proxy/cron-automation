# Changelog — cron-automation

## 1.2.0 (2026-07-16)
- Verified against **OpenClaw 2026.7.1**. Refreshed the model guidance: model ids age fast, so the
  docs now point to **`openclaw models`** as the source of truth instead of hard-coded examples, and
  note the modern `openclaw cron add --model provider/model` / `cron list --json` surface.
- `--lint` model check is now **version-proof**: flags a model that is neither a `provider/model` id
  nor a bare alias (dropped the dated `modelstudio/` special case), and points to `openclaw models`.
- Docs cross-reference `--audit` for the silent-failure case (a job pinned to a model that left the
  allowlist, e.g. a lapsed subscription).
- **Portability fixes:** call `node` from `PATH` instead of a hard-coded `/usr/bin/node` (broke on
  macOS / non-standard installs); `--lint -` now actually reads stdin (the documented `-` was being
  opened as a file named `-`).

## 1.1.0 (2026-07-16)
- `--lint` accepts a whole store — one job, an array, or `{jobs:[…]}`/`{jobs:{…}}` — and lints each; understands the migrated `scheduleIdentity` form and skips state-only records instead of false-alarming.
- New `--audit`: reports crons FAILING at runtime (consecutiveErrors / lastStatus=error) from the LIVE gateway (`openclaw cron list --json`), falling back to the on-disk jobs store with id→name join. Catches the silent breakage a definition-only lint never can.

## 1.0.0 (2026-06-15)
- Initial release. Converted from the `cron-and-automation-mastery` Tower book.
- `cron-helper.sh`: `--lint` (5-pitfall check on cron JSON), `--tz` (WIB↔UTC), `--validate` (5-field expr), `--list`.
- PDA-structured: lean SKILL.md + `references/cron-reference.md` (example library, model/timeout/timezone).
