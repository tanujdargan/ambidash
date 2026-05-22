# ambidash — Design Specification

An all-in-one life dashboard for ambitious neurodivergent 18-25 year olds. The app understands you deeply through integrations and assessments, then generates a personalized daily action plan. An invisible AI mentor starts hands-on and fades as you build self-reliance.

## Target User

The archetype: ambitious 18-25 year olds juggling many simultaneous goals with neurodivergent tendencies (ADHD-leaning, overwhelm-prone, high ambition but inconsistent follow-through). People who set 10 goals, act on 3, and forget the rest until a random night panic.

## Core Philosophy

- **AI as invisible scaffolding** — AI powers the engine behind structured UI, not a chatbot. Users interact with clean native UI, not a conversation.
- **Diminishing AI over time** — starts heavy (detailed daily plans, proactive nudges), gradually pulls back as the user builds habits and self-awareness. Success = the user needs the app less.
- **Toxic motivation, not gamification** — no points, badges, or XP. Instead: streak pressure, guilt nudges, loss framing. "You're undoing 6 weeks of sleep habits" hits harder than "+50 XP."
- **Privacy-first** — all user data lives on device (SwiftData). Health data never leaves the phone. Only anonymized context summaries sent to cloud AI.

## Architecture

### High-Level

- **On-device**: SwiftUI app + SwiftData for all user data + integration layer (HealthKit, EventKit, DeviceActivity, Notes APIs)
- **Cloud backend**: Lightweight Swift server (Vapor or Hummingbird) handling two things: AI mentor calls (Claude API) and subscription management
- **Sync**: CloudKit for backup and multi-device sync. No user data stored server-side.
- **AI model**: Cloud-only (Claude API). No on-device LLM.
- **Offline**: Dashboard, goal tracking, and integrations work offline. AI features require internet.

### Tech Stack

- SwiftUI (UI)
- SwiftData (persistence)
- CloudKit (sync/backup)
- Vapor or Hummingbird (backend API)
- Claude API via Anthropic SDK (AI engine)
- StoreKit 2 (subscriptions)

### Privacy Model

When the AI mentor needs context, the app assembles a summary on-device (e.g., "user slept 5.2hrs, missed 3 workouts this week, has 4 goals at risk") and sends that — not raw HealthKit records or calendar details. The cloud backend processes the request and discards the context.

## Onboarding & Assessment System

### Flow

Welcome → Core Assessment (~5 min) → Connect Integrations → Declare Goals → Goal-specific assessments (~2 min each) → Work Style Preference → Profile built → First daily plan generated.

### Core Assessment (everyone, once, re-assessed quarterly)

**Cognitive & Work Style:**
- Focus preference (deep blocks, pomodoro, task-switching, flow-state)
- Peak energy time (morning, afternoon, night)
- Overwhelm response (shut down, hyperfocus on one, scatter)
- Preferred plan format (time-blocks, priority list, single next-action, focus blocks)

**Life Context:**
- Age, location, life stage
- Time commitments (school/work hours, fixed obligations)
- Living situation, access to resources

**Self-Awareness Baseline:**
- ADHD screening (ASRS-v1.1 adapted, simplified)
- Anxiety/stress level (GAD-7 inspired, simplified)
- Sleep quality self-assessment
- Life satisfaction across areas (1-10 wheel)

**Values & Priorities:**
- Top 3 life values
- What "next level" means (open-ended)
- Biggest current blocker
- Accountability preference

### Goal-Triggered Assessments (~2 min each)

Activated when a user adds a goal in a specific domain. Only relevant questions shown.

- **Fitness & Body** — activity level, training experience, body composition goal, diet, injuries
- **Cognitive & Learning** — learning style, current/target knowledge domains, time available, stimulation habits
- **Social & Communication** — anxiety level, current habits, communication goals, language targets
- **Career & Building** — current skills, target role/company, portfolio status, startup stage, financial target

**Design principle:** Assessments are conversational (one question at a time, contextual follow-ups), not clinical intake forms. Use validated instruments where possible but simplify the tone.

## Integration Layer

### Native Integrations (on-device APIs)

**Apple Health (HealthKit):**
- Sleep analysis (duration, stages, consistency)
- Step count, walking distance
- Workouts (type, duration, calories)
- Resting heart rate, HRV
- Active energy burned, mindful minutes
- Sync: HKObserverQuery for background delivery

**Calendar (EventKit):**
- Today's events, free/busy blocks
- Recurring commitments
- Sync: Foreground fetch + EKEventStoreChanged notification

**Screen Time (DeviceActivity + ManagedSettings):**
- Total screen time per day
- Per-category breakdown (social, entertainment, productivity)
- Number of pickups, notification count
- Limitation: Category-level only — Apple restricts exact app names
- Sync: DeviceActivityMonitor app extension

**Reminders (EventKit):**
- Incomplete/overdue items
- Completion patterns

### External Integrations (REST / local files)

**Notion (OAuth + REST API):**
- Recently modified pages (activity signal)
- Database entries (if shared)
- Sync: Periodic poll every few hours

