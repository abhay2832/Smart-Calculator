-- Smart Calculator counters + private visitor report. Run the whole file in Supabase > SQL Editor.
create table if not exists sc_visitors(vid text primary key, last_seen timestamptz not null default now(), last_used timestamptz);
create table if not exists sc_monthly(month text not null, vid text not null, primary key(month,vid));
create table if not exists sc_daily(day date not null, vid text not null, primary key(day,vid));
create table if not exists sc_admin(k text primary key);
alter table sc_visitors enable row level security;
alter table sc_monthly enable row level security;
alter table sc_daily enable row level security;
alter table sc_admin enable row level security;
-- Passcode: run this ONE line separately with your own secret passcode (not in this file):
-- insert into sc_admin(k) values ('write-your-own-secret-passcode-here');
create or replace function sc_ping(p_vid text, p_used boolean default false) returns json language plpgsql security definer set search_path=public as $$
declare m text := to_char(now() at time zone 'Asia/Kolkata','YYYY-MM'); r json;
begin
  if p_vid is null or length(p_vid)<8 or length(p_vid)>64 then raise exception 'bad id'; end if;
  insert into sc_visitors(vid,last_seen,last_used) values(p_vid,now(),case when p_used then now() end)
    on conflict(vid) do update set last_seen=now(), last_used=case when p_used then now() else sc_visitors.last_used end;
  insert into sc_monthly(month,vid) values(m,p_vid) on conflict do nothing;
  insert into sc_daily(day,vid) values((now() at time zone 'Asia/Kolkata')::date,p_vid) on conflict do nothing;
  select json_build_object('live',(select count(*) from sc_visitors where last_seen>now()-interval '60 seconds'),'using',(select count(*) from sc_visitors where last_used>now()-interval '2 minutes'),'monthly',(select count(*) from sc_monthly where month=m)) into r;
  return r;
end $$;
create or replace function sc_report(p_pass text) returns json language plpgsql security definer set search_path=public as $$
begin
  if not exists(select 1 from sc_admin where k=p_pass) then raise exception 'wrong passcode'; end if;
  return json_build_object('days',(select coalesce(json_agg(json_build_object('d',d,'n',n) order by d),'[]'::json) from (select day::text d,count(*) n from sc_daily where day>=(now() at time zone 'Asia/Kolkata')::date-29 group by day) t),'total',(select count(*) from sc_visitors));
end $$;
grant execute on function sc_ping(text,boolean) to anon;
grant execute on function sc_report(text) to anon;
