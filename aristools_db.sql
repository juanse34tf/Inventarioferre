
SET NAMES utf8mb4;

CREATE DATABASE IF NOT EXISTS aristools
  CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE aristools;


/* 
   1. TABLAS */

CREATE TABLE rol (
  id_rol       INT          NOT NULL AUTO_INCREMENT,
  nombre_rol   VARCHAR(50)  NOT NULL,
  descripcion  VARCHAR(255) NULL,
  PRIMARY KEY (id_rol),
  UNIQUE KEY uq_rol_nombre (nombre_rol)
) ENGINE=InnoDB;

CREATE TABLE usuario (
  id_usuario         INT          NOT NULL AUTO_INCREMENT,
  nombre_completo    VARCHAR(100) NOT NULL,
  documento          VARCHAR(20)  NULL,
  correo             VARCHAR(100) NULL,
  nombre_usuario     VARCHAR(50)  NOT NULL,
  contrasena_hash    VARCHAR(255) NOT NULL,
  id_rol             INT          NOT NULL,
  estado             VARCHAR(20)  NOT NULL DEFAULT 'Activo',
  intentos_fallidos  INT          NOT NULL DEFAULT 0,
  ultimo_acceso      DATETIME     NULL,
  PRIMARY KEY (id_usuario),
  UNIQUE KEY uq_usuario_documento (documento),
  UNIQUE KEY uq_usuario_correo (correo),
  UNIQUE KEY uq_usuario_login (nombre_usuario),
  CONSTRAINT fk_usuario_rol FOREIGN KEY (id_rol) REFERENCES rol (id_rol),
  CONSTRAINT ck_usuario_estado CHECK (estado IN ('Activo','Inactivo','Bloqueado')),
  CONSTRAINT ck_usuario_intentos CHECK (intentos_fallidos >= 0)
) ENGINE=InnoDB;

CREATE TABLE categoria (
  id_categoria  INT          NOT NULL AUTO_INCREMENT,
  nombre        VARCHAR(80)  NOT NULL,
  descripcion   VARCHAR(255) NULL,
  PRIMARY KEY (id_categoria),
  UNIQUE KEY uq_categoria_nombre (nombre)
) ENGINE=InnoDB;

CREATE TABLE producto (
  id_producto      INT           NOT NULL AUTO_INCREMENT,
  codigo           VARCHAR(30)   NULL,
  nombre           VARCHAR(120)  NOT NULL,
  descripcion      VARCHAR(255)  NULL,
  id_categoria     INT           NOT NULL,
  unidad_medida    VARCHAR(20)   NOT NULL,
  costo_referencia DECIMAL(12,2) NOT NULL DEFAULT 0,
  stock_minimo     INT           NOT NULL DEFAULT 0,
  stock_maximo     INT           NOT NULL DEFAULT 0,
  estado           VARCHAR(20)   NOT NULL DEFAULT 'Activo',
  PRIMARY KEY (id_producto),
  UNIQUE KEY uq_producto_codigo (codigo),
  CONSTRAINT fk_producto_categoria FOREIGN KEY (id_categoria) REFERENCES categoria (id_categoria),
  CONSTRAINT ck_producto_estado CHECK (estado IN ('Activo','Inactivo')),
  CONSTRAINT ck_producto_costo CHECK (costo_referencia >= 0),
  CONSTRAINT ck_producto_stock CHECK (stock_minimo >= 0 AND stock_maximo >= stock_minimo)
) ENGINE=InnoDB;

CREATE TABLE bodega (
  id_bodega  INT          NOT NULL AUTO_INCREMENT,
  codigo     VARCHAR(20)  NULL,
  nombre     VARCHAR(100) NOT NULL,
  ubicacion  VARCHAR(150) NOT NULL,
  estado     VARCHAR(20)  NOT NULL DEFAULT 'Activo',
  PRIMARY KEY (id_bodega),
  UNIQUE KEY uq_bodega_codigo (codigo),
  CONSTRAINT ck_bodega_estado CHECK (estado IN ('Activo','Inactivo'))
) ENGINE=InnoDB;

