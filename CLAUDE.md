# The Final Stretch Project — Context Handoff

*Paste this into a Claude Code session (or save as `CLAUDE.md` at the repo root) to bring it up to speed.*

---

## What this project is

**The Final Stretch Project** builds free, open-source iOS apps that carry public data the rest of the way to the people it's about.

> Public data usually stops just short of the people it's about. We build the final stretch.

Governments and public institutions publish enormous amounts of data — clinical trials, recalls, inspection records, court dockets, famine warnings. Almost all of it is published *for institutions*, not for the people whose lives it describes. The information exists; the last stretch to the person who needs it doesn't.

**Domain:** `finalstretch.org` · **Contact:** `hello@finalstretch.org`

## Status: pre-incorporation

There is **no legal entity yet.** The intent is to form a **California nonprofit public benefit corporation** and file for 501(c)(3) status, but only after both developers have shipped an app and maintained it. Until then:

- Do not describe the project as a "nonprofit," a "Foundation," or "501(c)(3)" anywhere — not in the README, app metadata, the website, or code comments.
- The accurate phrase is **"a free, open-source project."**
- Do not add donation links, GitHub Sponsors, Ko-fi, or any payment mechanism. Money arriving with no entity creates a tax problem.

Write code as though the nonprofit exists — same standards, same commitments — but don't claim the status.

## Who's building it

Two developers, siblings, ages 20 and 16. They are **equal co-owners** of the GitHub org. Neither is senior.

- Each owns one app repo and is the **required reviewer** on the other's.
- Branch protection on `main` requires one approving review. No direct pushes.
- A parent is a third org owner for **recovery and legal notices only** — he does not merge, review, or push.

**Implication for you:** when you finish work, open a pull request. Never push to `main`, never merge your own PR, never suggest bypassing the review requirement to move faster. The review gate is a deliberate governance mechanism, not friction to route around.

---

## Hard product constraints

These are non-negotiable and written into a signed agreement between the developers. Treat them as compile-time requirements, not preferences.

1. **Free.** No purchase price, no in-app purchases, no paid tiers, no "pro" features.
2. **No advertising.** Ever. No analytics SDKs that monetize.
3. **No data collection.** The apps do not collect, transmit, sell, or share users' personal data. Where user data exists at all, **it stays on the device.** Apple privacy nutrition labels are set to *Data Not Collected* and that must remain true.
4. **No interested funding.** No money from any party with a stake in what users are shown — for health apps specifically, no trial sponsors, no recruitment firms, no pharmaceutical companies. This is the core differentiator against the commercial competition.

### What "no data collection" means architecturally

- **No backend of our own for user data.** Don't propose a server, a user account system, a login, or a sync service.
- User inputs (a health condition, a medication list, a location) are held in local storage only — Core Data, SwiftData, or the file system. Never a remote DB.
- Queries go directly from device to the public API. No proxy that could log them.
- No Firebase, no Amplitude, no Mixpanel, no Sentry with PII, no crash reporters that capture user content.
- If you need caching, cache on device.
- If a feature genuinely can't work without a server, say so explicitly and stop — don't quietly design one in.

This isn't only an ethical stance. Keeping everything on-device means the FTC Health Breach Notification Rule, California's CMIA, and most of CCPA simply don't attach. It's the cheapest compliance posture available and it should not be given up casually.

---

## The product test

For any feature, ask:

> **Does this move the data closer to the person, or move the person closer to the data?**

A filter panel that mirrors ClinicalTrials.gov's own taxonomy fails. Plain-language explanation of an eligibility criterion passes. A search form that requires knowing the right medical term fails. Accepting what someone would actually say and mapping it passes.

If a proposed feature only makes sense to someone who already understands the source dataset, it's the wrong feature.

---

## The apps

### 1. Clinical trial finder (primary)

**Data source:** ClinicalTrials.gov API v2 — `https://clinicaltrials.gov/api/v2/`

- No API key, no auth, no rate-limit registration. JSON.
- Key endpoints: `GET /studies` (search), `GET /studies/{nctId}` (single study).
- Useful params: `query.cond`, `query.term`, `query.locn`, `query.intr`, `filter.overallStatus`, `filter.geo` (e.g. `distance(39.0,-77.1,50mi)`), `fields` (projection — use it, responses are large), `pageSize` (max 1000), `pageToken`.
- Full spec at `https://clinicaltrials.gov/data-api/api`.

**The competitive landscape is not empty.** Antidote Match, Power (withpower.com), Massive Bio, TrialJectory, and Carebox all exist. The gap is not "no app exists." The gap is that **they're funded by trial sponsors and recruitment**, so they have an incentive in what gets surfaced. Free, neutral, and non-recruiting is the differentiator. Don't write copy claiming nothing like this exists.

**Safety rules — these matter more than any feature.**

