import "@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

const ANTHROPIC_API_KEY = Deno.env.get("ANTHROPIC_API_KEY");
const CLAUDE_MODEL = "claude-sonnet-4-20250514";
const MAX_TOKENS = 1024;

interface MentorGoal {
  id: string;
  title: string;
  domain: string;
  neglect_days: number;
  streak: number;
  // PLAN REWRITE — the user's own goal detail makes goal-work concrete.
  details?: string;
  // F2 — measurable target layer (present only when the goal has a target)
  target_value?: number;
  current_value?: number;
  baseline_value?: number;
  unit?: string;
  direction?: string;
  percent_complete?: number;
  variance_state?: string; // "ahead" | "on_pace" | "behind"
  expected_value?: number;
}

// C1 — an existing checkpoint summary passed to the decompose action so the
// model can avoid duplicating and fill gaps.
interface MentorMilestone {
  title: string;
  period: string; // "year" | "quarter" | "month" | "week"
}

// A2 / #8 — a compact settled-action history entry folded into the plan prompt
// so the model adapts to what was actually done/skipped (and why).
interface MentorActionHistory {
  title: string;
  status: string; // "done" | "skipped"
  goal_id?: string;
  skip_reason?: string;
}

interface MentorRequest {
  action: "insight" | "plan" | "mirror" | "decompose";
  context: {
    goals?: Array<MentorGoal>;
    snapshot?: { sleep_hours: number; steps: number; screen_time_hours: number };
    profile?: { name: string; age: number; peak_energy: string; cognitive_style: string };
    reflection?: { mood: string; blockers: string[]; text: string };
    // C1 — decompose action payload: ONE goal (with horizon) + its existing chain.
    goal?: MentorGoal & { horizon?: string; subtitle?: string };
    milestones?: Array<MentorMilestone>;
    // A2 / #8 — adaptive plan context: recent history, latest reflection, intent.
    recent_done_actions?: Array<MentorActionHistory>;
    recent_skipped_actions?: Array<MentorActionHistory>;
    latest_reflection?: { mood: string; blockers: string[]; text: string };
    postponed_goal_title?: string;
    focus_intent?: string;
    // PLAN REWRITE — the user's daily-rhythm preferences (rendered text block) and
    // the concrete fixed/routine skeleton + free gaps, so the plan is woven around
    // the real day. Kept in lockstep with MentorPromptBuilder + DailyTimeline.
    preferences?: string;
    day_skeleton?: string;
    // A2 / #8 — two-way mentor reply: the user's written letter (insight action).
    user_message?: string;
    // MENTOR REFOCUS — the today → this-week → %-closer breakdown for the reply.
    forward_summary?: string;
  };
}

// C1 — coarse→fine band guidance per horizon, mirrors MilestoneGenerator.chainPeriods
// and MentorPromptBuilder.decomposePrompt on the client.
function chainBands(horizon: string | undefined): string {
  switch (horizon) {
    case "dream":
    case "build":
      return "year, then quarter, then month";
    case "now":
      return "month, then week";
    case "soon":
    default:
      return "quarter, then month, then week";
  }
}

/// Renders the F2 measurable/variance descriptor for a goal, or "" if no target.
function measurableLine(g: MentorGoal): string {
  if (g.target_value === undefined || g.current_value === undefined) return "";
  const unit = g.unit ? ` ${g.unit}` : "";
  const pct = g.percent_complete ?? 0;
  const dir = g.direction === "decrease" ? "decreasing" : "increasing";
  let pace = "on pace";
  if (g.variance_state === "behind") pace = "BEHIND pace";
  else if (g.variance_state === "ahead") pace = "ahead of pace";
  const expected = g.expected_value !== undefined ? `, on-pace value today: ${g.expected_value}${unit}` : "";
  return ` · measurable: ${g.current_value}/${g.target_value}${unit} (${pct}%, ${dir}), ${pace}${expected}`;
}

