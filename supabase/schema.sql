-- Familienkalender: Datenbankschema für Supabase
-- Tabellen: families, family_members, people, events
-- Zugriff: nur Mitglieder einer Familie sehen und ändern deren Daten (Row Level Security).

-- ---------- Tabellen ----------
create table public.families (
  id          uuid primary key default gen_random_uuid(),
  name        text not null check (char_length(name) between 1 and 60),
  invite_code text not null unique,
  created_by  uuid not null default auth.uid() references auth.users(id) on delete cascade,
  created_at  timestamptz not null default now()
);

create table public.family_members (
  family_id uuid not null references public.families(id) on delete cascade,
  user_id   uuid not null references auth.users(id) on delete cascade,
  role      text not null default 'member' check (role in ('owner','member')),
  joined_at timestamptz not null default now(),
  primary key (family_id, user_id)
);
create index family_members_user_idx on public.family_members(user_id);

create table public.people (
  id         uuid primary key default gen_random_uuid(),
  family_id  uuid not null references public.families(id) on delete cascade,
  name       text not null check (char_length(name) between 1 and 40),
  color      text not null default '#1f6f8b' check (color ~ '^#[0-9a-fA-F]{6}$'),
  user_id    uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now()
);
create index people_family_idx on public.people(family_id);
create index people_user_idx on public.people(user_id);

create table public.events (
  id           uuid primary key default gen_random_uuid(),
  family_id    uuid not null references public.families(id) on delete cascade,
  title        text not null check (char_length(title) between 1 and 120),
  date         date not null,
  end_date     date,
  all_day      boolean not null default false,
  start_time   time,
  end_time     time,
  people       uuid[] not null default '{}',
  repeat       text not null default 'none' check (repeat in ('none','weekly','biweekly','monthly','yearly')),
  repeat_until date,
  location     text check (char_length(location) <= 160),
  note         text check (char_length(note) <= 2000),
  created_by   uuid default auth.uid() references auth.users(id) on delete set null,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);
create index events_family_date_idx on public.events(family_id, date);
create index events_created_by_idx on public.events(created_by);
create index families_created_by_idx on public.families(created_by);

-- ---------- Hilfsfunktionen (nicht über die API erreichbar) ----------
create schema if not exists private;
revoke all on schema private from public, anon;
grant usage on schema private to authenticated;

create or replace function private.is_family_member(fid uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.family_members m
                 where m.family_id = fid and m.user_id = (select auth.uid()));
$$;

create or replace function private.is_family_owner(fid uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.family_members m
                 where m.family_id = fid and m.user_id = (select auth.uid()) and m.role = 'owner');
$$;

create or replace function public.new_invite_code()
returns text language sql volatile set search_path = '' as $$
  select upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 12));
$$;

create or replace function public.touch_updated_at()
returns trigger language plpgsql set search_path = '' as $$
begin new.updated_at := now(); return new; end; $$;
create trigger events_touch before update on public.events
  for each row execute function public.touch_updated_at();

-- ---------- Aktionen (RPC) ----------
create or replace function public.create_family(p_name text)
returns uuid language plpgsql security definer set search_path = '' as $$
declare fid uuid;
begin
  if auth.uid() is null then raise exception 'not_signed_in'; end if;
  insert into public.families(name, invite_code, created_by)
    values (trim(p_name), public.new_invite_code(), auth.uid()) returning id into fid;
  insert into public.family_members(family_id, user_id, role) values (fid, auth.uid(), 'owner');
  return fid;
end; $$;

create or replace function public.join_family(p_code text)
returns uuid language plpgsql security definer set search_path = '' as $$
declare fid uuid;
begin
  if auth.uid() is null then raise exception 'not_signed_in'; end if;
  select id into fid from public.families where invite_code = upper(trim(p_code));
  if fid is null then raise exception 'invalid_code'; end if;
  insert into public.family_members(family_id, user_id) values (fid, auth.uid())
    on conflict do nothing;
  return fid;
end; $$;

create or replace function public.rotate_invite_code(p_family uuid)
returns text language plpgsql security definer set search_path = '' as $$
declare c text;
begin
  if not private.is_family_owner(p_family) then raise exception 'not_owner'; end if;
  c := public.new_invite_code();
  update public.families set invite_code = c where id = p_family;
  return c;
end; $$;

revoke execute on function private.is_family_member(uuid), private.is_family_owner(uuid),
  public.new_invite_code(), public.create_family(text), public.join_family(text),
  public.rotate_invite_code(uuid), public.touch_updated_at() from public, anon;
grant execute on function private.is_family_member(uuid), private.is_family_owner(uuid),
  public.create_family(text), public.join_family(text), public.rotate_invite_code(uuid) to authenticated;

-- ---------- Row Level Security ----------
alter table public.families       enable row level security;
alter table public.family_members enable row level security;
alter table public.people         enable row level security;
alter table public.events         enable row level security;

create policy "families: Mitglieder lesen" on public.families
  for select to authenticated using (private.is_family_member(id));
create policy "families: Besitzer ändert" on public.families
  for update to authenticated using (private.is_family_owner(id)) with check (private.is_family_owner(id));
create policy "families: Besitzer löscht" on public.families
  for delete to authenticated using (private.is_family_owner(id));

create policy "members: Mitglieder lesen" on public.family_members
  for select to authenticated using (private.is_family_member(family_id));
create policy "members: austreten oder entfernen" on public.family_members
  for delete to authenticated using (
    (user_id = (select auth.uid()) and role <> 'owner') or
    (private.is_family_owner(family_id) and user_id <> (select auth.uid())));

create policy "people: lesen" on public.people for select to authenticated using (private.is_family_member(family_id));
create policy "people: anlegen" on public.people for insert to authenticated with check (private.is_family_member(family_id));
create policy "people: ändern" on public.people for update to authenticated using (private.is_family_member(family_id)) with check (private.is_family_member(family_id));
create policy "people: löschen" on public.people for delete to authenticated using (private.is_family_member(family_id));

create policy "events: lesen" on public.events for select to authenticated using (private.is_family_member(family_id));
create policy "events: anlegen" on public.events for insert to authenticated with check (private.is_family_member(family_id));
create policy "events: ändern" on public.events for update to authenticated using (private.is_family_member(family_id)) with check (private.is_family_member(family_id));
create policy "events: löschen" on public.events for delete to authenticated using (private.is_family_member(family_id));

-- ---------- Live-Aktualisierung ----------
alter publication supabase_realtime add table public.events, public.people;