CREATE TABLE proveedor (
  id_proveedor  INT          NOT NULL AUTO_INCREMENT,
  nit           VARCHAR(20)  NOT NULL,
  razon_social  VARCHAR(150) NOT NULL,
  contacto      VARCHAR(100) NULL,
  telefono      VARCHAR(20)  NULL,
  correo        VARCHAR(100) NULL,
  direccion     VARCHAR(150) NULL,
  estado        VARCHAR(20)  NOT NULL DEFAULT 'Activo',
  PRIMARY KEY (id_proveedor),
  UNIQUE KEY uq_proveedor_nit (nit),
  CONSTRAINT ck_proveedor_estado CHECK (estado IN ('Activo','Inactivo'))
) ENGINE=InnoDB;

-- Stock actual de cada producto en cada bodega.
-- Solo cambia a traves de movimientos (nunca se edita a mano).
CREATE TABLE existencia (
  id_producto  INT NOT NULL,
  id_bodega    INT NOT NULL,
  cantidad     INT NOT NULL DEFAULT 0,
  PRIMARY KEY (id_producto, id_bodega),
  CONSTRAINT fk_existencia_producto FOREIGN KEY (id_producto) REFERENCES producto (id_producto),
  CONSTRAINT fk_existencia_bodega   FOREIGN KEY (id_bodega)   REFERENCES bodega (id_bodega),
  CONSTRAINT ck_existencia_cantidad CHECK (cantidad >= 0)
) ENGINE=InnoDB;

CREATE TABLE tipo_movimiento (
  id_tipo_movimiento   INT         NOT NULL AUTO_INCREMENT,
  nombre               VARCHAR(60) NOT NULL,
  naturaleza           VARCHAR(20) NOT NULL,
  requiere_autorizacion BOOLEAN    NOT NULL DEFAULT FALSE,
  id_rol_autorizador   INT         NULL,
  PRIMARY KEY (id_tipo_movimiento),
  UNIQUE KEY uq_tipo_movimiento_nombre (nombre),
  CONSTRAINT fk_tipo_rol FOREIGN KEY (id_rol_autorizador) REFERENCES rol (id_rol),
  CONSTRAINT ck_tipo_naturaleza CHECK (naturaleza IN ('Entrada','Salida','Transferencia','Ajuste')),
  CONSTRAINT ck_tipo_autoriza CHECK (requiere_autorizacion = 0 OR id_rol_autorizador IS NOT NULL)
) ENGINE=InnoDB;

CREATE TABLE movimiento_inventario (
  id_movimiento        INT          NOT NULL AUTO_INCREMENT,
  id_producto          INT          NOT NULL,
  id_tipo_movimiento   INT          NOT NULL,
  id_bodega_origen     INT          NULL,
  id_bodega_destino    INT          NULL,
  id_proveedor         INT          NULL,
  id_usuario           INT          NOT NULL,
  estado               VARCHAR(20)  NOT NULL DEFAULT 'Pendiente',
  id_usuario_autoriza  INT          NULL,
  fecha_autorizacion   DATETIME     NULL,
  motivo_rechazo       VARCHAR(255) NULL,
  documento_soporte    VARCHAR(100) NULL,
  motivo               VARCHAR(255) NULL,
  cantidad             INT          NOT NULL,
  fecha                DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  observacion          VARCHAR(255) NULL,
  PRIMARY KEY (id_movimiento),
  KEY idx_mov_fecha (fecha),
  KEY idx_mov_estado (estado),
  CONSTRAINT fk_mov_producto  FOREIGN KEY (id_producto)         REFERENCES producto (id_producto),
  CONSTRAINT fk_mov_tipo      FOREIGN KEY (id_tipo_movimiento)  REFERENCES tipo_movimiento (id_tipo_movimiento),
  CONSTRAINT fk_mov_origen    FOREIGN KEY (id_bodega_origen)    REFERENCES bodega (id_bodega),
  CONSTRAINT fk_mov_destino   FOREIGN KEY (id_bodega_destino)   REFERENCES bodega (id_bodega),
  CONSTRAINT fk_mov_proveedor FOREIGN KEY (id_proveedor)        REFERENCES proveedor (id_proveedor),
  CONSTRAINT fk_mov_usuario   FOREIGN KEY (id_usuario)          REFERENCES usuario (id_usuario),
  CONSTRAINT fk_mov_autoriza  FOREIGN KEY (id_usuario_autoriza) REFERENCES usuario (id_usuario),
  CONSTRAINT ck_mov_estado    CHECK (estado IN ('Pendiente','Autorizado','Rechazado')),
  CONSTRAINT ck_mov_cantidad  CHECK (cantidad > 0),
  CONSTRAINT ck_mov_bodegas   CHECK (id_bodega_origen IS NOT NULL OR id_bodega_destino IS NOT NULL),
  CONSTRAINT ck_mov_distintas CHECK (id_bodega_origen IS NULL OR id_bodega_destino IS NULL
                                     OR id_bodega_origen <> id_bodega_destino)
) ENGINE=InnoDB;