/// A2 / #8 — renders the adaptive plan-context block (recent done/skipped with
/// captured skip reasons, latest reflection, postpone/focus intent). Returns ""
/// when no signal is present so the cold-start prompt is unchanged. Kept in
/// lockstep with MentorPromptBuilder.adaptiveContext on the client.
function adaptivePlanContext(context: MentorRequest["context"]): string {
  let out = "";

  if (context.recent_done_actions?.length) {
    out += "\nRECENTLY COMPLETED (build on momentum, don't just repeat):\n";
    for (const a of context.recent_done_actions.slice(0, 8)) {
      out += `- ${a.title}\n`;
    }
  }

  if (context.recent_skipped_actions?.length) {
    out += "\nRECENTLY SKIPPED (adapt — don't blindly re-push what keeps getting deferred for the same reason):\n";
    for (const a of context.recent_skipped_actions.slice(0, 8)) {
      const reason = a.skip_reason ? ` — reason: ${a.skip_reason}` : "";
      out += `- ${a.title}${reason}\n`;
    }
  }

  if (context.latest_reflection) {
    const r = context.latest_reflection;
    const bits: string[] = [];
    if (r.mood) bits.push(`mood: ${r.mood}`);
    if (r.blockers?.length) bits.push(`blockers: ${r.blockers.join(", ")}`);
    if (r.text) bits.push(`note: ${r.text}`);
    if (bits.length) out += `\nLATEST REFLECTION (honor what they told you): ${bits.join(" · ")}\n`;
  }

  if (context.postponed_goal_title) {
    if (context.postponed_goal_title.toLowerCase() === "neither") {
      out += "\nUSER INTENT: They said they are NOT postponing any top goal today — keep all in play.\n";
    } else {
      out += `\nUSER INTENT: The user said they are postponing "${context.postponed_goal_title}" today — DEPRIORITIZE that goal (drop it or give it the lightest touch) and reallocate the freed time to their other goals.\n`;
    }
  }
  if (context.focus_intent) {
    out += `USER FOCUS: They want to focus on "${context.focus_intent}" — weight the plan toward it.\n`;
  }

  return out;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response(null, {
      headers: {
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Methods": "POST",
        "Access-Control-Allow-Headers": "authorization, content-type",
      },
    });
  }

  // Verify auth
  const authHeader = req.headers.get("authorization");
  if (!authHeader) {
    return new Response(JSON.stringify({ error: "Missing authorization" }), { status: 401 });
  }

  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_ANON_KEY")!,
    { global: { headers: { authorization: authHeader } } }
  );

  const { data: { user }, error: authError } = await supabase.auth.getUser();
  if (authError || !user) {
    return new Response(JSON.stringify({ error: "Unauthorized" }), { status: 401 });
  }

  if (!ANTHROPIC_API_KEY) {
    return new Response(JSON.stringify({ error: "AI not configured" }), { status: 503 });
  }

  const body: MentorRequest = await req.json();
  const prompt = buildPrompt(body);

  // Call Claude API
  const response = await fetch("https://api.anthropic.com/v1/messages", {
    method: "POST",
    headers: {
      "content-type": "application/json",
      "x-api-key": ANTHROPIC_API_KEY,
      "anthropic-version": "2023-06-01",
    },
    body: JSON.stringify({
      model: CLAUDE_MODEL,
      max_tokens: MAX_TOKENS,
      messages: [{ role: "user", content: prompt }],
    }),
  });

  if (!response.ok) {
    const err = await response.text();
    return new Response(JSON.stringify({ error: `AI error: ${response.status}` }), { status: 502 });
  }

  const data = await response.json();
  const text = data.content?.[0]?.text || "";

  // Log usage
  await supabase.from("mentor_feedback").insert({
    user_id: user.id,
    role: body.action === "mirror" ? "mirror" : "mentor",
    content: text,
    trigger_event: body.action,
    quota_cost: 1,
  });

  return new Response(JSON.stringify({ text }), {
    headers: { "Content-Type": "application/json" },
  });
});

