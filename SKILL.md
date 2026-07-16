---
name: cron-automation
description: Schedule reliable recurring tasks for an OpenClaw agent. Ships a helper that lints cron job JSON (session-target ↔ payload, timezone, model allowlist), converts WIB↔UTC, and validates schedules — encoding the gotchas that silently break agent crons. Use when setting up, debugging, or auditing scheduled/automated agent jobs.
version: 1.1.0
metadata:
  openclaw:
    emoji: "⏰"
    requires:
      bins: ["node", "bash", "crontab"]
triggers:
  - "set up cron"
  - "schedule a task"
  - "automate this"
  - "recurring job"
  - "cron job"
  - "fix my cron"
author: Rin
license: UNLICENSED
lastUpdated: 2026-07-16
---

# Cron Automation

Reliable scheduled tasks for an OpenClaw agent — JSON cron jobs done right, with the gotchas that silently break them caught up front.

## 🚀 Quick Start

```bash
./scripts/cron-helper.sh --lint job.json         # catch the 5 classic mistakes before deploy (one job, an array, or a {jobs:[…]} store)
./scripts/cron-helper.sh --audit                 # report crons FAILING at runtime (live via gateway)
./scripts/cron-helper.sh --tz 09:00 wib          # 09:00 WIB → UTC + the cron field
./scripts/cron-helper.sh --validate "0 2 * * *"  # check a 5-field expression
./scripts/cron-helper.sh --list                  # host crontab, annotated
```

## 🧱 OpenClaw cron format (JSON, not crontab)

```json
{
  "name": "morning-briefing",
  "schedule": { "kind": "cron", "expr": "0 2 * * *", "tz": "UTC" },
  "payload":  { "kind": "agentTurn", "message": "Generate morning briefing..." },
  "sessionTarget": "isolated",
  "enabled": true
}
```
Schedule kinds: `cron` (`expr` + `tz`) · `every` (`everyMs`) · `at` (ISO one-shot).

## ⚠️ The rules that silently break crons

**Session ↔ payload (must match):** `main` → `systemEvent` only (urgent alerts) · `isolated` / `current` → `agentTurn` only (background work). Mismatch = error.

**The 5 classic pitfalls** — `--lint` checks these automatically:
1. **Wrong model id** — `modelstudio/qwen3.5-plus` ❌ → `qwen/qwen3.5-plus` ✅ (allowlist enforced).
2. **Elevated in isolated** — no `sudo` / `systemctl` / `/var/log` in isolated sessions → use `last -n 5`, `df -h`, `free -m`, or host cron.
3. **Timeout too short** — set timeout ≈ **2× expected** (complex generation → 600s, not 300s).
4. **Wrong session type** — see the session↔payload rule above.
5. **No timezone** — always set `tz`; server runs UTC, document the local intent in a comment.

→ Full reference (example library · model/cost · timeouts · delivery · monitoring · timezone): [`references/cron-reference.md`](references/cron-reference.md) · deep theory: `tower/cron-and-automation-mastery.md`.

## 🕐 Timezone

Store schedules in **UTC** (avoids DST drift); document the human local time in a comment. WIB = UTC+7 → 09:00 WIB = `0 2 * * *` UTC. Use `--tz` to convert.

---
*Derived from the `cron-and-automation-mastery` Tower book. By Rin ⏰*