/* =====================================================================
   2. PROCEDIMIENTOS ALMACENADOS (logica de movimientos)

   Reglas:
   - Entrada       : solo bodega destino.
   - Salida        : solo bodega origen.
   - Transferencia : origen y destino distintos.
   - Ajuste        : una sola bodega (destino suma, origen resta).
   - Si el tipo requiere autorizacion el movimiento queda 'Pendiente' y
     NO toca el stock hasta que un usuario con el rol autorizador lo
     autorice. Si no la requiere, se aplica de inmediato.
   - Quien registra un movimiento no puede autorizarlo.
   ===================================================================== */

DELIMITER $$

-- Uso interno: aplica el movimiento a la tabla existencia
CREATE PROCEDURE sp_aplicar_movimiento (IN p_id_movimiento INT)
BEGIN
  DECLARE v_producto INT;
  DECLARE v_origen   INT;
  DECLARE v_destino  INT;
  DECLARE v_cantidad INT;
  DECLARE v_stock    INT DEFAULT 0;

  SELECT id_producto, id_bodega_origen, id_bodega_destino, cantidad
    INTO v_producto, v_origen, v_destino, v_cantidad
    FROM movimiento_inventario
   WHERE id_movimiento = p_id_movimiento;

  IF v_origen IS NOT NULL THEN
    SELECT COALESCE(SUM(cantidad), 0) INTO v_stock
      FROM existencia
     WHERE id_producto = v_producto AND id_bodega = v_origen
       FOR UPDATE;

    IF v_stock < v_cantidad THEN
      SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Stock insuficiente en la bodega de origen';
    END IF;

    UPDATE existencia
       SET cantidad = cantidad - v_cantidad
     WHERE id_producto = v_producto AND id_bodega = v_origen;
  END IF;

  IF v_destino IS NOT NULL THEN
    INSERT INTO existencia (id_producto, id_bodega, cantidad)
    VALUES (v_producto, v_destino, v_cantidad)
    ON DUPLICATE KEY UPDATE cantidad = cantidad + v_cantidad;
  END IF;
END$$


