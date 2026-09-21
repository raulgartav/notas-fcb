-- ============================================================
--  Notas FCB · servidor del grupo
--  Pega este archivo entero en Supabase → SQL Editor → Run.
--  Se puede volver a ejecutar sin romper nada.
-- ============================================================

create extension if not exists pgcrypto with schema extensions;

-- ---------- Datos ----------
create table if not exists public.salas (
  codigo      text primary key,
  nombre      text,
  clave_hash  text not null,
  doc         jsonb,
  rev         bigint not null default 0,
  creada      timestamptz not null default now(),
  actualizado timestamptz not null default now()
);

-- Nadie entra por la puerta de la tabla: solo por las funciones de abajo,
-- y esas exigen el código del grupo y su clave.
alter table public.salas enable row level security;
revoke all on table public.salas from anon, authenticated;

create table if not exists public.ajustes (
  clave text primary key,
  valor text
);
alter table public.ajustes enable row level security;
revoke all on table public.ajustes from anon, authenticated;

-- ---------- Utilidades ----------
create or replace function public.hash_clave(p_clave text)
returns text language sql immutable security definer set search_path = public, extensions as $$
  select encode(extensions.digest(coalesce(p_clave,''), 'sha256'), 'hex');
$$;

create or replace function public.codigo_libre()
returns text language plpgsql security definer set search_path = public, extensions as $$
declare alfabeto text := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; intento text; i int;
begin
  loop
    intento := '';
    for i in 1..8 loop
      intento := intento || substr(alfabeto, 1 + floor(random() * length(alfabeto))::int, 1);
    end loop;
    exit when not exists (select 1 from public.salas where codigo = intento);
  end loop;
  return intento;
end $$;

-- ---------- Crear grupo ----------
create or replace function public.sala_crear(p_nombre text default null)
returns jsonb language plpgsql security definer set search_path = public, extensions as $$
declare v_codigo text; v_clave text; alfabeto text := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; i int;
begin
  v_codigo := public.codigo_libre();
  v_clave := '';
  for i in 1..12 loop
    v_clave := v_clave || substr(alfabeto, 1 + floor(random() * length(alfabeto))::int, 1);
  end loop;
  insert into public.salas (codigo, nombre, clave_hash, doc, rev)
  values (v_codigo, nullif(trim(coalesce(p_nombre,'')),''), public.hash_clave(v_clave), null, 0);
  return jsonb_build_object('codigo', v_codigo, 'clave', v_clave);
end $$;

-- ---------- Leer ----------
create or replace function public.sala_leer(p_codigo text, p_clave text)
returns jsonb language plpgsql security definer set search_path = public, extensions as $$
declare s public.salas%rowtype;
begin
  select * into s from public.salas
   where codigo = upper(trim(p_codigo)) and clave_hash = public.hash_clave(upper(trim(p_clave)));
  if not found then return null; end if;
  return jsonb_build_object('nombre', s.nombre, 'doc', s.doc, 'rev', s.rev, 'actualizado', s.actualizado);
end $$;

-- ---------- Guardar (con control de versión) ----------
create or replace function public.sala_guardar(p_codigo text, p_clave text, p_doc jsonb, p_rev bigint default null)
returns jsonb language plpgsql security definer set search_path = public, extensions as $$
declare s public.salas%rowtype; v_rev bigint;
begin
  select * into s from public.salas
   where codigo = upper(trim(p_codigo)) and clave_hash = public.hash_clave(upper(trim(p_clave)))
   for update;
  if not found then
    raise exception 'Código de grupo incorrecto' using errcode = '42501';
  end if;

  -- El móvil no sabía en qué versión estaba, o venía de una anterior:
  -- le devolvemos la actual para que fusione y lo vuelva a intentar.
  if (p_rev is not null and p_rev <> s.rev)
     or (p_rev is null and s.doc is not null and s.doc ? 'matches') then
    return jsonb_build_object('ok', false, 'rev', s.rev, 'doc', s.doc);
  end if;

  update public.salas
     set doc = p_doc, rev = s.rev + 1, actualizado = now()
   where codigo = s.codigo
  returning rev into v_rev;

  return jsonb_build_object('ok', true, 'rev', v_rev);
end $$;

-- ---------- Calendario oficial ----------
-- El móvil no puede llamar a football-data.org (lo bloquea por CORS) y además
-- la clave no debe viajar dentro del HTML: la consulta sale de aquí.
-- Guarda tu token con:
--   insert into public.ajustes (clave, valor) values ('football_data_token', 'TU_TOKEN')
--   on conflict (clave) do update set valor = excluded.valor;
create extension if not exists http with schema extensions;

create or replace function public.fd_get(p_codigo text, p_clave text, p_ruta text)
returns jsonb language plpgsql security definer set search_path = public, extensions as $$
declare s public.salas%rowtype; v_token text; r extensions.http_response;
begin
  select * into s from public.salas
   where codigo = upper(trim(p_codigo)) and clave_hash = public.hash_clave(upper(trim(p_clave)));
  if not found then
    raise exception 'Código de grupo incorrecto' using errcode = '42501';
  end if;
  if p_ruta is null or left(p_ruta, 1) <> '/' then
    raise exception 'Ruta no permitida' using errcode = '22023';
  end if;

  select valor into v_token from public.ajustes where clave = 'football_data_token';
  if v_token is null or v_token = '' then
    return jsonb_build_object('status', 401, 'body', '{"message":"Falta el token de football-data.org en la tabla ajustes"}');
  end if;

  select * into r from extensions.http((
    'GET',
    'https://api.football-data.org/v4' || p_ruta,
    array[extensions.http_header('X-Auth-Token', v_token)],
    null,
    null
  )::extensions.http_request);

  return jsonb_build_object('status', r.status, 'body', r.content);
end $$;

-- ---------- Permisos ----------
revoke all on function public.hash_clave(text) from public, anon, authenticated;
revoke all on function public.codigo_libre() from public, anon, authenticated;

grant execute on function public.sala_crear(text)                            to anon, authenticated;
grant execute on function public.sala_leer(text, text)                       to anon, authenticated;
grant execute on function public.sala_guardar(text, text, jsonb, bigint)     to anon, authenticated;
grant execute on function public.fd_get(text, text, text)                    to anon, authenticated;
