# Fitness log app — product + technical spec (working title "Rep")

Personal, phone-only training log you talk to. Built the Shelf way: Flutter (3.47) for iOS + Android, local SQLite (`sqflite`), on-device speech, no accounts, no cloud, sideload APK / Xcode install. No in-app AI. Deeper questions go to Grok via the share sheet, same as Shelf's Export / Share.

## Goals / non-goals
**Goals:** log sets by voice with no typing; plan the week and see strain warnings; 30-second daily check-in; warnings that learn from Lewis's own history and say why; week/month export for Grok.
**Non-goals:** no LLM/API calls or keys, no wearables/HealthKit in MVP, no social, no coaching programmes, no calorie tracking, no commercial polish or store listing.

## UI rules (apply everywhere)
No explanatory/help text on screens. Icon-only controls, labels on long-press (tooltip on hover). Choices open as pop-ups/pop-outs, never rows of pills. White canvas, one accent colour, British English.

## User flows
1. **Log after sets:** tap and hold the mic (home or lock-screen widget later). Say "bench press, 4 sets of 8 at 70 kilos". A confirm card pops up (exercise · 4×8 · 70 kg). It auto-saves after 3 s, or tap any field to fix it (pop-out picker). The same flow works for "Muay Thai, 90 minutes, hard" and "ran 5k in 28 minutes, RPE 6".
2. **Plan the week:** Plan tab, 7 day columns. Tap a day → pop-up: session type (+ optional muscle groups/intensity), or say it ("Tuesday Thai hard, Wednesday legs heavy"). Strain icons appear on flagged days; tap one for the evidence pop-out.
3. **Daily check-in:** a notification at a set time (default 8am). One screen, six sliders 1–10, or answer by voice in one sentence ("sore 6, energy 4, slept 7 hours…"). Done in about 30 s.
4. **Export:** ⋮ → Week / Month → JSON + readable `.md` via share sheet → Grok.