CREATE PROCEDURE sp_registrar_movimiento (
  IN  p_id_producto        INT,
  IN  p_id_tipo_movimiento INT,
  IN  p_id_bodega_origen   INT,
  IN  p_id_bodega_destino  INT,
  IN  p_id_proveedor       INT,
  IN  p_id_usuario         INT,
  IN  p_cantidad           INT,
  IN  p_motivo             VARCHAR(255),
  IN  p_documento_soporte  VARCHAR(100),
  IN  p_observacion        VARCHAR(255),
  OUT p_id_movimiento      INT
)
BEGIN
  DECLARE v_naturaleza VARCHAR(20) DEFAULT NULL;
  DECLARE v_requiere   BOOLEAN     DEFAULT FALSE;
  DECLARE v_estado     VARCHAR(20);

  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN
    ROLLBACK;
    RESIGNAL;
  END;

  IF p_cantidad IS NULL OR p_cantidad <= 0 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'La cantidad debe ser mayor que cero';
  END IF;

  SELECT naturaleza, requiere_autorizacion
    INTO v_naturaleza, v_requiere
    FROM tipo_movimiento
   WHERE id_tipo_movimiento = p_id_tipo_movimiento;

  IF v_naturaleza IS NULL THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El tipo de movimiento no existe';
  END IF;

  IF NOT EXISTS (SELECT 1 FROM producto WHERE id_producto = p_id_producto AND estado = 'Activo') THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El producto no existe o esta inactivo';
  END IF;

  IF NOT EXISTS (SELECT 1 FROM usuario WHERE id_usuario = p_id_usuario AND estado = 'Activo') THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El usuario no existe o no esta activo';
  END IF;

  IF p_id_bodega_origen IS NOT NULL
     AND NOT EXISTS (SELECT 1 FROM bodega WHERE id_bodega = p_id_bodega_origen AND estado = 'Activo') THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'La bodega de origen no existe o esta inactiva';
  END IF;

  IF p_id_bodega_destino IS NOT NULL
     AND NOT EXISTS (SELECT 1 FROM bodega WHERE id_bodega = p_id_bodega_destino AND estado = 'Activo') THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'La bodega de destino no existe o esta inactiva';
  END IF;

  IF v_naturaleza = 'Entrada'
     AND (p_id_bodega_destino IS NULL OR p_id_bodega_origen IS NOT NULL) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Una entrada requiere solo bodega de destino';
  END IF;

  IF v_naturaleza = 'Salida'
     AND (p_id_bodega_origen IS NULL OR p_id_bodega_destino IS NOT NULL) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Una salida requiere solo bodega de origen';
  END IF;

  IF v_naturaleza = 'Transferencia'
     AND (p_id_bodega_origen IS NULL OR p_id_bodega_destino IS NULL
          OR p_id_bodega_origen = p_id_bodega_destino) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Una transferencia requiere bodega de origen y destino distintas';
  END IF;

  IF v_naturaleza = 'Ajuste'
     AND ((p_id_bodega_origen IS NULL AND p_id_bodega_destino IS NULL)
          OR (p_id_bodega_origen IS NOT NULL AND p_id_bodega_destino IS NOT NULL)) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Un ajuste requiere solo una bodega (destino suma, origen resta)';
  END IF;

  IF v_requiere = 1 THEN
    SET v_estado = 'Pendiente';
  ELSE
    SET v_estado = 'Autorizado';
  END IF;

  START TRANSACTION;

  INSERT INTO movimiento_inventario
    (id_producto, id_tipo_movimiento, id_bodega_origen, id_bodega_destino,
     id_proveedor, id_usuario, estado, motivo, documento_soporte, cantidad, observacion)
  VALUES
    (p_id_producto, p_id_tipo_movimiento, p_id_bodega_origen, p_id_bodega_destino,
     p_id_proveedor, p_id_usuario, v_estado, p_motivo, p_documento_soporte, p_cantidad, p_observacion);

  SET p_id_movimiento = LAST_INSERT_ID();

  IF v_estado = 'Autorizado' THEN
    CALL sp_aplicar_movimiento(p_id_movimiento);
  END IF;

  COMMIT;
END$$


CREATE PROCEDURE sp_autorizar_movimiento (
  IN p_id_movimiento       INT,
  IN p_id_usuario_autoriza INT
)
BEGIN
  DECLARE v_estado          VARCHAR(20) DEFAULT NULL;
  DECLARE v_id_registra     INT         DEFAULT NULL;
  DECLARE v_rol_autorizador INT         DEFAULT NULL;
  DECLARE v_rol_usuario     INT         DEFAULT NULL;

  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN
    ROLLBACK;
    RESIGNAL;
  END;

  START TRANSACTION;

  SELECT m.estado, m.id_usuario, t.id_rol_autorizador
    INTO v_estado, v_id_registra, v_rol_autorizador
    FROM movimiento_inventario m
    JOIN tipo_movimiento t ON t.id_tipo_movimiento = m.id_tipo_movimiento
   WHERE m.id_movimiento = p_id_movimiento
     FOR UPDATE;

  SELECT id_rol INTO v_rol_usuario
    FROM usuario
   WHERE id_usuario = p_id_usuario_autoriza AND estado = 'Activo';

  IF v_estado IS NULL THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El movimiento no existe';
  ELSEIF v_estado <> 'Pendiente' THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Solo se pueden autorizar movimientos pendientes';
  ELSEIF v_rol_usuario IS NULL THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El usuario que autoriza no existe o no esta activo';
  ELSEIF v_id_registra = p_id_usuario_autoriza THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Quien registra el movimiento no puede autorizarlo';
  ELSEIF v_rol_autorizador IS NOT NULL AND v_rol_usuario <> v_rol_autorizador THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El rol del usuario no puede autorizar este tipo de movimiento';
  END IF;

  CALL sp_aplicar_movimiento(p_id_movimiento);

  UPDATE movimiento_inventario
     SET estado = 'Autorizado',
         id_usuario_autoriza = p_id_usuario_autoriza,
         fecha_autorizacion = NOW()
   WHERE id_movimiento = p_id_movimiento;

  COMMIT;
