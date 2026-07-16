# Changelog — cron-automation

## 1.1.0 (2026-07-16)
- `--lint` accepts a whole store — one job, an array, or `{jobs:[…]}`/`{jobs:{…}}` — and lints each; understands the migrated `scheduleIdentity` form and skips state-only records instead of false-alarming.
- New `--audit`: reports crons FAILING at runtime (consecutiveErrors / lastStatus=error) from the LIVE gateway (`openclaw cron list --json`), falling back to the on-disk jobs store with id→name join. Catches the silent breakage a definition-only lint never can.

## 1.0.0 (2026-06-15)
- Initial release. Converted from the `cron-and-automation-mastery` Tower book.
- `cron-helper.sh`: `--lint` (5-pitfall check on cron JSON), `--tz` (WIB↔UTC), `--validate` (5-field expr), `--list`.
- PDA-structured: lean SKILL.md + `references/cron-reference.md` (example library, model/timeout/timezone).