- **Never assert eligibility.** Do not output "you qualify," "you're a match," a match score, or a ranked probability. Eligibility criteria are clinician-authored free text, frequently ambiguous, and a confident wrong answer does real harm to someone who is desperate.
- **Surface and explain, then hand off.** Show trials, translate criteria into plain language, flag what the person would need to discuss with a doctor, and route them to the study contact.
- Always show recruitment status, last-update date, and the NCT ID. Stale trials are a major failure mode of the official site.
- Never diagnose, never suggest treatments, never interpret lab values.
- Include a persistent, non-dismissible-on-first-run statement that this is not medical advice.

**If using an LLM for plain-language rewriting:** it must run on-device (Apple Foundation Models / Core ML) or the user's own query must never leave the device attached to identifiers. Do not route health text through a third-party API. If that's not achievable, ship a rules-based glossary instead — a worse feature is better than a broken privacy promise.

### 2. Second app — under consideration

The original idea was a **FEWS NET** (Famine Early Warning Systems Network) client. Two problems were identified:

- **Audience mismatch.** FEWS NET's users are humanitarian decision-makers with desktops and established workflows, not phone users.
- **Source instability.** FEWS NET went offline in early 2025 when USAID was dismantled, returned later that year, and now sits under the State Department. In August 2026 several countries were dropped from its outlook briefs. Building a consumer app on a source that can vanish is risky.

**Better-fitting alternatives discussed:**

- **A FEWS NET archive/mirror** — version-tracked ingestion so researchers can see what was published, when, and what quietly disappeared. Turns the fragility into the value proposition. This is a service, not an app, and would be **AGPL-3.0** rather than Apache.
- **ReliefWeb API** (UN OCHA) — better-funded, better API, aggregates situation reports across agencies. `https://apidoc.reliefweb.int/`
- **CMS Care Compare** (`data.cms.gov`) — nursing home / home health quality data. Families choose a facility in ~72 hours under extreme stress; the official site is a comparison-shopping tool for a decision nobody has time to comparison-shop. Strongest alternative candidate.
- **CourtListener / RECAP API** — federal dockets for pro se litigants.
- **Transit accessibility** — GTFS plus agency elevator-outage feeds; mainstream apps route wheelchair users through stations with dead elevators.
- **openFDA + CPSC + USDA FSIS recalls** — unified recall matching against a device-local list of what the user owns or takes.
- **EPA ECHO** — facility compliance history for neighborhood groups.

**If the second app is undecided, don't pick for them.** Surface tradeoffs and let the developers choose.

---

## Technical conventions

**Platform:** iOS, Swift, SwiftUI. Local persistence via SwiftData or Core Data.

**Licensing:** **Apache-2.0** for apps and shared libraries. Add the `LICENSE` file before any repo goes public. AGPL was considered and rejected — it conflicts with App Store distribution terms (the VLC problem) and its network clause does nothing for on-device apps. AGPL-3.0 *is* appropriate for any hosted service component.

**Repo layout:** one repo per app, plus a shared repo for common code — the on-device storage layer, API client patterns, the design system.

**Every repo has:** `README.md`, `LICENSE`, `CONTRIBUTING.md` (with DCO sign-off, `git commit -s`), `CODE_OF_CONDUCT.md`, and `DECISIONS.md` — one dated paragraph per product decision, both developers named. When you make a non-obvious architectural choice, add an entry.

**Accessibility is not optional.** These apps are for people in difficult circumstances, often older, often stressed, often on older hardware. Full VoiceOver support, Dynamic Type all the way up, sufficient contrast, no color-only signaling. Test at the largest accessibility text size before considering a view done. Offline-tolerant behavior and graceful degradation on slow connections matter more here than in a typical consumer app.

**Signing:** the Apple Developer Program account is an **Individual** account held by the 20-year-old. The 16-year-old has App Store Connect access as App Manager but **cannot create certificates** — that's an individual-account limitation. So: manual signing with a shared distribution certificate, and an App Store Connect API key for uploads. Don't propose workflows that assume automatic signing or per-developer certificates. Never suggest sharing the Apple ID login.

**Secrets:** there should be almost none, since there's no backend and the APIs need no keys. If a key ever becomes necessary, it does not go in the repo — and note that these repos are intended to go public, so anything committed is permanently exposed.

---

## Things not to do

- Don't propose a backend, user accounts, login, or cloud sync.
- Don't add analytics, crash reporting with user content, or any third-party SDK that phones home.
- Don't write "nonprofit," "Foundation," or "501(c)(3)" into any user-facing text or metadata.
- Don't add monetization of any kind, including "optional" tips.
- Don't output eligibility determinations, match scores, diagnoses, or treatment suggestions in the clinical trial app.
- Don't push to `main` or merge your own PR.
- Don't claim in copy that no comparable app exists — it isn't true, and the real differentiator is neutrality.
- Don't send user health text to a third-party LLM API.

---

## Quick orientation for a new session

1. Read `DECISIONS.md` in the repo you're working in — it's the record of what's already been settled and why.
2. Check which app repo you're in; the safety rules above are strictest for the clinical trial app.
3. If a proposed change touches any of the four hard constraints, stop and flag it rather than implementing a variant.
4. Open a PR. The other sibling reviews it.
