-- Deck the Dates: Christmas Party 2026 voting table
-- (Argao Minstrels, El Voicetas, Cantores Dei, and CTU-Argao Chorale)
-- Run in Supabase: Dashboard > SQL Editor > New query > paste all of this > Run.
-- Safe to run again, including if you already ran the earlier version: it only adds what's missing.

create table if not exists public.choir_xmas_votes (
  id            uuid primary key default gen_random_uuid(),
  name          text not null check (char_length(name) between 1 and 40),
  name_key      text not null unique,
  voice_part    text not null check (voice_part in ('S','A','T','B','X')),
  -- d26 = Dec 26-27, d27 = Dec 27-28, d28 = Dec 28-29
  dates         text[] not null default '{}' check (dates <@ array['d26','d27','d28']::text[]),
  cant_make_it  boolean not null default false,
  venues        text[] not null default '{}' check (cardinality(venues) <= 12),
  guests_adults smallint not null default 0 check (guests_adults between 0 and 10),
  guests_kids   smallint not null default 0 check (guests_kids between 0 and 10),
  song_request  text check (char_length(song_request) <= 120),
  note          text check (char_length(note) <= 300),
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);

-- Which choir each voter belongs to. name_key is "choir|name", so two people
-- with the same name in different choirs get separate votes.
alter table public.choir_xmas_votes add column if not exists choir text;

alter table public.choir_xmas_votes drop constraint if exists choir_xmas_votes_choir_check;
alter table public.choir_xmas_votes add constraint choir_xmas_votes_choir_check
  check (choir is null or choir in ('minstrels','voicetas','cantores','chorale'));

alter table public.choir_xmas_votes drop constraint if exists choir_xmas_votes_name_key_check;
alter table public.choir_xmas_votes add constraint choir_xmas_votes_name_key_check
  check (char_length(name_key) between 1 and 80);

-- Pledges (GCash or Cash, plus an optional food pledge) and the "I'm coming as..." outfit.
alter table public.choir_xmas_votes add column if not exists pledge_method text;
alter table public.choir_xmas_votes add column if not exists pledge_food text;
alter table public.choir_xmas_votes add column if not exists coming_as text;

alter table public.choir_xmas_votes drop constraint if exists choir_xmas_votes_pledge_method_check;
alter table public.choir_xmas_votes add constraint choir_xmas_votes_pledge_method_check
  check (pledge_method is null or pledge_method in ('gcash','cash'));

alter table public.choir_xmas_votes drop constraint if exists choir_xmas_votes_pledge_food_check;
alter table public.choir_xmas_votes add constraint choir_xmas_votes_pledge_food_check
  check (pledge_food is null or char_length(pledge_food) <= 80);

alter table public.choir_xmas_votes drop constraint if exists choir_xmas_votes_coming_as_check;
alter table public.choir_xmas_votes add constraint choir_xmas_votes_coming_as_check
  check (coming_as is null or char_length(coming_as) <= 100);

-- After the date and venue vote closes: "I'll be there" (true) or "Can't make it after all" (false).
-- Empty means they haven't said, so their vote for the winning night counts as their answer.
alter table public.choir_xmas_votes add column if not exists going boolean;

create or replace function public.choir_xmas_touch()
returns trigger language plpgsql set search_path = '' as $$
begin
  new.updated_at := now();
  return new;
end $$;

drop trigger if exists choir_xmas_touch on public.choir_xmas_votes;
create trigger choir_xmas_touch before update on public.choir_xmas_votes
  for each row execute function public.choir_xmas_touch();

-- Anyone with the link can read, add and edit votes (no delete), same as the reunion app.
alter table public.choir_xmas_votes enable row level security;

drop policy if exists "choir xmas read" on public.choir_xmas_votes;
create policy "choir xmas read" on public.choir_xmas_votes
  for select to anon, authenticated using (true);

drop policy if exists "choir xmas add" on public.choir_xmas_votes;
create policy "choir xmas add" on public.choir_xmas_votes
  for insert to anon, authenticated with check (true);

drop policy if exists "choir xmas edit" on public.choir_xmas_votes;
create policy "choir xmas edit" on public.choir_xmas_votes
  for update to anon, authenticated using (true) with check (true);

grant select, insert, update on public.choir_xmas_votes to anon, authenticated;

-- Tell the website's data layer to pick up the changes right away.
notify pgrst, 'reload schema';

-- Handy later:
-- See all votes:        select name, choir, voice_part, dates, venues, going, pledge_method, pledge_food, coming_as, song_request from public.choir_xmas_votes order by created_at;
-- Clear test votes:     delete from public.choir_xmas_votes;
-- Remove one person:    delete from public.choir_xmas_votes where name = 'Their Name' and choir = 'voicetas';
