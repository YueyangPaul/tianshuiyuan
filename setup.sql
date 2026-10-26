-- 甜水园小饭桌：在 Supabase 的 SQL Editor 里整段粘贴运行一次即可。

-- 1) 所有数据放在一张表里：col 是类别（菜品 / 每期菜单 / 点单 / 成品照片），data 是内容
create table if not exists public.docs (
  col text not null check (col in ('dishes', 'menus', 'orders', 'photos', 'bookings', 'slots')),
  id text not null,
  data jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now(),
  primary key (col, id)
);
create index if not exists docs_updated_at_idx on public.docs (updated_at);

create or replace function public.touch_docs() returns trigger
language plpgsql as $$
begin
  new.updated_at := clock_timestamp();
  return new;
end $$;
drop trigger if exists docs_touch on public.docs;
create trigger docs_touch before insert or update on public.docs
for each row execute function public.touch_docs();

-- 2) 主人 = 这个项目里最早创建的那个登录账号（你在 Authentication → Users 里加的第一个用户）
create or replace function public.is_host() returns boolean
language sql stable security definer set search_path = public, auth as $$
  select auth.uid() is not null
     and auth.uid() = (select id from auth.users order by created_at asc limit 1)
$$;

-- 3) 权限：所有人能看；朋友只能提交点单和预约；菜单、菜品、照片、档期只有主人能改
alter table public.docs enable row level security;
drop policy if exists "everyone reads" on public.docs;
drop policy if exists "guests add orders" on public.docs;
drop policy if exists "guests edit orders" on public.docs;
drop policy if exists "host deletes" on public.docs;
create policy "everyone reads" on public.docs for select using (true);
create policy "guests add orders" on public.docs for insert
  with check (col in ('orders', 'bookings') or public.is_host());
create policy "guests edit orders" on public.docs for update
  using (col in ('orders', 'bookings') or public.is_host())
  with check (col in ('orders', 'bookings') or public.is_host());
create policy "host deletes" on public.docs for delete using (public.is_host());

-- 4) 打开实时推送，朋友一提交主人页面马上能看到
do $$ begin
  alter publication supabase_realtime add table public.docs;
exception when duplicate_object then null; end $$;

-- 5) 几道示例菜，可以在主人后台的菜单库里改掉或删掉
insert into public.docs (col, id, data) values
 ('dishes', 'dz1', '{"name":"凉拌木耳","cat":"凉菜","desc":"老陈醋加小米辣，脆爽开胃","active":true,"img":"","createdAt":1,"aiPrompt":"cold wood ear mushroom salad with black vinegar, red chili and garlic"}'),
 ('dishes', 'dz2', '{"name":"口水鸡","cat":"凉菜","desc":"川味红油，花椒香重","active":true,"img":"","createdAt":2,"aiPrompt":"Sichuan mouth-watering chicken, sliced poached chicken in red chili oil with sesame and peanuts"}'),
 ('dishes', 'dz3', '{"name":"红烧肉","cat":"热菜","desc":"冰糖炒色，肥而不腻","active":true,"img":"","createdAt":3,"aiPrompt":"red braised pork belly cubes with glossy caramelized soy glaze"}'),
 ('dishes', 'dz4', '{"name":"番茄炒蛋","cat":"热菜","desc":"番茄多汁，偏甜口","active":true,"img":"","createdAt":4,"aiPrompt":"stir-fried tomato and scrambled eggs, juicy and bright"}'),
 ('dishes', 'dz5', '{"name":"清蒸鲈鱼","cat":"热菜","desc":"葱丝豉油，鲜嫩","active":true,"img":"","createdAt":5,"aiPrompt":"steamed whole sea bass topped with scallion shreds and soy sauce"}'),
 ('dishes', 'dz7', '{"name":"玉米排骨汤","cat":"汤羹","desc":"慢炖两小时，清甜","active":true,"img":"","createdAt":6,"aiPrompt":"clear pork rib soup with corn chunks and carrot in a ceramic pot"}'),
 ('dishes', 'dz9', '{"name":"杨枝甘露","cat":"甜品","desc":"芒果西柚，冰的","active":true,"img":"","createdAt":7,"aiPrompt":"mango pomelo sago dessert in a glass bowl"}')
on conflict (col, id) do nothing;

-- 回收站：任何一行被软删除（data 变成 {_deleted:true}）之前，先把原来的内容存一份，误删可以找回
create table if not exists public.docs_trash (
  col text not null, id text not null, data jsonb, deleted_at timestamptz not null default now()
);
alter table public.docs_trash enable row level security;   -- 不开放给网页读写，只能用后台/service_role 恢复
create or replace function public.docs_keep_trash() returns trigger language plpgsql security definer set search_path = public as $$
begin
  if coalesce((new.data->>'_deleted')::boolean, false) and not coalesce((old.data->>'_deleted')::boolean, false) then
    insert into public.docs_trash(col, id, data) values (old.col, old.id, old.data);
  end if;
  return new;
end $$;
drop trigger if exists docs_keep_trash on public.docs;
create trigger docs_keep_trash before update on public.docs for each row execute function public.docs_keep_trash();

-- 照片放 Storage：公开 bucket "img"，任何人可读，只有主人能传/改/删；表里存 "sb:<路径>"
insert into storage.buckets (id, name, public) values ('img', 'img', true) on conflict (id) do update set public = true;
drop policy if exists "img host select" on storage.objects;
drop policy if exists "img host insert" on storage.objects;
drop policy if exists "img host update" on storage.objects;
drop policy if exists "img host delete" on storage.objects;
-- 覆盖上传和删除也需要 select 权限
create policy "img host select" on storage.objects for select to authenticated using (bucket_id = 'img' and public.is_host());
create policy "img host insert" on storage.objects for insert to authenticated with check (bucket_id = 'img' and public.is_host());
create policy "img host update" on storage.objects for update to authenticated using (bucket_id = 'img' and public.is_host());
create policy "img host delete" on storage.objects for delete to authenticated using (bucket_id = 'img' and public.is_host());

-- 约饭（2026-10-26 加）：已经建过表的项目跑这段，放开 bookings / slots 两个类别，朋友可以提交预约
alter table public.docs drop constraint if exists docs_col_check;
alter table public.docs add constraint docs_col_check check (col in ('dishes', 'menus', 'orders', 'photos', 'bookings', 'slots'));
drop policy if exists "guests add orders" on public.docs;
drop policy if exists "guests edit orders" on public.docs;
create policy "guests add orders" on public.docs for insert
  with check (col in ('orders', 'bookings') or public.is_host());
create policy "guests edit orders" on public.docs for update
  using (col in ('orders', 'bookings') or public.is_host())
  with check (col in ('orders', 'bookings') or public.is_host());
