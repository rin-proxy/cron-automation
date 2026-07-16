# cron-automation

Reliable scheduled tasks for an OpenClaw agent — JSON cron jobs done right. Derived from the `cron-and-automation-mastery` Tower book; fills a gap that generic Claude-skill catalogs don't cover (OS/agent-level scheduling + OpenClaw's cron format).

## What you get
- **`scripts/cron-helper.sh`** — lints a cron job JSON for the 5 classic mistakes (session↔payload mismatch, missing tz, bad model id, non-5-field expr, unset `enabled`), converts WIB↔UTC, validates schedules, and **audits a live jobs store for crons failing at runtime** (`--audit`). `--lint` takes one job, an array, or a whole `{jobs:[…]}` store.
- **`SKILL.md`** — the OpenClaw cron format + the rules that silently break crons.
- **`references/cron-reference.md`** — example library, model/cost & timeout tables, delivery, monitoring, timezone.

## Install
```bash
openclaw skills install git:rin-proxy/cron-automation
```
Or copy the folder into `workspace/skills/`.

## Usage
```bash
./scripts/cron-helper.sh --lint job.json         # before you deploy a cron job (one job, an array, or a {jobs:[…]} store)
./scripts/cron-helper.sh --audit                 # report crons FAILING at runtime (live via gateway)
./scripts/cron-helper.sh --tz 09:00 wib          # 09:00 WIB → the UTC cron field
./scripts/cron-helper.sh --validate "0 2 * * *"  # check a 5-field expression
./scripts/cron-helper.sh --list                  # annotated host crontab
```

## Requires
`node`, `bash`, `crontab`. Runs fully local — no cloud calls.
