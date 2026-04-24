-- RESERVIVES migration: roles + token cap

ALTER TYPE rol_usuario ADD VALUE IF NOT EXISTS 'CAFETERIA';
ALTER TYPE rol_usuario ADD VALUE IF NOT EXISTS 'JEFE_ESTUDIOS';
ALTER TYPE rol_usuario ADD VALUE IF NOT EXISTS 'SECRETARIA';
ALTER TYPE rol_usuario ADD VALUE IF NOT EXISTS 'PROFESOR_SERVICIO';

UPDATE usuarios
SET tokens = LEAST(100, GREATEST(tokens, 0))
WHERE tokens < 0 OR tokens > 100;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = 'chk_tokens_range'
          AND conrelid = 'usuarios'::regclass
    ) THEN
        ALTER TABLE usuarios
            ADD CONSTRAINT chk_tokens_range CHECK (tokens >= 0 AND tokens <= 100);
    END IF;
END$$;
