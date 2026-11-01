---
name: report
description: Write or refresh a scraper progress report (live hub numbers + repo state) in the family repo, in the team's report format. Use only when the user invokes /report.
disable-model-invocation: true
argument-hint: "[report ID → report-<ID>.md | family | project] [extra notes]"
---

# /report: scraper progress report

Arguments (may be empty): $ARGUMENTS

Goal: one Markdown report that anyone can open cold and, within a minute, know **where the work stands, what is wrong, what is
interesting, and exactly what to do next**. Numbers come from live queries, never from memory or an older report.

## 1. Work out the scope

- Family = `family` in `./scrape.json` of the current repo, unless the arguments name a family, a project (`budget-pfms`), a project
  prefix, or a report ID.
- **A report ID as the first argument** (letters + digits, e.g. `G04`, `T01`, `F01`; match it case-insensitively, write it upper-case):
  the output file is **always `report-<ID>.md`** in the repo root, e.g. `/report G04` → `report-G04.md`. Don't ask about naming.
  - If a report for that ID already exists under any name (`report-G04.md`, `reportG04.md`, `REPORTG04.md`, …), it is the previous
    report: take its scope (projects) from it and fill "Changes since last report". Write the new version to `report-<ID>.md`; an old
    file under a different name is left as is, and the final reply mentions it (the user can delete it).
  - If no report has that ID, it is a new report: the scope is the rest of the arguments, or the whole family when there are none.
- Without an ID: if an existing report in the repo root (`report*.md`, `REPORT*.md`, any case) covers the same scope, refresh that
  one, writing it to `report-<its ID>.md`. Otherwise write a new one, `report-<next ID>.md`, continuing the repo's series (mca uses `F`,
  budget uses `G`). If the repo has no series yet, ask the user once which letter to use (suggest the next unused letter).
- Anything else in the arguments is extra context or emphasis from the user: work it in.

## 2. Gather facts (run independent steps in parallel)

1. **Hub, live:** `~/.claude/skills/report/hub_snapshot.sh <family or project>` (read-only, a few seconds). Gives projects + pool
   settings, queue by status, pace (done in 1 h / 24 h / 7 d), stored record counts, runs, item errors, dashboard failures,
   metrics (24 h and all time), health checks, sample records. Follow up with your own `psql -d scrape_hub` queries for anything
   that stands out (e.g. group failures by key pattern, counts per year/state inside `public.records` filtered by `project`).
   Never query `public.records` without a `project =` filter.
2. **Repo:** `git status --short`, `git log --oneline -8`, `git rev-parse --short HEAD`, whether `main` is pushed
   (`git status -sb`); `scrape.json`, `family.py` (projects, queue seeding, `geo`/`proxy`), the task scripts' headers, `CLAUDE.md`,
   `README.md`, and notes such as `FINDINGS.md`.
3. **Tests:** `python -m pytest tests -q` (use `.venv/bin/python` if it exists, else `python3`). Offline only. Don't run
   `scrape-check` against live sites unless the user asks; read the last result in `.scrape-check/` if present and say how old it is.
4. **CI:** `gh run list --limit 6` (and `gh run view <id> --log-failed | tail -30` for a failed `check` or `setup`).
5. **Previous report(s):** for the "Changes since" table and to carry over open decisions, risks and next steps that are still true.
   Re-check every carried-over claim; drop or mark what is no longer true.
6. Only when the scope stores data outside the hub (Postgres `ws_ronik`, local dumps, the bucket): the sizes and row counts there.

## 3. Work out what it means

- **Progress:** done / total items and %, records stored. `queue.fetched` counts re-sends; `record_counts.n` is distinct ids. Report
  the stored count, and mention the gap when it is large (it means overlap or re-sent records).
- **Pace and ETA:** from items done in the last 24 h (or 7 d if quiet), divided over remaining items. State the assumption
  ("at 2 workers, if the pool keeps scheduling it"). No ETA when nothing is running: say why instead.
- **State word** for each project, and overall:
  🔍 EXPLORING · 🛠 BUILDING · ⏳ RUNNING · ⚠️ STALLED (pending items, nothing done in the last few hours) ·
  ⛔ BLOCKED (cannot proceed without a decision or access) · ✅ COMPLETE · 💤 PARKED (deliberately not running).