## Screens
Today (mic, today's plan, logged sessions, check-in status) · Plan (week grid + warnings) · History (calendar, tap day → sessions + check-in) · Insights (learned patterns table, each with N and effect) · Settings (exercise dictionary/aliases, check-in time, units, export).

## Data model (SQLite)
- `exercises` — id, name, category (strength/cardio/combat/mobility), muscle_groups (list), aliases (list), default_load_factor
- `sessions` — id, date, start_time, type (gym/muay_thai/run/hike/yoga/other), duration_min, rpe (1–10, nullable), notes, raw_transcript
- `sets` — id, session_id, exercise_id, set_count, reps, weight_kg, distance_km, duration_s, rpe
- `plan_items` — id, date, type, muscle_groups, intensity (easy/moderate/hard), duration_min_est
- `checkins` — date, soreness, energy, sleep_quality, sleep_hours, mood, ate_well, stress (1–10), raw_transcript
- `patterns` — key (e.g. `muay_thai:hard>gym:legs_heavy`), n, mean_next_readiness, mean_next_fatigue, last_updated
- `warnings_log` — date, rule, shown, evidence_json (to check later whether warnings were right)

## Load + readiness model (plain terms, no AI)
**Session load** = duration (min) × RPE (session-RPE, the standard sports-science measure). Strength sessions with no duration: estimate 3 min per set. If RPE is missing, use a per-type default (Thai 7, heavy gym 7, run 6, hike 4, yoga 2), replaced by his own average RPE for that type once N ≥ 5.
**Muscle-group load** = sum of sets per group over the last 72 h.
**Readiness (from check-in)** = mean of energy, sleep, mood, ate_well, (11 − soreness), (11 − stress), scaled to 0–100. Fatigue = soreness and energy kept separately as well.
**Weekly load** = sum of session loads over 7 days. **Acute:chronic ratio** = this week ÷ average of the last 4 weeks.

**Rules (defaults, day 1):**
- Two hard days (RPE ≥ 7 or load above his 75th percentile) back to back.
- Same muscle group trained heavy within 48 h.
- Heavy legs then running/Thai the next day.
- Planned weekly load > 1.3 × the 4-week average (shown once ≥ 3 weeks of data).
- Today's check-in readiness < 40 with a hard session planned.

**Personal learning:** after each check-in, the previous day's pattern is recorded. That covers the session-type pair (day −2 → day −1) and the last session alone, and the pattern's next-day readiness/fatigue means are updated. Once a pattern has **N ≥ 3** samples, its mean replaces the default rule for that pattern:
- mean next-day fatigue ≥ 7 (or readiness < 45) → **warning upgraded**, even if the default rule didn't fire;
- mean next-day fatigue ≤ 4 (readiness ≥ 65) → **warning downgraded** to a muted icon;
- in between → keep the default.
Use a rolling window of the last 8 occurrences so it tracks changes in fitness. It works from day 1 on defaults and becomes personal around week 4.
**Evidence text** in the pop-out: "Last 3 times: Thai hard → legs heavy. Next-day fatigue 8, 7, 9." It shows the dates, and tapping a date opens that day.

## Voice parser (deterministic)
On-device STT: iOS `SFSpeechRecognizer` (`requiresOnDeviceRecognition`), Android `SpeechRecognizer` (offline preferred), via the `speech_to_text` plugin Shelf already uses, en-GB. Pipeline:
1. Normalise: lowercase, number words → digits ("eight" → 8, "seventy" → 70), strip filler (reuse Shelf's cleanup), and map units "kilos/kg/k" → kg, "lbs/pounds" → lb→kg, "k/km" after a run → km.
2. Split into multiple entries on "then", "and then", ";".
3. Exercise match: longest alias match in the dictionary, then fuzzy fallback (Levenshtein ≤ 2 / phonetic) for mishearings like "bench rest" → bench press. If nothing matches, the card shows "?" and the picker opens.
4. Slot regexes: `(\d+) sets? of (\d+)`, `(\d+) ?x ?(\d+)`, `at (\d+(\.\d+)?) ?(kg|lb)`, `(\d+) (minutes|mins|hours?)`, `(\d+(\.\d+)?) ?(k|km|miles)`, `rpe (\d+)` / intensity words (easy=3, moderate=5, hard=7, brutal=9).
5. Context: if no exercise is said, use the last-logged exercise ("another 2 sets of 8").

| Said | Parsed |
|---|---|
| "bench press, 4 sets of 8 at 70 kilos" | Bench press · 4×8 · 70 kg |
| "squats 5 by 5 100k" | Back squat · 5×5 · 100 kg |
| "Muay Thai, hour and a half, hard" | Muay Thai · 90 min · RPE 7 |
| "ran 5k in 28 minutes, RPE 6" | Run · 5 km · 28 min · RPE 6 |
| "yoga 30 minutes easy" | Yoga · 30 min · RPE 3 |
| "pull-ups 3 sets of 10 bodyweight then rows 3 by 12 at 50" | Two entries |

The seeded dictionary has about 80 exercises plus aliases. Each correction made on the confirm card adds an alias automatically, so the parser learns his phrasing deterministically.

## Grok hand-off
⋮ → Export week/month → share sheet: `fitness-summary-v1.json` (sessions, sets, check-ins, plan vs actual, warnings shown and next-day outcomes, learned patterns with N) + `summary.md` (readable tables + a short schema guide, like Shelf's guide). No keys, no API. An optional BYO-key "Ask AI" like Shelf's is left for later.

## Privacy
Everything is local: SQLite + app sandbox, speech on-device, no network calls in MVP, no analytics. The only export is one Lewis starts through the share sheet. Backup is a manual JSON export/import.

## MVP vs later
**MVP:** voice logging + confirm card, exercise dictionary, non-gym sessions, Today/Plan/History, check-in (sliders + voice), default rules, pattern learning with evidence, week/month export, iOS + Android sideload.
**Later:** Insights screen polish, widget/lock-screen mic, Apple Health/Health Connect (sleep, HR), Watch quick-log, progression charts / PRs, BYO-key Ask AI, warning-accuracy review ("were the warnings right?").

## Open questions
1. Name: keep "Rep" or something else?
2. Check-in time and reminder: a fixed morning notification, or open-the-app only?
3. Should Muay Thai be split into sub-types (pads/sparring/clinch/conditioning), since they load very differently?
4. Units: kg only, and km or miles for running?
5. Separate repo `LewisAGI/<name>`, public like Shelf, or private?
