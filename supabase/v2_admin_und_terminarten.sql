-- Version 2: Admin-Rechte und Terminarten
-- Abwärtskompatibel: alte App-Version läuft weiter.

-- Terminart: normaler Termin, Geburtstag oder vorgemerkte Familienzeit
alter table public.events
  add column if not exists kind text not null default 'event'
  check (kind in ('event','birthday','family_time'));

-- Personen: nur der Admin (Rolle owner) verwaltet die Familie.
-- Mitglieder dürfen nur sich selbst anlegen bzw. einen freien Eintrag als "das bin ich" übernehmen
-- und ihren eigenen Eintrag (Name, Farbe) ändern.
drop policy if exists "people: anlegen" on public.people;
drop policy if exists "people: ändern"  on public.people;
drop policy if exists "people: löschen" on public.people;

create policy "people: anlegen" on public.people for insert to authenticated
  with check (private.is_family_owner(family_id)
           or (private.is_family_member(family_id) and user_id = (select auth.uid())));

create policy "people: ändern" on public.people for update to authenticated
  using (private.is_family_owner(family_id)
      or (private.is_family_member(family_id) and (user_id is null or user_id = (select auth.uid()))))
  with check (private.is_family_owner(family_id)
      or (private.is_family_member(family_id) and user_id = (select auth.uid())));

create policy "people: löschen" on public.people for delete to authenticated
  using (private.is_family_owner(family_id));

-- Mitglieder entfernen: unverändert (nur Admin entfernt andere, jeder außer dem Admin kann austreten).
