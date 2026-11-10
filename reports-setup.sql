-- Smart Calculator: real "Report a Problem" form. Run the whole file in Supabase > SQL Editor.
create table if not exists sc_reports(id bigint generated always as identity primary key, created_at timestamptz not null default now(), name text, email text, category text, message text not null);
alter table sc_reports enable row level security;
create table if not exists sc_admin(k text primary key);
alter table sc_admin enable row level security;
create or replace function sc_submit(p_name text, p_email text, p_cat text, p_msg text) returns void language plpgsql security definer set search_path=public as $$
begin
  if p_msg is null or length(trim(p_msg))<3 or length(p_msg)>2000 then raise exception 'bad message'; end if;
  if (select count(*) from sc_reports where created_at>now()-interval '1 hour')>100 then raise exception 'busy'; end if;
  insert into sc_reports(name,email,category,message) values(left(p_name,100),left(p_email,150),left(p_cat,60),trim(p_msg));
end $$;
create or replace function sc_reports(p_pass text) returns json language plpgsql security definer set search_path=public as $$
begin
  if not exists(select 1 from sc_admin where k=p_pass) then raise exception 'wrong passcode'; end if;
  return (select coalesce(json_agg(r order by r.created_at desc),'[]'::json) from (select created_at,name,email,category,message from sc_reports order by created_at desc limit 100) r);
end $$;
grant execute on function sc_submit(text,text,text,text) to anon;
grant execute on function sc_reports(text) to anon;
-- Your secret passcode for the private admin page. Run THIS ONE LINE separately, with your own passcode:
-- insert into sc_admin(k) values ('write-your-own-secret-passcode-here');
