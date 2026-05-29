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
  } else if (action === "plan") {
    prompt = "Generate a daily action plan as a JSON array. Each item: {title, why, duration_minutes, time_slot, goal_id, amount, metric}.\n";
    prompt += "Every action MUST set goal_id to exactly one id from the GOALS list. Do not invent ids.\n";
    prompt += "For goals with a measurable target, size the action to move the number: set \"amount\" to the increment this action should add (in the goal's unit) and \"metric\" to that unit; omit both for goals without a target.\n\n";
    if (context.profile) {
      prompt += `USER: ${context.profile.name}, age ${context.profile.age}, peak energy: ${context.profile.peak_energy}\n`;
    }
    if (context.goals?.length) {
      prompt += "GOALS (by neglect):\n";
      for (const g of context.goals.sort((a, b) => b.neglect_days - a.neglect_days)) {
        prompt += `- [id: ${g.id}] ${g.title}: ${g.neglect_days}d neglected${measurableLine(g)}\n`;
      }
    }
    prompt += "\nCreate 4-6 actions. Prioritize goals that are BEHIND pace toward their target, then neglected goals. Respond with ONLY the JSON array.";
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
