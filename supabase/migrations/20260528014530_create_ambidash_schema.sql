-- AmbiDash database schema
-- User profiles, goals, plans, reflections, mentor feedback

-- Profiles (extends auth.users)
create table public.profiles (
    id uuid primary key references auth.users(id) on delete cascade,
    name text not null default '',
    age integer,
    life_stage text default 'student',
    timezone text default 'America/Toronto',
    scaffold_level integer default 3,
    cognitive_style text,
    peak_energy_time text,
    overwhelm_response text,
    adhd_score integer default 0,
    anxiety_score integer default 0,
    top_values text[] default '{}',
    biggest_blocker text,
    accountability_preference text,
    plan_format text default 'focusBlocks',
    notification_intensity text default 'moderate',
    max_actions_per_day integer default 6,
    created_at timestamptz default now(),
    updated_at timestamptz default now()
);

alter table public.profiles enable row level security;
create policy "Users can read own profile" on public.profiles for select using (auth.uid() = id);
create policy "Users can update own profile" on public.profiles for update using (auth.uid() = id);
create policy "Users can insert own profile" on public.profiles for insert with check (auth.uid() = id);

-- Goals
create table public.goals (
    id uuid primary key default gen_random_uuid(),
    user_id uuid not null references auth.users(id) on delete cascade,
    title text not null,
    subtitle text default '',
    domain text not null,
    horizon text default 'now',
    priority integer default 1,
    is_active boolean default true,
    last_progress_date timestamptz default now(),
    streak_current integer default 0,
    streak_best integer default 0,
    streak_last_active timestamptz default now(),
    created_at timestamptz default now(),
    updated_at timestamptz default now()
);

alter table public.goals enable row level security;
create policy "Users can CRUD own goals" on public.goals for all using (auth.uid() = user_id);

-- Daily plans
create table public.daily_plans (
    id uuid primary key default gen_random_uuid(),
    user_id uuid not null references auth.users(id) on delete cascade,
    date date not null,
    format text default 'focusBlocks',
    regenerated boolean default false,
    created_at timestamptz default now()
);

alter table public.daily_plans enable row level security;
create policy "Users can CRUD own plans" on public.daily_plans for all using (auth.uid() = user_id);

-- Planned actions
create table public.planned_actions (
    id uuid primary key default gen_random_uuid(),
    plan_id uuid not null references public.daily_plans(id) on delete cascade,
    user_id uuid not null references auth.users(id) on delete cascade,
    title text not null,
    why_reasoning text default '',
    time_slot text default '',
    duration_minutes integer default 30,
    status text default 'pending',
    completed_at timestamptz,
    skip_reason text,
    created_at timestamptz default now()
);

alter table public.planned_actions enable row level security;
create policy "Users can CRUD own actions" on public.planned_actions for all using (auth.uid() = user_id);

-- Reflections
create table public.reflections (
    id uuid primary key default gen_random_uuid(),
    user_id uuid not null references auth.users(id) on delete cascade,
    date date not null default current_date,
    type text default 'daily',
    mood text default '',
    blockers text[] default '{}',
    freeform_text text default '',
    created_at timestamptz default now()
);

alter table public.reflections enable row level security;
create policy "Users can CRUD own reflections" on public.reflections for all using (auth.uid() = user_id);

-- Mentor feedback / letters
create table public.mentor_feedback (
    id uuid primary key default gen_random_uuid(),
    user_id uuid not null references auth.users(id) on delete cascade,
    role text not null,
    content text not null,
    trigger_event text default '',
    quota_cost integer default 1,
    created_at timestamptz default now()
);

alter table public.mentor_feedback enable row level security;
create policy "Users can CRUD own mentor feedback" on public.mentor_feedback for all using (auth.uid() = user_id);

-- Integration snapshots
create table public.integration_snapshots (
    id uuid primary key default gen_random_uuid(),
    user_id uuid not null references auth.users(id) on delete cascade,
    date date not null,
    sleep_hours double precision default 0,
    sleep_score integer default 0,
    steps integer default 0,
    workout_count integer default 0,
    screen_time_hours double precision default 0,
    pickups integer default 0,
    calendar_free_minutes integer default 0,
    created_at timestamptz default now(),
    unique(user_id, date)
);

alter table public.integration_snapshots enable row level security;
create policy "Users can CRUD own snapshots" on public.integration_snapshots for all using (auth.uid() = user_id);

-- Auto-create profile on signup
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = ''
as $$
begin
    insert into public.profiles (id, name)
    values (new.id, coalesce(new.raw_user_meta_data->>'name', ''));
    return new;
end;
$$;

create or replace trigger on_auth_user_created
    after insert on auth.users
    for each row execute function public.handle_new_user();

-- Updated_at triggers
create or replace function public.update_updated_at()
returns trigger language plpgsql
as $$
begin
    new.updated_at = now();
    return new;
end;
$$;

create trigger profiles_updated_at before update on public.profiles
    for each row execute function public.update_updated_at();
create trigger goals_updated_at before update on public.goals
    for each row execute function public.update_updated_at();