END$$


CREATE PROCEDURE sp_rechazar_movimiento (
  IN p_id_movimiento       INT,
  IN p_id_usuario_autoriza INT,
  IN p_motivo_rechazo      VARCHAR(255)
)
BEGIN
  DECLARE v_estado          VARCHAR(20) DEFAULT NULL;
  DECLARE v_id_registra     INT         DEFAULT NULL;
  DECLARE v_rol_autorizador INT         DEFAULT NULL;
  DECLARE v_rol_usuario     INT         DEFAULT NULL;

  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN
    ROLLBACK;
    RESIGNAL;
  END;

  IF p_motivo_rechazo IS NULL OR TRIM(p_motivo_rechazo) = '' THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Debe indicar el motivo del rechazo';
  END IF;

  START TRANSACTION;

  SELECT m.estado, m.id_usuario, t.id_rol_autorizador
    INTO v_estado, v_id_registra, v_rol_autorizador
    FROM movimiento_inventario m
    JOIN tipo_movimiento t ON t.id_tipo_movimiento = m.id_tipo_movimiento
   WHERE m.id_movimiento = p_id_movimiento
     FOR UPDATE;

  SELECT id_rol INTO v_rol_usuario
    FROM usuario
   WHERE id_usuario = p_id_usuario_autoriza AND estado = 'Activo';

  IF v_estado IS NULL THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El movimiento no existe';
  ELSEIF v_estado <> 'Pendiente' THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Solo se pueden rechazar movimientos pendientes';
  ELSEIF v_rol_usuario IS NULL THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El usuario no existe o no esta activo';
  ELSEIF v_rol_autorizador IS NOT NULL AND v_rol_usuario <> v_rol_autorizador THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El rol del usuario no puede rechazar este tipo de movimiento';
  END IF;

  UPDATE movimiento_inventario
     SET estado = 'Rechazado',
         id_usuario_autoriza = p_id_usuario_autoriza,
         fecha_autorizacion = NOW(),
         motivo_rechazo = p_motivo_rechazo
   WHERE id_movimiento = p_id_movimiento;

  COMMIT;
END$$

DELIMITER ;


/*
   3. DATOS DE EJEMPLO */

INSERT INTO rol (nombre_rol, descripcion) VALUES
  ('Administrador',      'Acceso total al sistema'),
  ('Jefe de Bodega',     'Autoriza transferencias y gestiona bodegas'),
  ('Auxiliar de Bodega', 'Registra movimientos de inventario');

INSERT INTO usuario (nombre_completo, documento, correo, nombre_usuario, contrasena_hash, id_rol) VALUES
  ('Administrador General', '1000000001', 'admin@aristools.com',    'admin',    SHA2('Admin123*', 256), 1),
  ('Jefe de Bodega',        '1000000002', 'jefe@aristools.com',     'jefe',     SHA2('Jefe123*', 256),  2),
  ('Auxiliar de Bodega',    '1000000003', 'auxiliar@aristools.com', 'auxiliar', SHA2('Aux123*', 256),   3);

INSERT INTO categoria (nombre, descripcion) VALUES
  ('Herramientas manuales',    'Martillos, destornilladores y llaves'),
  ('Herramientas electricas',  'Taladros, pulidoras y sierras'),
  ('Tornilleria y fijaciones', 'Tornillos, tuercas y chazos'),
  ('Seguridad industrial',     'Elementos de proteccion personal');

INSERT INTO bodega (codigo, nombre, ubicacion) VALUES
  ('BOD-001', 'Bodega Principal',   'Sede Norte'),
  ('BOD-002', 'Bodega Secundaria',  'Sede Sur'),
  ('BOD-003', 'Bodega de Despachos', 'Zona Industrial');