- **Failures:** cluster them by error text and key pattern. For each cluster: how many, cause (known / guessed / unknown, say which),
  whether retrying can help (a `LayoutChanged` won't, a `ReadTimeout` may), and the fix.
- **What stands out:** anomalies, surprises, things that cost time, and interesting facts in the data itself, with real names and
  values from the records (e.g. "Bihar ₹448 vs Kerala ₹1,346.8 per head", "approved 2010, a second entry pending since 2013").
  Aim for 3–8 items worth someone's attention. Ordinary facts don't belong here.
- **Hand-off:** what would someone need in order to continue tomorrow: the first command, the file to open, the decision they're waiting on.

## 4. Write it: template

Use this order. Every section is numbered and listed in Contents. Leave out a section only when it cannot apply (e.g. no site map
for a pure re-processing job); **never drop sections 1, 2, 3, 9, 11**: if there's nothing to put there, say "None found" and how you checked.

```markdown
# <ID>: <What is being scraped> (<site or source>)

**Status:** <emoji> <STATE WORD>. <One sentence: how far, and the main thing holding it back or next.>
**Updated:** <1 Nov 2026 19:05 CET> · **Family:** `<family>` · **Code:** `s1d-labs/<family>@<short hash>` (<pushed / N commits not pushed / M uncommitted files>)
**Projects:** `<p1>` (task `<t>`, target `<host>`, <geo/proxy>), … 
**Data:** `select … from public.records where project = '<p>'` · Metabase "Team data (scrape_hub)" · bucket `<project>/<path>/`
**Previous report:** <date, file> (or "first report")

---

## Contents
1. [TL;DR](#1-tldr) … (numbered links to every section and subsection)

---

## 1. TL;DR
3–6 bullets: where it stands (with the key number), the biggest problem, the most interesting finding, the next action and who owns it.

## 2. Where things stand
| Project | State | Items done / total | Failed · pending · running | Records stored | Pace (24 h) | ETA |
- Bullets under the table: totals, spread (e.g. by year or state), the hub's view (paused? throttled? health check up?).

### 2.1 Changes since last report      (omit in the first report)
| | <previous date> | Now | Change |

## 3. Pick up here
- **Repo:** `~/…` (branch, clean or not) · **Run tests:** `<command>` · **Try one item:** `<command>`
- **Next action:** <the one thing to do first, with the exact command or file:line>
- **Waiting on:** <decisions or access, and whose call it is>, or "nothing"

## 4. What stands out
Numbered. Each: **bold one-line finding.** Evidence (numbers, keys, real values). *Fix:* or *So what:* line when there is one.

## 5. The source
- Publisher / site, access (keys, login, captcha), network (answers from where: box, GitHub runners, India), robots/rate limits seen.
### 5.1 Site map
| What | URL / form | Notes |   (URL patterns, forms and filters, what is public and what isn't)

## 6. How it is collected
- **Code:** each file and what it does. **Queue:** what one item is, how keys are built, how many and why.
- **Pace & behaviour:** requests, delays, workers, session drops, retries, blocks (from metrics). 
- Decisions taken, marked **Decision (<who>, <date>):** …

## 7. The data
- Where it is (tables, bucket paths, files with size), record id format, one example record.
### 7.1 Fields
| Field | Source | Notes |   (derived fields marked "(derived)"; bold each field's gotcha inline)
### 7.2 What is in it
Breakdown tables (by status, year, state, type…) and top-10 lists from live queries. Right-align numbers.
### 7.3 How to query it
A short SQL block with 3–5 working queries.

## 8. Verification
- Tests: N passed / failed (command). CI: last `check` / `setup` result with date. scrape-check: last result and its date.
- Cross-checks done (our totals vs the site's own totals, record ids stable on rerun) and **what has not been checked**.

## 9. Known gaps and quality issues
| # | Issue | Size | Impact / what to do |   Worst first, issue in bold when serious. Separate "missing at the source" from "missed by us".

## 10. Risks and open decisions
- **Risks:** what could go wrong if someone runs/changes things now (e.g. "don't run setup yet: …").
- **To decide (<owner>):** numbered options, with a recommendation.

## 11. Next steps
Numbered across groups, each item specific enough to start without asking (command, file, or query):
**To do now** · **To decide** · **Later** · **Housekeeping** (uncommitted code, secrets shared in chat to rotate, servers/files to clean up, CI)
```

## 5. Rules

**Honest**
- Every number comes from a query or command run now. When a number comes from somewhere else (an older report, the site), say so.
- Say "not checked" when it wasn't. Mark guesses as guesses ("probably a site bug, not confirmed").
- Report failures, stalls, red CI and your own past mistakes plainly, with counts. Never round them away or bury them below good news.
- A project with pending items and no recent progress is ⚠️ STALLED, not ⏳ RUNNING.

**Easy to read**
- Status and TL;DR fit on the first screen. Tables over prose. Short sentences. Bold only the fact that matters in a line.
- Absolute dates: `1 Nov 2026`, times with timezone (`19:05 CET`, `16:42 IST`). Numbers with thousands separators; % to one decimal.
- `code` for every path, project, key, column, value, command and resource id.
- Link sections to each other (`[9](#9-known-gaps-and-quality-issues)`) and to sibling reports (`report-G02.md#…`).
- Aim for under ~300 lines; push long lists (every table, every key) into a linked file or a query, not the report.

**Safe**
- Never write a secret (API key, password, token), only where it lives (`~/.config/s1d/ogd.env`). If one was shared in chat, list
  "rotate it" under Housekeeping.
- No personal data in examples: no individuals' names, phones, e-mails, account numbers. Organisations are fine.
- Read-only: the report is the only file you write. Don't commit, push, run setup, seed queues or change hub settings; put those in Next steps.

## 6. Finish

Write the file, then reply in a few lines: the file path as a link, the status line, the 2–3 most important points
(including anything that needs a decision), and anything you couldn't check. Don't paste the report into the chat.
