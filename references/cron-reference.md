# Cron Reference

Example library, model/cost/timeout tables, delivery & monitoring for the `cron-automation` skill — loaded on demand. Full theory: `tower/cron-and-automation-mastery.md`.

## Example library (copy, adjust tz + model, deploy)

> These show the **stored** JSON form (what `--lint` validates). On modern OpenClaw you can also
> create the same jobs with `openclaw cron add --agent <id> --message "…" --model provider/model`
> plus schedule flags, and read them back with `openclaw cron list --json`.

**Morning briefing** — `0 2 * * *` UTC (= 09:00 WIB) · isolated · timeout 600s · model `kimi/kimi-for-coding`
```json
{ "name": "morning-briefing",
  "schedule": {"kind":"cron","expr":"0 2 * * *","tz":"UTC"},
  "payload":  {"kind":"agentTurn","message":"Generate morning briefing with tasks, calendar, and priorities"},
  "sessionTarget": "isolated", "enabled": true }
```
**Security audit (every 3 days)** — isolated · use `last -n 5` (NO elevated)
```json
{ "name":"security-audit-3day",
  "schedule":{"kind":"cron","expr":"0 10 */3 * *","tz":"UTC"},
  "payload":{"kind":"agentTurn","message":"Run security audit: SSH, firewall, fail2ban, disk, logs"},
  "sessionTarget":"isolated","enabled":true }
```
**Daily memory summary** — `0 23 * * *` · **Project progress** — `0 */6 * * *` (nag if stalled >3 days). Same shape.

## Schedule types
| Type | Format | Example |
|---|---|---|
| cron | `expr` + `tz` | `"0 9 * * *"` daily 09:00 in `tz` |
| every | `everyMs` | `"everyMs": 3600000` hourly |
| at | ISO | `"at": "2026-05-20T02:00:00Z"` one-shot |

## Model allowlist & cost
Model ids are **`provider/model`** (or a configured alias); an id outside the allowlist fails
instantly. **`openclaw models`** prints the exact ids + aliases configured on your box — that's the
source of truth (model names age fast, so check it rather than trusting a static list). Pin a job's
model with `--model provider/model` (`openclaw cron add/edit`) or `payload.model` in the JSON; an
unset model uses the account default. Current-era examples: `anthropic/claude-opus-4-8`,
`anthropic/claude-sonnet-5`, `anthropic/claude-haiku-4-5`, `kimi/kimi-for-coding`.

| Task | Pick | Why |
|---|---|---|
| Simple reporting | a fast/cheap model (Haiku-class) | just reads files |
| Memory review | a light model | light analysis |
| Deep reflection / briefing | a mid model (Sonnet-class) | pattern recognition |
| Complex analysis | a top model (Opus-class) | deep reasoning |

Use the cheapest capable model for routine work; reserve premium for hard reasoning. **A job pinned
to a model that later leaves your allowlist (e.g. a lapsed subscription) fails silently — catch it
with `cron-helper.sh --audit`.**

## Elevated-command restriction (isolated sessions)
Isolated cron sessions **cannot** run elevated commands.
| Need | ❌ Elevated | ✅ Alternative |
|---|---|---|
| Auth logs | `grep /var/log/auth.log` | `last -n 5` |
| Disk | `du -sh /var` | `df -h` |
| Memory | `cat /proc/meminfo` | `free -m` |
| Restart service | `systemctl restart` | host cron + script |

## Timeout
Set timeout ≈ **2× expected duration**. Simple check 60s · memory review 300s · deep reflection / briefing **600s** · security audit 120s.

## Delivery
**Announce** (output → chat; briefings/alerts) · **Silent** (no delivery; maintenance/file updates) · **Webhook** (→ external URL; integrations).

## Monitoring
Healthy = success >95%, 0 consecutive errors, duration within timeout. **When a cron fails:** read the error → verify model allowlist → check elevated perms (isolated = no sudo) → check timeout → test manually.

## Timezone
Server runs UTC. **WIB = UTC+7.** Store schedules in UTC (avoids DST drift), document local intent in a comment.
| Zone | Offset | | Zone | Offset |
|---|---|---|---|---|
| UTC | +0 | | WIB/ICT | +7 |
| CET | +1 | | CST (China)/SGT | +8 |
| IST | +5:30 | | JST/KST | +9 |
| EST | −5 | | PST | −8 |

09:00 WIB → `0 2 * * *` UTC. Pitfalls: don't double-convert; use 24h format; mind DST for US/EU/AU zones.
