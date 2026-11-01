#!/usr/bin/env bash
# Live progress snapshot of one scrape-pool family (or one project) from the hub's database.
# Usage: hub_snapshot.sh <family | project | project-prefix>
# Read-only. Output is plain psql tables meant to be read by /report, not pasted as is.
set -euo pipefail
ARG="${1:?usage: hub_snapshot.sh <family|project|prefix>}"
Q() { psql -d scrape_hub -X -q -P pager=off -v ON_ERROR_STOP=1 -c "$1"; }
# Projects in scope: those whose pool entry names the family, or whose name equals / starts with the argument.
SCOPE="(select name from public.projects where settings->>'family' = '$ARG' or name = '$ARG' or name like '$ARG-%')"

echo "### Snapshot taken $(date '+%d %b %Y %H:%M %Z') (box clock; DB times below are shown in the box's timezone)"

echo; echo "### Projects (pool entry, expected sizes)"
Q "select name, title, expected_units exp_items, expected_records exp_records,
          settings->>'task' task, settings->>'target' target,
          nullif(concat_ws(' ', 'geo='||nullif(settings->>'geo',''), 'proxy='||nullif(settings->>'proxy','')),'') network,
          settings->>'max_workers' max_w, settings->>'probe' probe, (settings->>'pool')::bool pool, created_at::date created
   from public.projects where name in $SCOPE order by name"

echo; echo "### Queue by status (fetched = records reported by items, re-sends included)"
Q "select project, status, count(*) items, sum(fetched) fetched, max(attempts) max_attempts, max(done_at) last_done
   from public.queue where project in $SCOPE group by 1,2 order by 1,2"

echo; echo "### Pace: items done (last 1 h / 24 h / 7 d) and remaining"
Q "select project,
          count(*) filter (where done_at > now()-interval '1 hour') done_1h,
          count(*) filter (where done_at > now()-interval '24 hours') done_24h,
          count(*) filter (where done_at > now()-interval '7 days') done_7d,
          count(*) filter (where status not in ('done','parked','split')) remaining,
          min(done_at) first_done
   from public.queue where project in $SCOPE group by 1 order by 1"

echo; echo "### Records stored (distinct ids, the true count)"
Q "select project, n records, missing_docs, at counted_at from public.record_counts where project in $SCOPE order by 1"

echo; echo "### Runs by state"
Q "select project, state, count(*) runs, sum(records) records, sum(errors) errors, sum(blocked) blocked,
          min(started_at) first_start, max(last_seen) last_seen,
          round(avg(extract(epoch from (coalesce(finished_at,last_seen)-started_at))/3600)::numeric,1) avg_hours
   from public.runs where project in $SCOPE group by 1,2 order by 1,2"

echo; echo "### Last 8 runs"
Q "select project, state, started_at, coalesce(finished_at,last_seen) ended, records, errors, blocked, left(note,70) note,
          actor, egress_ip
   from public.runs where project in $SCOPE order by started_at desc limit 8"

echo; echo "### Item errors still on the queue (top 10)"
Q "select project, status, left(last_error,90) last_error, count(*) items, max(attempts) max_attempts
   from public.queue where project in $SCOPE and last_error is not null and last_error <> ''
   group by 1,2,3 order by 4 desc limit 10"

echo; echo "### Failures list on the dashboard (hub.failure), top 10 reasons"
Q "select project, kind, left(reason,80) reason, count(*) n, max(last_seen) last_seen
   from public.failures where project in $SCOPE group by 1,2,3 order by 4 desc limit 10"

echo; echo "### Metrics, last 24 h and all time"
Q "select project, name,
          round(sum(value) filter (where at > now()-interval '24 hours')::numeric,1) last_24h,
          round(sum(value)::numeric,1) all_time
   from public.metrics where project in $SCOPE group by 1,2 order by 1,4 desc"

echo; echo "### Health checks (latest result per probe of the family)"
Q "select t.name, t.url, p.ok, p.ms, p.at, left(p.detail,60) detail
   from public.probe_targets t
   left join lateral (select * from public.probes where target = t.name order by at desc limit 1) p on true
   where t.family = '$ARG' or t.name like '$ARG:%' order by 1"

echo; echo "### A few sample records per project (newest), to quote real values"
# Lateral lookup on the (project, record_id) primary key: a window over all records takes minutes on big projects.
Q "select p.name project, r.record_id, left(r.data::text, 220) data
   from public.projects p
   cross join lateral (select record_id, data from public.records where project = p.name
                       order by record_id desc limit 2) r
   where p.name in $SCOPE order by 1"
