-- ═══════════════════════════════════════════════════════════════
-- 17_planes_y_limites.sql
-- Sistema de planes y límites de alumnos
-- Ejecutar en Supabase → SQL Editor → Run
-- ═══════════════════════════════════════════════════════════════

-- 1. Agregar columnas de plan a profiles
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS plan_tipo text DEFAULT 'free',
  ADD COLUMN IF NOT EXISTS plan_alumnos_max integer DEFAULT 0,
  ADD COLUMN IF NOT EXISTS plan_vencimiento timestamptz DEFAULT NULL,
  ADD COLUMN IF NOT EXISTS plan_notas text DEFAULT '';

-- 2. Valores por defecto según rol
--    independiente → plan 'independiente', sin alumnos
--    profesor      → plan 'entrenador', 10 alumnos
--    admin         → plan 'pro', ilimitado (-1)

-- 3. Actualizar el admin (vos) a Pro ilimitado
UPDATE public.profiles
SET plan = 'pro',
    plan_tipo = 'pro',
    plan_alumnos_max = -1  -- -1 = ilimitado
WHERE email = 'iguerabide07@gmail.com';

-- 4. Todos los profesores existentes quedan en entrenador (10 alumnos)
UPDATE public.profiles
SET plan_tipo = 'entrenador',
    plan_alumnos_max = 10
WHERE rol = 'profesor'
  AND email != 'iguerabide07@gmail.com';

-- 5. Todos los independientes existentes
UPDATE public.profiles
SET plan_tipo = 'independiente',
    plan_alumnos_max = 0
WHERE rol = 'independiente';

-- 6. Función que devuelve el límite de alumnos del usuario actual
CREATE OR REPLACE FUNCTION public.get_plan_alumnos_max()
RETURNS integer
LANGUAGE sql
SECURITY DEFINER
STABLE
AS $$
  SELECT plan_alumnos_max FROM public.profiles WHERE id = auth.uid();
$$;

-- 7. Función para contar alumnos activos del profesor actual
CREATE OR REPLACE FUNCTION public.contar_alumnos_activos()
RETURNS integer
LANGUAGE sql
SECURITY DEFINER
STABLE
AS $$
  SELECT COUNT(*)::integer
  FROM public.alumnos
  WHERE profesor_id = auth.uid()
    AND (extra->>'estado' IS NULL OR extra->>'estado' != 'eliminado');
$$;

-- 8. Vista útil para el admin: ver todos los profesores con su uso
CREATE OR REPLACE VIEW public.admin_uso_planes AS
SELECT
  p.id,
  p.nombre,
  p.email,
  p.rol,
  p.plan_tipo,
  p.plan_alumnos_max,
  p.plan_vencimiento,
  COUNT(a.id)::integer AS alumnos_actuales
FROM public.profiles p
LEFT JOIN public.alumnos a ON a.profesor_id = p.id
WHERE p.rol IN ('profesor', 'independiente')
GROUP BY p.id, p.nombre, p.email, p.rol, p.plan_tipo, p.plan_alumnos_max, p.plan_vencimiento
ORDER BY alumnos_actuales DESC;

-- ═══════════════════════════════════════════════════════════════
-- PARA ACTIVAR UN PLAN MANUALMENTE (cuando alguien contrata):
-- ═══════════════════════════════════════════════════════════════
-- Plan Independiente:
--   UPDATE public.profiles SET plan='independiente', plan_tipo='independiente', plan_alumnos_max=0 WHERE email='profesor@email.com';
--
-- Plan Entrenador (10 alumnos):
--   UPDATE public.profiles SET plan='entrenador', plan_tipo='entrenador', plan_alumnos_max=10 WHERE email='profesor@email.com';
--
-- Plan Entrenador + 3 alumnos extra (13 total):
--   UPDATE public.profiles SET plan='entrenador', plan_tipo='entrenador', plan_alumnos_max=13 WHERE email='profesor@email.com';
--
-- Plan Pro (ilimitado):
--   UPDATE public.profiles SET plan='pro', plan_tipo='pro', plan_alumnos_max=-1 WHERE email='profesor@email.com';
-- ═══════════════════════════════════════════════════════════════