**Obsidian (local vault via iCloud/FileManager):**
- Recently modified notes, note count growth
- Tags/folders (areas of interest)
- Privacy: File metadata only, not content (unless user opts in)

### Normalization

All raw data flows through a normalization layer into a unified `IntegrationSnapshot` — one daily summary record in SwiftData. Dashboard, AI mentor, and daily plan engine all read from this model. Adding new integrations later means implementing a new snapshot producer; downstream consumers don't change.

### Permission Model

Each integration is opt-in with clear explanation of what's read and why. Users can connect/disconnect at any time. Nothing breaks if integrations are skipped.

## Self-Awareness Dashboard (Home Screen)

The first thing users see when opening the app.

### Components

**Pulse Score (0-100):** Composite readiness score from today's integration data — sleep, activity, screen time, goal progress. Quick signal for "how equipped am I today?" Trending arrow vs. 7-day average.

**Dimension Bars:** Five life dimensions — Body, Mind, Focus, Social, Growth — scored from real data and goal progress. Color-coded: green (on track), amber (needs attention), red (slipping). Map to declared goals.

**Quick Stats:** Three most relevant numbers for today (sleep, screen time, steps by default). Rotate based on user's goals. Each shows trend vs. recent average. Tappable for 7/30-day charts.

**Goal Strip:** Horizontally scrollable chips showing every active goal with live status. The "goal drift prevention" surface. At a glance: which goals are healthy, which need attention, which are being neglected. Color-coded for scannability.

**AI Insight Card:** One pattern-spotted insight per day (free) or refreshing throughout the day (premium). Always tied to actual user data and goals. Cloud AI call consuming user's quota.

### Tab Bar

- **Dashboard** — self-awareness overview (this screen)
- **Today** — daily action plan
- **Goals** — manage, add, deep-dive into goals
- **Reflect** — end-of-day/week reflection and review

## Daily Action Plan (Today Tab)

### Plan Generation

The AI engine receives a context bundle assembled on-device:
- User profile (work style, energy peaks, preferences)
- Active goals with priority weights
- Today's calendar (free/busy blocks)
- Today's IntegrationSnapshot
- Yesterday's completion data
- Goal-specific assessment data

### Generation Logic

The AI doesn't just list tasks. It:
- Slots actions into calendar free time
- Respects energy peaks (hard tasks in focus windows)
- Balances across goals (no single goal dominates the day)
- Adjusts difficulty based on readiness (bad sleep = lighter day)
- Connects each action to WHY (strategic advisor role)
- Prioritizes neglected goals (drift prevention)

### Adaptive Format

Plan content is the same; presentation adapts to the user's assessed work style:
- **Focus Blocks** — time-slotted actions with reasoning (for structured learners)
- **Single Next Action** — one action at a time with Done/Skip/Later buttons (for overwhelm-prone users)
- **Priority List** — ranked list without strict times (for self-directed users)

### Action Tracking

- **Done**: Logs completion, updates goal progress
- **Skip**: Logs skip + optional reason. Feeds honest mirror during reflection
- **Later**: Moves to end of queue or next slot
- Skip patterns tracked — consistent skipping triggers honest mirror asking if goal is still real

### Plan Timing

- Generated: Early morning or on first app open
- Re-generated: If calendar changes significantly mid-day (premium)
- Free: 1 plan per day
- Premium: Unlimited re-generation + mid-day adaptation

## AI Mentor System

### Trigger Events

Morning plan generation, action skipped, reflection submitted, goal drift detected (days without progress), new integration data arrives.

A role router selects the appropriate mentor mode based on context.

### Four Roles

**Strategic Advisor** (morning plans, goal-setting, weekly review):
Connects daily actions to big goals. Provides WHY behind each action. Example: "You spent 0 hours on ML but 6 on leetcode. Your differentiator is research — shift 3 hours."

**Honest Mirror** (goal neglected, skip patterns, reflection review):
Reflects reality without sugar-coating. Example: "You haven't touched language in 12 days. Your streak died at day 23. Is this still a priority, or are we dropping it?"

**Pattern Spotter** (new data correlations, weekly trends):
Notices what users don't see. Example: "Focus scores are 40% higher on days you work out before 9am."

**Loss & Accountability** (streaks at risk, regression, goals slipping):
Toxic motivation lever. Example: "Your sleep consistency was 92% last month. This week: 57%. You're undoing 6 weeks of work."

### Notification Strategy (Duolingo-style)

- **Loss framing**: "You've been on social media 1.5hrs. That's your entire deep work block — gone."
- **Streak pressure**: "Your 34-day streak ends at midnight. 15 minutes of French. That's it."
- **Guilt nudge**: "You said lean body was top-3. You've skipped 4 of 5 workouts. Your goal is dead by June."
- **Positive reinforcement** (not all toxic): "7+ hrs sleep 6 nights running. Focus jumped 25%. Proof the system works when you do."

### Diminishing Scaffolding

**Weeks 1-4 (Heavy):** Full daily plans with detailed reasoning. Proactive push notifications. Multiple insights per day. Frequent check-in prompts.