INSERT INTO proveedor (nit, razon_social, contacto, telefono, correo, direccion) VALUES
  ('900123456-1', 'Distribuidora Ferretera S.A.S.',    'Carlos Ruiz', '3101234567', 'ventas@disferretera.com',   'Calle 10 # 5-20'),
  ('900654321-2', 'Importaciones Industriales Ltda.',  'Marta Diaz',  '3157654321', 'contacto@impindustrial.com', 'Carrera 15 # 30-45');

INSERT INTO producto (codigo, nombre, descripcion, id_categoria, unidad_medida, costo_referencia, stock_minimo, stock_maximo) VALUES
  ('PRD-001', 'Martillo de uña 16 oz',      'Martillo con mango de fibra',        1, 'Unidad', 25000.00,  10, 100),
  ('PRD-002', 'Destornillador de estria',   'Destornillador Phillips #2',         1, 'Unidad',  8000.00,  20, 150),
  ('PRD-003', 'Taladro percutor 1/2 pulgada', 'Taladro electrico de 650 W',       2, 'Unidad', 210000.00,  3,  20),
  ('PRD-004', 'Tornillo drywall 6x1',       'Caja x 100 unidades',                3, 'Caja',   12000.00,  50, 800),
  ('PRD-005', 'Casco de seguridad',         'Casco con suspension de 4 puntos',   4, 'Unidad', 18000.00,  10,  60),
  ('PRD-006', 'Guantes de carnaza',         'Par de guantes de carnaza',          4, 'Par',     9000.00,  10,  80);

INSERT INTO tipo_movimiento (nombre, naturaleza, requiere_autorizacion, id_rol_autorizador) VALUES
  ('Entrada por compra',          'Entrada',       0, NULL),
  ('Salida por consumo',          'Salida',        0, NULL),
  ('Transferencia entre bodegas', 'Transferencia', 1, 2),
  ('Ajuste de inventario',        'Ajuste',        1, 1);

-- Movimientos de ejemplo (el stock se genera con los procedimientos)
-- Parametros: producto, tipo, origen, destino, proveedor, usuario, cantidad, motivo, documento, observacion, OUT id
CALL sp_registrar_movimiento(1, 1, NULL, 1, 1, 3,  40, 'Compra inicial', 'FAC-0001', 'Inventario inicial', @id_mov);
CALL sp_registrar_movimiento(2, 1, NULL, 1, 1, 3,  60, 'Compra inicial', 'FAC-0001', 'Inventario inicial', @id_mov);
CALL sp_registrar_movimiento(3, 1, NULL, 1, 2, 3,   8, 'Compra inicial', 'FAC-0002', 'Inventario inicial', @id_mov);
CALL sp_registrar_movimiento(4, 1, NULL, 1, 2, 3, 500, 'Compra inicial', 'FAC-0002', 'Inventario inicial', @id_mov);
CALL sp_registrar_movimiento(5, 1, NULL, 2, 1, 3,  25, 'Compra inicial', 'FAC-0003', 'Inventario inicial', @id_mov);
CALL sp_registrar_movimiento(6, 1, NULL, 1, 1, 3,   3, 'Compra inicial', 'FAC-0003', 'Stock por debajo del minimo (ejemplo)', @id_mov);

-- Una salida (se aplica de inmediato) y una transferencia que queda PENDIENTE
CALL sp_registrar_movimiento(2, 2, 1,    NULL, NULL, 3, 10, 'Entrega a obra',   'REM-0001', 'Consumo de ejemplo', @id_mov);
CALL sp_registrar_movimiento(1, 3, 1,    2,    NULL, 3, 10, 'Reposicion de bodega secundaria', 'TR-0001', 'Pendiente de autorizacion', @id_mov);

-- Verificacion rapida
SELECT 'Tablas creadas y datos de ejemplo cargados' AS resultado;
SELECT p.codigo, p.nombre, b.nombre AS bodega, e.cantidad
  FROM existencia e
  JOIN producto p ON p.id_producto = e.id_producto
  JOIN bodega b   ON b.id_bodega   = e.id_bodega
 ORDER BY p.codigo, b.nombre;
