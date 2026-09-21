-- ============================================================
--  Notas FCB · calendario oficial (opcional)
--  Ejecuta esto DESPUÉS de esquema.sql, en SQL Editor → Run.
--
--  Sirve para que el móvil pueda ver los próximos partidos y
--  autorrellenar alineaciones. Sin esto la app funciona igual,
--  solo que los partidos se añaden a mano.
--
--  Si diera error porque la extensión http no está disponible,
--  no pasa nada: el resto de la app no se ve afectado.
-- ============================================================

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

grant execute on function public.fd_get(text, text, text) to anon, authenticated;

-- Y por último, guarda tu token de football-data.org:
--   insert into public.ajustes (clave, valor)
--   values ('football_data_token', 'PEGA_AQUI_TU_TOKEN')
--   on conflict (clave) do update set valor = excluded.valor;