**Months 2-3 (Moderate):** Plans become shorter. Notifications only for drift/risk. Insights focus on patterns, not basics. "You probably know what to do today — here's what I'd tweak."

**Months 4+ (Light):** Daily plan optional. Mentor speaks only when data shows real problems. Weekly summary replaces daily micro-management. Focus on long-term trajectory.

### Free vs. Premium AI

| Feature | Free | Premium |
|---------|------|---------|
| Daily plan generation | 1/day | Unlimited + mid-day re-gen |
| AI insight cards | 1/day | Refreshes throughout day |
| Pattern spotting | Weekly summary | Real-time |
| Guilt nudge notifications | 1/day max | Context-aware, as needed |
| Reflection analysis | Templated | Deep AI analysis |
| Strategic advisor | Not available | Full strategic reasoning |
| Honest mirror | Automated alerts | AI-personalized |
| Diminishing scaffolding | Fixed level | Adapts over time |

## Reflection & Review System (Reflect Tab)

### Daily Reflection (every evening)

- Auto-populated day summary (completed/skipped/stats)
- Quick mood selection (tap: crushed it / decent / meh / bad day)
- Blocker selection (procrastination, low energy, unexpected events, anxiety)
- Optional free-form text
- AI honest mirror response (premium: personalized, free: templated)
- Takes 1-2 minutes. Notification at user's chosen time.

### Weekly Review (every Sunday)

- Full week summary: goals hit vs. missed, trends
- Pattern spotter insights for the week
- Goal health check — each goal scored and colored
- Strategic advisor suggestions for next week
- Option to reprioritize or drop goals
- Compare this week vs. last week (loss framing)

### Monthly Deep Dive (premium)

- 30-day trajectory across all dimensions
- Before/after comparisons with real data
- "Where you were → where you are" narrative
- Goal recalibration suggestions
- Scaffold level adjustment

### Skip Analysis (automatic, background)

- Runs when skip patterns emerge
- Categorizes skips by goal, time of day, blocker type
- Feeds into plan engine to reschedule vulnerable actions
- Triggers honest mirror if skip rate hits threshold

## Data Model (SwiftData)

### Core Entities

- **UserProfile** — name, age, life stage, timezone, scaffold level
- **CoreAssessment** — cognitive style, energy peaks, ADHD score, anxiety score, values, blockers
- **WorkStylePreference** — plan format, streak toggle, notification intensity, max actions/day
- **Goal** — title, domain, priority, status, created date, last progress date, neglect days count
- **DomainAssessment** — domain, answers (JSON), assessed date
- **IntegrationSnapshot** — one per day; sleep, steps, workouts, screen time, categories, pickups, calendar free time, Notion/Obsidian activity
- **DailyPlan** — date, format, action count, whether regenerated
- **PlannedAction** — title, WHY reasoning, time slot, duration, status (pending/done/skipped/later), skip reason
- **GoalProgress** — daily score per goal, 7-day trend, status color
- **Streak** — current count, best count, last active date
- **Reflection** — date, type (daily/weekly/monthly), mood, freeform text
- **MentorFeedback** — role, content, trigger event, quota cost

### CloudKit Sync

All models sync via CloudKit. IntegrationSnapshot is device-specific (re-fetched from APIs per device). Conflict resolution: last-write-wins for most models. No server-side database.

## Business Model

**Freemium subscription.**

**Free tier:** Basic dashboard, goal tracking, all integrations, 1 daily plan, 1 AI insight, 1 notification/day, templated reflections, basic streak tracking.

**Premium tier (pricing TBD — likely $7-12/month based on AI cost per user):** Unlimited AI plans + mid-day re-gen, refreshing insights, real-time pattern spotting, context-aware notifications, deep reflection analysis, strategic advisor, personalized honest mirror, diminishing scaffolding, monthly deep dives.

## Scope Decomposition

This is a large project. Recommended build order:

1. **Foundation** — Xcode project, SwiftData models, basic navigation (tab bar), user profile
2. **Onboarding** — Core assessment flow, goal declaration, work style preference
3. **Integration Layer** — HealthKit, EventKit, DeviceActivity, normalization, IntegrationSnapshot
4. **Dashboard** — Pulse score, dimension bars, quick stats, goal strip (all from local data)
5. **Daily Plan (local)** — Plan model, action tracking (done/skip/later), format rendering — without AI initially (template-based)
6. **Backend + AI** — Vapor/Hummingbird server, Claude API integration, plan generation, insight generation
7. **Mentor System** — Role router, notification strategy, guilt nudges, streak system
8. **Reflection System** — Daily/weekly reflection flows, honest mirror, skip analysis
9. **External Integrations** — Notion OAuth, Obsidian vault access
10. **Premium + Payments** — StoreKit 2 subscription, usage metering, tier gating
11. **Diminishing Scaffolding** — Scaffold level tracking, progressive AI withdrawal
12. **Polish** — Charts, trend views, monthly deep dives, onboarding refinement
