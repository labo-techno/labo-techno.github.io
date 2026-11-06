-- Labo Techno : base de données Supabase
-- À coller en entier dans Supabase > SQL Editor > New query, puis « Run ». Une seule fois.

-- 1. Tables ---------------------------------------------------------------
create table if not exists public.groupes (
  code         text primary key,
  nom          text not null check (char_length(nom) between 1 and 60),
  formateur_id uuid not null references auth.users on delete cascade,
  created_at   timestamptz not null default now()
);

create table if not exists public.profils (
  id           uuid primary key references auth.users on delete cascade,
  pseudo       text not null check (char_length(pseudo) between 1 and 24),
  groupe_code  text references public.groupes(code) on update cascade on delete set null,
  role         text not null default 'apprenant' check (role in ('apprenant', 'formateur')),
  consentement timestamptz not null default now()
);

create table if not exists public.progression (
  user_id    uuid primary key references auth.users on delete cascade,
  data       jsonb not null,
  updated_at timestamptz not null default now()
);

create table if not exists public.pratique (
  user_id      uuid not null references auth.users on delete cascade,
  competence   text not null,
  statut       text not null check (statut in ('valide', 'reprendre')),
  formateur_id uuid references auth.users on delete set null,
  updated_at   timestamptz not null default now(),
  primary key (user_id, competence)
);

-- Formation (parcours) : CAP-PAT, CAP-BOU, CAP-CHT. Ces lignes ajoutent aussi les colonnes à une base déjà installée.
alter table public.groupes add column if not exists parcours text not null default 'CAP-PAT';
alter table public.profils add column if not exists parcours text;

-- 2. Fonctions d'aide (sécurisées, rangées hors de l'API publique) ------------
create schema if not exists private;
grant usage on schema private to authenticated;

create or replace function private.est_formateur() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from profils where id = auth.uid() and role = 'formateur');
$$;

create or replace function private.suit_eleve(eleve uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from profils p join groupes g on g.code = p.groupe_code
    where p.id = eleve and g.formateur_id = auth.uid()
  );
$$;
revoke all on function private.est_formateur() from public, anon;
revoke all on function private.suit_eleve(uuid) from public, anon;
grant execute on function private.est_formateur() to authenticated;
grant execute on function private.suit_eleve(uuid) to authenticated;

-- Un utilisateur ne peut pas se donner lui-même le rôle de formateur.
create or replace function public.bloque_role() returns trigger
language plpgsql set search_path = public as $$
begin
  if new.role is distinct from old.role and current_user = 'authenticated' then
    new.role := old.role;
  end if;
  return new;
end $$;
drop trigger if exists profil_role on public.profils;
create trigger profil_role before update on public.profils for each row execute function public.bloque_role();

-- Droit à l'effacement : l'utilisateur supprime son compte et toutes ses données.
create or replace function public.supprimer_mon_compte() returns void
language sql security definer set search_path = public, auth as $$
  delete from auth.users where id = auth.uid();
$$;
revoke all on function public.supprimer_mon_compte() from public, anon;
grant execute on function public.supprimer_mon_compte() to authenticated;

-- 3. Règles d'accès (Row Level Security) ----------------------------------
alter table public.groupes     enable row level security;
alter table public.profils     enable row level security;
alter table public.progression enable row level security;
alter table public.pratique    enable row level security;

-- Groupes : tout utilisateur connecté peut vérifier un code ; seul un formateur crée ses groupes.
drop policy if exists groupes_lecture on public.groupes;
create policy groupes_lecture on public.groupes for select to authenticated using (true);
drop policy if exists groupes_creation on public.groupes;
create policy groupes_creation on public.groupes for insert to authenticated with check (formateur_id = auth.uid() and private.est_formateur());
drop policy if exists groupes_modif on public.groupes;
create policy groupes_modif on public.groupes for update to authenticated using (formateur_id = auth.uid()) with check (formateur_id = auth.uid());
drop policy if exists groupes_suppression on public.groupes;
create policy groupes_suppression on public.groupes for delete to authenticated using (formateur_id = auth.uid());

-- Profils : chacun voit le sien ; le formateur voit ceux de ses groupes.
drop policy if exists profils_lecture on public.profils;
create policy profils_lecture on public.profils for select to authenticated using (id = auth.uid() or private.suit_eleve(id));
drop policy if exists profils_creation on public.profils;
create policy profils_creation on public.profils for insert to authenticated with check (id = auth.uid() and role = 'apprenant');
drop policy if exists profils_modif on public.profils;
create policy profils_modif on public.profils for update to authenticated using (id = auth.uid()) with check (id = auth.uid());

-- Progression : chacun écrit la sienne ; le formateur lit celle de ses élèves.
drop policy if exists progression_lecture on public.progression;
create policy progression_lecture on public.progression for select to authenticated using (user_id = auth.uid() or private.suit_eleve(user_id));
drop policy if exists progression_creation on public.progression;
create policy progression_creation on public.progression for insert to authenticated with check (user_id = auth.uid());
drop policy if exists progression_modif on public.progression;
create policy progression_modif on public.progression for update to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());

-- Validation pratique : l'élève la lit ; seul son formateur l'écrit.
drop policy if exists pratique_lecture on public.pratique;
create policy pratique_lecture on public.pratique for select to authenticated using (user_id = auth.uid() or private.suit_eleve(user_id));
drop policy if exists pratique_creation on public.pratique;
create policy pratique_creation on public.pratique for insert to authenticated with check (private.suit_eleve(user_id) and formateur_id = auth.uid());
drop policy if exists pratique_modif on public.pratique;
create policy pratique_modif on public.pratique for update to authenticated using (private.suit_eleve(user_id)) with check (formateur_id = auth.uid());
drop policy if exists pratique_suppression on public.pratique;
create policy pratique_suppression on public.pratique for delete to authenticated using (private.suit_eleve(user_id));

-- Anciennes fonctions d'aide (versions précédentes), remplacées par private.*
drop function if exists public.est_formateur();
drop function if exists public.suit_eleve(uuid);

-- 4. Devenir formateur -------------------------------------------------------
-- Après votre première connexion dans l'appli (avec votre pseudo, sans code de groupe),
-- exécutez cette ligne en remplaçant l'adresse par la vôtre :
-- update public.profils set role = 'formateur' where id = (select id from auth.users where email = 'votre.adresse@exemple.fr');
