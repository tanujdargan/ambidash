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

interface MentorRequest {
  action: "insight" | "plan" | "mirror";
  context: {
    goals?: Array<MentorGoal>;
    snapshot?: { sleep_hours: number; steps: number; screen_time_hours: number };
    profile?: { name: string; age: number; peak_energy: string; cognitive_style: string };
    reflection?: { mood: string; blockers: string[]; text: string };
  };
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
  } else if (action === "mirror") {
    prompt = "You are the Honest Mirror mentor. Reflect reality without sugar-coating.\n\n";
    if (context.reflection) {
      prompt += `MOOD: "${context.reflection.mood}"\nBLOCKERS: ${context.reflection.blockers.join(", ")}\nTEXT: ${context.reflection.text}\n`;
    }
    prompt += "\nGive brutally honest feedback in 2-3 sentences. Use loss framing. Be direct.";
  }

  return prompt;
}
