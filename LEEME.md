# Notas FCB para iPhone

La misma app que tienes en el Mac, adaptada al teléfono y con dos diferencias grandes:

- **El grupo es configurable.** Ya no son Raúl, Nico y Papa fijos: eliges cuántos sois (hasta 8) y cómo se llama cada uno. Las medias, el ranking, la discrepancia y el «X/Y confirmadas» se ajustan solos.
- **Cada uno usa su propio móvil.** Las notas se juntan en un grupo compartido. Podéis puntuar a la vez sin pisaros: cada nota viaja por separado, con su propia marca de tiempo.

No es una app de la App Store: se instala desde Safari con «Añadir a pantalla de inicio». Queda con su icono, a pantalla completa, sin barra de navegador, y funciona sin conexión.

---

## Puesta en marcha (una sola vez)

### 1. Publicar la app

Necesitas una cuenta de GitHub (gratis). Con el repositorio ya creado en esta carpeta:

```bash
gh auth login
```

```bash
cd "/Users/raulgarciatavera/Desktop/varios/Aplicación FCB espacio Claude/notas-movil" && gh repo create notas-fcb --public --source=. --push
```

Después, en GitHub: **Settings → Pages → Source: Deploy from a branch → main / (root) → Save**.
En un par de minutos la app estará en `https://TU-USUARIO.github.io/notas-fcb/`.

> El HTML queda público, pero **no lleva ningún dato ni ninguna clave secreta**: las notas viven en el servidor del grupo y solo se entra con el código.

### 2. Crear el servidor del grupo

Es lo que permite que los móviles compartan notas. En [supabase.com](https://supabase.com) (gratis):

1. Crea un proyecto.
2. Abre **SQL Editor**, pega entero el archivo [`supabase/esquema.sql`](supabase/esquema.sql) y pulsa **Run**.
3. Para que funcione el calendario oficial, ejecuta también esto con tu token de football-data.org:

```sql
insert into public.ajustes (clave, valor)
values ('football_data_token', 'PEGA_AQUI_TU_TOKEN')
on conflict (clave) do update set valor = excluded.valor;
```

4. Ve a **Project Settings → API** y copia la **Project URL** y la clave **anon public**.
5. Pégalas en `config.js` de esta carpeta y vuelve a publicar:

```bash
cd "/Users/raulgarciatavera/Desktop/varios/Aplicación FCB espacio Claude/notas-movil" && git add -A && git commit -m "Configurar servidor del grupo" && git push
```

La clave `anon` es pública a propósito y no da acceso a nada por sí sola: las tablas están cerradas con RLS y solo se entra por funciones que exigen el código del grupo.

Si prefieres no tocar `config.js`, cada móvil puede pegar esos dos valores desde la propia app, en **Grupo → Ajustes del servidor**.

### 3. Instalarla en cada iPhone

1. Abre la dirección en **Safari** (tiene que ser Safari; Chrome en iOS no instala apps).
2. Botón de compartir → **Añadir a pantalla de inicio**.
3. Ábrela desde el icono, no desde Safari.

### 4. Formar el grupo

- En **tu** móvil: **Crear un grupo**, escribe los nombres y elige quién eres.
- Comparte el código que aparece (botón **Compartir código**).
- En los otros móviles: **Unirme con un código**, pegarlo, y cada uno elige quién es.

El código tiene la forma `ABCD1234-XXXXXXXXXXXX`. Quien lo tenga entra al grupo, así que se comparte como se comparte una contraseña.

---

## Cómo se guarda

No hay botón de guardar, y no hace falta:

1. Cada cambio se escribe **al instante** en la memoria del teléfono. Incluso la nota que estás escribiendo, sin salir del campo.
2. Menos de un segundo después se envía al grupo.
3. Al cerrar la app o cambiar a otra, se fuerza el envío de lo que quede pendiente.
4. Al volver a abrirla, se trae lo que hayan puesto los demás y se mezcla.

Sin cobertura sigue funcionando igual: se guarda en el teléfono y se envía cuando vuelva la conexión. El indicador de arriba dice en qué estado está («Al día», «Sincronizando…», «Sin conexión», «Solo este móvil»).

**Qué pasa si dos puntuáis a la vez:** cada nota es independiente, así que las dos se conservan. Si dos personas corrigen *la misma* nota, gana la última. La alineación es compartida y ahí también manda el último cambio.

---

## Actualizar la app más adelante

Al cambiar `index.html`, sube el número de versión en `sw.js`:

```js
const VERSION = 'notas-fcb-v2';
```

y publica. Los móviles se actualizan solos al abrirla con conexión.

---

## Lo que cambia respecto a la app del Mac

| | Mac | iPhone |
| --- | --- | --- |
| Quiénes puntúan | Raúl, Nico y Papa fijos | los que quieras, con sus nombres |
| Dónde viven los datos | un JSON en Application Support | memoria del teléfono + grupo compartido |
| Identidad | se pregunta al entrar a editar | se elige una vez por móvil |
| Calendario y autorrelleno | consulta directa desde la app | sale por el servidor del grupo |
| Copia de seguridad | archivo en disco | compartir/copiar el JSON desde ⛊ Seguridad |

---

## Detalles que conviene saber

- **Los datos del móvil son del móvil.** Si borras la app de la pantalla de inicio, iOS puede borrar lo guardado en ese teléfono. Como todo está también en el grupo, se recupera al volver a entrar con el código. Si usas la app **sin grupo**, haz copia de vez en cuando desde ⛊ Seguridad.
- **Tiene que ser Safari** para instalarla. Una vez instalada da igual.
- **El calendario oficial necesita grupo**, porque la consulta sale por el servidor.