function buildPrompt(body: MentorRequest): string {
  const { action, context } = body;
  let prompt = "";

  if (action === "insight") {
    // A2 / #8 — when a user_message is present this is a two-way mentor REPLY,
    // not a cold insight. Branch the framing accordingly.
    if (context.user_message) {
      // MENTOR REFOCUS — frame the reply forward: today → this week → %-closer.
      prompt = "You are M., the AI mentor inside ambidash, a life dashboard app. The user has written you a letter. Reply as their mentor — warm but direct, never generic, never a list.\n\n";
      prompt += "Frame your reply FORWARD, not as a status report: what they're DOING today, what they're working toward THIS WEEK, and how today's work moves them closer to the goal. Be honest/approximate about percentages (\"about\", \"roughly\").\n\n";
      if (context.forward_summary) {
        prompt += context.forward_summary + "\n";
      } else if (context.goals?.length) {
        prompt += "USER'S GOALS:\n";
        for (const g of context.goals) {
          prompt += `- ${g.title} (${g.domain}): ${g.neglect_days} days since progress${measurableLine(g)}\n`;
        }
      }
      if (context.snapshot) {
        prompt += `\nTODAY: Sleep ${context.snapshot.sleep_hours}h, ${context.snapshot.steps} steps, ${context.snapshot.screen_time_hours}h screen\n`;
      }
      prompt += `\nTHE USER WROTE:\n"${context.user_message}"\n`;
      prompt += "\nWrite back in 2-4 sentences. Respond to what they actually said, then anchor them: today you're doing X; this week you're working toward Y; finishing today puts you roughly N% closer to <goal>. Be specific, never generic, no bullet lists.";
    } else {
      prompt = "You are an AI mentor inside AmbiDash. Your role is to spot patterns the user wouldn't notice.\n\n";
      if (context.goals?.length) {
        prompt += "GOALS:\n";
        for (const g of context.goals) {
          prompt += `- ${g.title} (${g.domain}): ${g.neglect_days} days since progress, ${g.streak}d streak${measurableLine(g)}\n`;
        }
      }
      if (context.snapshot) {
        prompt += `\nTODAY: Sleep ${context.snapshot.sleep_hours}h, ${context.snapshot.steps} steps, ${context.snapshot.screen_time_hours}h screen\n`;
      }
      prompt += "\nGive ONE specific, actionable insight (2-3 sentences). Connect data points. For goals with a measurable target, watch the number: if a goal is BEHIND pace, name the gap and what would close it. Be direct.";
    }
  } else if (action === "plan") {
    // PLAN REWRITE — the plan IS the user's real day, woven from three layers:
    // fixed anchors, daily routines, and goal-work in the free gaps. Mirrors
    // MentorPromptBuilder.planPrompt on the client.
    prompt = "You are building this person's real day as a concrete, time-ordered plan they can just follow.\n\n";
    prompt += "The day has three layers, woven into ONE timeline:\n";
    prompt += "1) FIXED ANCHORS — wake, meals, work/class blocks, sleep. Set; build around them, never move them.\n";
    prompt += "2) DAILY ROUTINES — morning routine (skincare/oral care/no-phone), workout, cooking. Pull from their preferences.\n";
    prompt += "3) GOAL-WORK — concrete tasks toward active goals, slotted ONLY into the free gaps.\n\n";
    prompt += "Every line reads like a real instruction: time or relative cue + concrete action + duration. Voice:\n";
    prompt += "  \"07:00 — No phone, make breakfast (20m)\"; \"Before 13:00 — Have lunch (30m)\"; \"After class — Gym, push day (45m)\"; \"20:00 — Cook dinner (40m)\"; \"Work block 14:00–14:50 — draft section 2 of the thesis (50m)\"\n";
    prompt += "BANNED: \"show up today\", \"fix sleep\", \"make progress\". Every goal-work line names a SPECIFIC task.\n\n";
    if (context.profile) {
      prompt += `USER: ${context.profile.name}, age ${context.profile.age}, peak energy: ${context.profile.peak_energy}\n`;
    }
    if (context.preferences) {
      prompt += `\nYOUR DAY (real daily rhythm — build around these):\n${context.preferences}\n`;
    }
    if (context.day_skeleton) {
      prompt += context.day_skeleton;
    }
    if (context.goals?.length) {
      prompt += "\nGOALS (most neglected first):\n";
      for (const g of context.goals.sort((a, b) => b.neglect_days - a.neglect_days)) {
        const detail = g.details ? ` · detail: ${g.details}` : "";
        prompt += `- [id: ${g.id}] ${g.title}: ${g.neglect_days}d neglected${detail}${measurableLine(g)}\n`;
      }
    }
    // A2 / #8 — adaptive history + explicit user intent.
    prompt += adaptivePlanContext(context);
    prompt += "\n\nRespond with ONLY a JSON array covering the WHOLE day, time-ordered. Each item:\n";
    prompt += "{\"anchor_type\": \"fixed|routine|goal_work\", \"title\": \"...\", \"why\": \"...\", \"duration_minutes\": N, \"time_slot\": \"HH:MM\", \"schedule_cue\": \"...\", \"goal_id\": \"uuid\", \"amount\": N, \"metric\": \"unit\", \"cue_trigger\": \"...\", \"target_amount\": N, \"target_unit\": \"...\"}\n";
    prompt += "RULES: Emit every fixed anchor and routine from the skeleton PLUS goal-work in the gaps, ordered by time_slot. anchor_type \"fixed\" for wake/meals/work-class/sleep, \"routine\" for morning routine/workout/cooking, \"goal_work\" for goal tasks. ALWAYS set time_slot (HH:MM, 24h); schedule_cue is the relative label (\"Before 13:00\", \"After class\", \"By 23:30\") else \"\". Titles are clean instructions WITHOUT the time prefix and NEVER abstract. ONLY goal_work sets goal_id (one UUID from GOALS; never invent); fixed/routine omit goal_id/amount/target_amount. At most 6 goal_work items, prioritizing goals BEHIND pace then neglected. If no preferences/skeleton, still produce a concrete goal_work timeline across a sensible waking day.";
  } else if (action === "decompose") {
    prompt = "You are an AI mentor inside ambidash, a life dashboard app. Break ONE long-range goal into a concrete checkpoint chain — the missing middle between the goal and a same-day action.\n\n";
    const g = context.goal;
    if (g) {
      prompt += `GOAL: ${g.title} (${g.domain})\n`;
      if (g.horizon) prompt += `HORIZON: ${g.horizon}\n`;
      if (g.subtitle) prompt += `CONTEXT: ${g.subtitle}\n`;
      prompt += measurableLine(g);
      if (g.target_value !== undefined) prompt += "\n";
      prompt += `\nCHAIN SHAPE: For a ${g.horizon ?? "soon"} goal, nest checkpoints from coarse to fine — ${chainBands(g.horizon)}. Each finer node should be a child of the coarser node it advances.\n`;
    }
    if (context.milestones?.length) {
      prompt += "\nEXISTING CHECKPOINTS (do not duplicate; fill gaps or refine):\n";
      for (const m of context.milestones) {
        prompt += `- [${m.period}] ${m.title}\n`;
      }
    }
    prompt += "\nRespond with ONLY a JSON array of checkpoint items. Each item: ";
    prompt += "{\"title\": \"...\", \"detail\": \"...\", \"period\": \"year|quarter|month|week\", ";
    prompt += "\"parent_index\": N or null, \"target_value\": N or null, \"unit\": \"...\" or null, ";
    prompt += "\"weeks_from_now_start\": N, \"weeks_from_now_end\": N}\n";
    prompt += "Rules: period MUST be exactly one of year|quarter|month|week. parent_index references the zero-based position of an EARLIER item in this same array (the coarser checkpoint this one nests under), or null for a top-level node — this expresses the tree. weeks_from_now_start/weeks_from_now_end are integer week offsets from today defining the checkpoint window (start < end). Set target_value + unit only for measurable checkpoints; otherwise null. Keep the chain tight (typically 1 node per band, 2-4 items total). Make titles concrete and outcome-oriented, not generic.";
  } else if (action === "mirror") {
    prompt = "You are the Honest Mirror mentor. Reflect reality without sugar-coating.\n\n";
    if (context.reflection) {
      prompt += `MOOD: "${context.reflection.mood}"\nBLOCKERS: ${context.reflection.blockers.join(", ")}\nTEXT: ${context.reflection.text}\n`;
    }
    prompt += "\nGive brutally honest feedback in 2-3 sentences. Use loss framing. Be direct.";
  }

  return prompt;
}
