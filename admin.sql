-- Labo Techno : mode administrateur (à exécuter après supabase.sql). Peut être relancé sans risque.

-- Liste des administrateurs (modifiable seulement depuis Supabase, jamais depuis l'appli)
create table if not exists public.admins (
  user_id   uuid primary key references auth.users on delete cascade,
  ajoute_le timestamptz not null default now()
);
alter table public.admins enable row level security;

-- Dernière activité dans l'appli (pour savoir qui est connecté)
alter table public.profils add column if not exists derniere_activite timestamptz;

create schema if not exists private;
grant usage on schema private to authenticated;

create or replace function private.est_admin() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from admins where user_id = auth.uid());
$$;
revoke all on function private.est_admin() from public, anon;
grant execute on function private.est_admin() to authenticated;

-- Un administrateur a aussi les droits de formateur (créer des groupes)
create or replace function private.est_formateur() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from profils where id = auth.uid() and role = 'formateur')
      or exists (select 1 from admins where user_id = auth.uid());
$$;

-- Règles d'accès supplémentaires pour l'administrateur (ajoutées, rien n'est supprimé)
do $$
declare r record;
begin
  for r in select * from (values
    ('admins', 'admins_lecture_soi', 'select', 'user_id = auth.uid()', null),
    ('profils', 'profils_admin_lecture', 'select', 'private.est_admin()', null),
    ('progression', 'progression_admin_lecture', 'select', 'private.est_admin()', null),
    ('pratique', 'pratique_admin_lecture', 'select', 'private.est_admin()', null),
    ('pratique', 'pratique_admin_creation', 'insert', null, 'private.est_admin()'),
    ('pratique', 'pratique_admin_modif', 'update', 'private.est_admin()', 'private.est_admin()'),
    ('pratique', 'pratique_admin_suppression', 'delete', 'private.est_admin()', null)
  ) as t(tbl, nom, cmd, using_expr, check_expr)
  loop
    if not exists (select 1 from pg_policies where schemaname = 'public' and tablename = r.tbl and policyname = r.nom) then
      execute format('create policy %I on public.%I for %s to authenticated%s%s', r.nom, r.tbl, r.cmd,
        case when r.using_expr is null then '' else ' using (' || r.using_expr || ')' end,
        case when r.check_expr is null then '' else ' with check (' || r.check_expr || ')' end);
    end if;
  end loop;
end $$;

-- Liste de tous les comptes, avec e-mail et dates : réservée aux administrateurs
create or replace function public.admin_comptes()
returns table (id uuid, email text, inscrit_le timestamptz, derniere_connexion timestamptz,
               pseudo text, role text, groupe_code text, parcours text, derniere_activite timestamptz, admin boolean)
language plpgsql stable security definer set search_path = public, auth as $$
begin
  if not private.est_admin() then
    raise exception 'Réservé aux administrateurs';
  end if;
  return query
    select u.id, u.email::text, u.created_at, u.last_sign_in_at,
           p.pseudo, p.role, p.groupe_code, p.parcours, p.derniere_activite,
           exists (select 1 from admins a where a.user_id = u.id)
    from auth.users u left join profils p on p.id = u.id
    order by coalesce(p.derniere_activite, u.last_sign_in_at, u.created_at) desc nulls last;
end $$;
revoke all on function public.admin_comptes() from public, anon;
grant execute on function public.admin_comptes() to authenticated;

-- Nommer un administrateur (remplacer l'adresse) :
-- insert into public.admins (user_id) select id from auth.users where email = 'votre.adresse@exemple.fr' on conflict do nothing;
