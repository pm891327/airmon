CREATE TABLE usuarios (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    username        VARCHAR(50) UNIQUE NOT NULL,
    email           VARCHAR(255) UNIQUE NOT NULL,
    password_hash   TEXT NOT NULL,                    
    nombre_completo VARCHAR(150),
    activo          BOOLEAN DEFAULT TRUE,
    email_verificado BOOLEAN DEFAULT FALSE,
    ultimo_login    TIMESTAMPTZ,
    created_at      TIMESTAMPTZ DEFAULT NOW(),
    updated_at      TIMESTAMPTZ DEFAULT NOW(),
    CONSTRAINT email_format CHECK (email ~* '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$'),
    CONSTRAINT username_length CHECK (char_length(username) >= 3)
);

    

CREATE INDEX idx_usuarios_email ON usuarios(email);
CREATE INDEX idx_usuarios_username ON usuarios(username);


CREATE TABLE wallets (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    usuario_id      UUID UNIQUE NOT NULL REFERENCES usuarios(id) ON DELETE CASCADE,
    saldo_cents     BIGINT NOT NULL DEFAULT 0,        
    moneda          VARCHAR(3) DEFAULT 'EUR',
    created_at      TIMESTAMPTZ DEFAULT NOW(),
    updated_at      TIMESTAMPTZ DEFAULT NOW(),
    
    CONSTRAINT saldo_no_negativo CHECK (saldo_cents >= 0)
);
CREATE INDEX idx_wallets_usuario ON wallets(usuario_id);




CREATE TYPE tipo_transaccion AS ENUM (
    'deposito',
    'retiro',
    'transferencia_entrante',
    'transferencia_saliente',
    'pago',
    'reembolso'
);

CREATE TABLE transacciones (
    id                  UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    wallet_id           UUID NOT NULL REFERENCES wallets(id) ON DELETE CASCADE,
    tipo                tipo_transaccion NOT NULL,
    cantidad_cents      BIGINT NOT NULL,              
    saldo_resultante    BIGINT NOT NULL,             
    descripcion         TEXT,
    referencia_externa  VARCHAR(100),                
    metadata            JSONB DEFAULT '{}',
    created_at          TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_transacciones_wallet ON transacciones(wallet_id);
CREATE INDEX idx_transacciones_fecha ON transacciones(created_at DESC);


CREATE OR REPLACE FUNCTION trigger_set_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER set_timestamp_usuarios
BEFORE UPDATE ON usuarios
FOR EACH ROW EXECUTE FUNCTION trigger_set_timestamp();

CREATE TRIGGER set_timestamp_wallets
BEFORE UPDATE ON wallets
FOR EACH ROW EXECUTE FUNCTION trigger_set_timestamp();


CREATE OR REPLACE FUNCTION registrar_usuario(
    p_username VARCHAR,
    p_email VARCHAR,
    p_password TEXT,
    p_nombre_completo VARCHAR DEFAULT NULL
)
RETURNS UUID AS $$
DECLARE
    v_usuario_id UUID;
BEGIN
    INSERT INTO usuarios (username, email, password_hash, nombre_completo)
    VALUES (
        p_username,
        LOWER(p_email),
        crypt(p_password, gen_salt('bf', 12)),   -- bcrypt con coste 12
        p_nombre_completo
    )
    RETURNING id INTO v_usuario_id;
    
    -- Crear wallet automáticamente
    INSERT INTO wallets (usuario_id) VALUES (v_usuario_id);
    
    RETURN v_usuario_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


CREATE OR REPLACE FUNCTION verificar_login(
    p_email VARCHAR,
    p_password TEXT
)
RETURNS TABLE(usuario_id UUID, username VARCHAR) AS $$
BEGIN
    RETURN QUERY
    SELECT u.id, u.username
    FROM usuarios u
    WHERE u.email = LOWER(p_email)
      AND u.activo = TRUE
      AND u.password_hash = crypt(p_password, u.password_hash);
      
    -- Actualizar último login si hubo match
    UPDATE usuarios
    SET ultimo_login = NOW()
    WHERE email = LOWER(p_email)
      AND password_hash = crypt(p_password, password_hash);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


CREATE OR REPLACE FUNCTION anadir_saldo(
    p_usuario_id UUID,
    p_cantidad_cents BIGINT,
    p_descripcion TEXT DEFAULT 'Depósito'
)
RETURNS BIGINT AS $$
DECLARE
    v_wallet_id UUID;
    v_nuevo_saldo BIGINT;
BEGIN
    IF p_cantidad_cents <= 0 THEN
        RAISE EXCEPTION 'La cantidad debe ser positiva';
    END IF;
    
    SELECT id INTO v_wallet_id FROM wallets WHERE usuario_id = p_usuario_id FOR UPDATE;
    
    IF v_wallet_id IS NULL THEN
        RAISE EXCEPTION 'Wallet no encontrada para el usuario %', p_usuario_id;
    END IF;
    
    UPDATE wallets
    SET saldo_cents = saldo_cents + p_cantidad_cents
    WHERE id = v_wallet_id
    RETURNING saldo_cents INTO v_nuevo_saldo;
    
    INSERT INTO transacciones (wallet_id, tipo, cantidad_cents, saldo_resultante, descripcion)
    VALUES (v_wallet_id, 'deposito', p_cantidad_cents, v_nuevo_saldo, p_descripcion);
    
    RETURN v_nuevo_saldo;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;







SELECT registrar_usuario('juanperez', 'juan@example.com', 'MiPassword123', 'Juan Pérez');

SELECT * FROM verificar_login('juan@example.com', 'MiPassword123');

SELECT anadir_saldo(
    (SELECT id FROM usuarios WHERE username='juanperez'),
    2550,
    'Depósito inicial'
);

SELECT 
    u.username,
    w.saldo_cents,
    (w.saldo_cents / 100.0)::NUMERIC(12,2) AS saldo_eur,
    w.moneda
FROM usuarios u
JOIN wallets w ON w.usuario_id = u.id
WHERE u.username = 'juanperez';

SELECT tipo, cantidad_cents, (cantidad_cents/100.0)::NUMERIC(10,2) AS eur, descripcion, created_at
FROM transacciones
ORDER BY created_at DESC;
