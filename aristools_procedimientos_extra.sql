/* =====================================================================
   PROCEDIMIENTOS ADICIONALES (para cubrir CONSULTAR y "BORRAR" desde Java)
   Ejecutar DESPUES de aristools_db.sql.
   ===================================================================== */
USE aristools;

DELIMITER $$

-- CONSULTAR: kardex (historial de movimientos) de un producto
CREATE PROCEDURE sp_kardex_producto (IN p_id_producto INT)
BEGIN
  SELECT m.id_movimiento,
         m.fecha,
         t.nombre AS tipo_movimiento,
         m.estado,
         m.cantidad,
         bo.codigo AS bodega_origen,
         bd.codigo AS bodega_destino,
         u.nombre_usuario AS registrado_por
    FROM movimiento_inventario m
    JOIN tipo_movimiento t ON t.id_tipo_movimiento = m.id_tipo_movimiento
    JOIN usuario u         ON u.id_usuario = m.id_usuario
    LEFT JOIN bodega bo    ON bo.id_bodega = m.id_bodega_origen
    LEFT JOIN bodega bd    ON bd.id_bodega = m.id_bodega_destino
   WHERE m.id_producto = p_id_producto
   ORDER BY m.fecha, m.id_movimiento;
END$$

-- "BORRAR": el proyecto no elimina datos con historial, se inactiva el producto
CREATE PROCEDURE sp_inactivar_producto (IN p_id_producto INT)
BEGIN
  DECLARE v_estado VARCHAR(20) DEFAULT NULL;

  SELECT estado INTO v_estado FROM producto WHERE id_producto = p_id_producto;

  IF v_estado IS NULL THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El producto no existe';
  ELSEIF v_estado = 'Inactivo' THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El producto ya esta inactivo';
  END IF;

  UPDATE producto SET estado = 'Inactivo' WHERE id_producto = p_id_producto;
END$$

DELIMITER ;
