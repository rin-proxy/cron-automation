#!/bin/bash
# cron-helper.sh — OpenClaw cron toolkit: lint job JSON, convert timezones, validate schedules.
# Encodes the gotchas from the cron-and-automation-mastery Tower book so they fail loudly, not silently.
set -uo pipefail
cmd="${1:-}"

case "$cmd" in
  --lint)
    # Lint OpenClaw cron job JSON. Accepts one job, an array, or a {jobs:[…]} / {jobs:{…}}
    # store (the real jobs.json) — lints EACH job. Handles the migrated scheduleIdentity form.
    src="${2:-/dev/stdin}"
    /usr/bin/node -e '
      const fs=require("fs");
      let d; try { d=JSON.parse(fs.readFileSync(process.argv[1],"utf8")); }
      catch(e){ console.log("  ❌ invalid JSON: "+e.message); process.exit(1); }
      let jobs = Array.isArray(d) ? d : (d && d.jobs ? d.jobs : [d]);
      if (jobs && !Array.isArray(jobs) && typeof jobs==="object") jobs = Object.values(jobs);
      const lintOne = (j) => {
        const issues=[];
        let sc=j.schedule||{};
        if(!sc.kind && j.scheduleIdentity){ try{ sc=(JSON.parse(j.scheduleIdentity).schedule)||{}; }catch(e){} }
        const st=j.sessionTarget, pk=j.payload&&j.payload.kind;
        if(!st) issues.push("missing sessionTarget");
        if(!pk) issues.push("missing payload.kind");
        if(st==="main" && pk && pk!=="systemEvent") issues.push(`main session needs payload.kind=systemEvent (got ${pk})`);
        if((st==="isolated"||st==="current") && pk && pk!=="agentTurn") issues.push(`${st} session needs payload.kind=agentTurn (got ${pk})`);
        if(sc.kind==="cron" && !sc.tz) issues.push("schedule.tz missing — set UTC or e.g. Asia/Jakarta");
        if(sc.kind==="cron" && sc.expr && sc.expr.trim().split(/\s+/).length!==5) issues.push(`schedule.expr is not 5 fields: "${sc.expr}"`);
        const m=j.model||(j.payload&&j.payload.model);
        if(m && /^modelstudio\//.test(m)) issues.push(`model "${m}" likely REJECTED by allowlist — use provider/model (e.g. qwen/qwen3.5-plus)`);
        if(j.enabled===undefined) issues.push("enabled not set (defaults may surprise you)");
        return issues;
      };
      let bad=0, skipped=0;
      jobs.forEach(j=>{
        const name=j.name||j.id||"(unnamed)";
        // A state-only record (jobs-state file) has no definition to lint — say so, don`t false-alarm.
        if(!j.name && !j.payload && !j.sessionTarget && (j.state||j.scheduleIdentity)){ skipped++; console.log(`  ⏭️  ${name}: state record — lint the definitions file (jobs.json) instead`); return; }
        const issues=lintOne(j);
        if(issues.length){ bad++; console.log(`  ⚠️  ${name}: ${issues.length} issue(s)`); issues.forEach(i=>console.log("     - "+i)); }
        else console.log(`  ✅ ${name}: passes — session↔payload OK, tz set, model OK, 5-field expr.`);
      });
      console.log(`  ── ${jobs.length} job(s): ${jobs.length-bad-skipped} ok, ${bad} with issues${skipped?`, ${skipped} skipped`:""}.`);
      process.exit(bad?2:0);
    ' "$src"
    ;;
  --audit)
    # Audit crons for RUNTIME failures (consecutiveErrors / lastStatus=error) — the
    # silent breakage a lint (which only reads the definition) can never catch.
    # Source, in order: an explicit file arg → the LIVE gateway (openclaw cron list
    # --json) → an on-disk jobs store. Names for keyed state stores come from the defs file.
    src="${2:-}"; live=""; tmp=""
    if [[ -z "$src" ]]; then
      if command -v openclaw >/dev/null 2>&1; then
        tmp="$(mktemp)"
        if openclaw cron list --json >"$tmp" 2>/dev/null && [[ -s "$tmp" ]]; then src="$tmp"; live=1; fi
      fi
      if [[ -z "$src" ]]; then
        for cand in ~/.openclaw/cron/jobs-state*.migrated ~/.openclaw/cron/jobs-state*.json ~/.openclaw/cron/jobs.json ~/.openclaw/cron/jobs.json.migrated; do
          [[ -f "$cand" ]] && { src="$cand"; break; }
        done
      fi
    fi
    [[ -n "$src" && -f "$src" ]] || { echo "  ❌ no cron source found (gateway CLI or jobs store) — pass a file: --audit <jobs.json>"; [[ -n "$tmp" ]] && rm -f "$tmp"; exit 1; }
    defs=""; for cand in ~/.openclaw/cron/jobs.json ~/.openclaw/cron/jobs.json.migrated; do [[ -f "$cand" ]] && { defs="$cand"; break; }; done
    if [[ -n "$live" ]]; then echo "  🔎 cron audit — live (openclaw cron list --json)"; else echo "  🔎 cron audit — $src"; fi
    /usr/bin/node -e '
      const fs=require("fs");
      const load=p=>{ try{ return JSON.parse(fs.readFileSync(p,"utf8")); }catch(e){ return null; } };
      const d=load(process.argv[1]); if(!d){ console.log("  ❌ invalid/unreadable JSON"); process.exit(1); }
      const defs=process.argv[2]?load(process.argv[2]):null;
      const nameById={};
      if(defs){ let dl=Array.isArray(defs)?defs:(defs.jobs?(Array.isArray(defs.jobs)?defs.jobs:Object.values(defs.jobs)):[]); dl.forEach(j=>{ if(j&&j.id) nameById[j.id]=j.name; }); }
      let jobs=d.jobs!==undefined?d.jobs:d;
      let entries = Array.isArray(jobs) ? jobs.map(j=>[j&&j.id,j]) : (jobs&&typeof jobs==="object" ? Object.entries(jobs) : []);
      const label=(id,o)=>{ if(o&&o.name) return o.name; if(nameById[id]) return nameById[id];
        if(o&&o.scheduleIdentity){ try{ const s=JSON.parse(o.scheduleIdentity).schedule||{}; return "cron "+(s.expr||"?")+" ("+String(id||"").slice(0,8)+")"; }catch(e){} }
        return id||"(unnamed)"; };
      let bad=0;
      entries.forEach(function(pair){ const id=pair[0], o=pair[1]; const st=(o&&o.state)||{};
        const ce=st.consecutiveErrors||0; const ls=st.lastStatus||st.lastRunStatus||(o&&o.status)||"?";
        if(ce>0 || ls==="error"){ bad++;
          const ld=st.lastDiagnostics||{}; const ds=(ld&&ld.summary)||st.lastDiagnosticSummary||(o&&o.lastRunError)||"";
          const diag=ds?(" — "+String(ds).slice(0,100)):"";
          console.log("  ⚠️  "+label(id,o)+": "+ce+" consecutive error(s), lastStatus="+ls+diag);
        }
      });
      if(!bad) console.log("  ✅ "+entries.length+" job(s), none failing.");
      else console.log("  ── "+bad+" of "+entries.length+" job(s) FAILING — check model/allowlist/subscription/timeout.");
      process.exit(bad?2:0);
    ' "$src" "$defs"
    rc=$?
    [[ -n "$tmp" ]] && rm -f "$tmp"
    exit $rc
    ;;
  --tz)
    # WIB↔UTC. Usage: --tz HH:MM [wib|utc]   (default: input is WIB → UTC)
    t="${2:-}"; from="${3:-wib}"
    [[ "$t" == *:* ]] || { echo "  usage: --tz HH:MM [wib|utc]"; exit 1; }
    h=$((10#${t%%:*})); m=$((10#${t#*:}))
    if [[ "$from" == "wib" ]]; then off=-7; label="WIB→UTC"; else off=7; label="UTC→WIB"; fi
    nh=$(( (h + off + 24) % 24 ))
    printf "  %s : %02d:%02d → %02d:%02d   (UTC cron field for a daily job: \"%d %d * * *\")\n" "$label" "$h" "$m" "$nh" "$m" "$m" "$([[ $from == wib ]] && echo $nh || echo $h)"
    [[ "$from" == "wib" ]] && printf "  → store \"%d %d * * *\" tz UTC; comment the intent: %02d:%02d WIB.\n" "$m" "$nh" "$h" "$m"
    ;;
  --validate)
    expr="${2:-}"
    n=$(echo "$expr" | awk '{print NF}')
    if [[ "${n:-0}" -ne 5 ]]; then echo "  ❌ not a 5-field cron expr (got ${n:-0} fields): $expr"; exit 1; fi
    echo "  ✅ 5-field cron: $expr"
    echo "  ⏰ server runs UTC — convert local time (WIB = UTC+7) with --tz, and document the intent in a comment."
    ;;
  --list)
    echo "  Host crontab (annotated):"
    crontab -l 2>/dev/null | grep -vE "^\s*$" | sed "s/^/    /" || echo "    (none)"
    echo "  Note: OpenClaw *agent* crons are managed via the gateway, not the host crontab — lint their JSON with --lint."
    ;;
  *)
    echo "cron-helper.sh — OpenClaw cron toolkit"
    echo "  --lint <file.json|->    lint job(s) — one, an array, or a {jobs:[…]} store (session↔payload · tz · model · 5-field · enabled)"
    echo "  --audit [jobs.json]     report jobs FAILING at runtime (consecutiveErrors / lastStatus=error); auto-finds the store"
    echo "  --tz HH:MM [wib|utc]    convert WIB↔UTC + emit the UTC cron field"
    echo "  --validate \"<expr>\"     check a 5-field cron expression"
    echo "  --list                  show host crontab, annotated"
    ;;
esac
