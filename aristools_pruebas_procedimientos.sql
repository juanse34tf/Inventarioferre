/* =====================================================================
   PRUEBAS UNITARIAS Y DE INTEGRACION - PROCEDIMIENTOS ALMACENADOS
   Proyecto Integrador Aristools

   Como ejecutarlo:
   1. Crear la base desde cero con aristools_db.sql
   2. Ejecutar ESTE script completo (en MySQL Workbench activar
      "Continue SQL script execution after errors" o usar mysql --force),
      porque varias pruebas provocan errores A PROPOSITO.
   3. Las pruebas van en orden: cada una parte del estado que dejo la anterior.

   Datos de partida (los deja aristools_db.sql):
   - Usuarios: 1 = Administrador, 2 = Jefe de Bodega, 3 = Auxiliar
   - Tipos:    1 = Entrada, 2 = Salida (sin autorizacion)
               3 = Transferencia (autoriza rol 2), 4 = Ajuste (autoriza rol 1)
   - Movimiento 8 = transferencia PENDIENTE de 10 martillos (PRD-001) 1 -> 2
   ===================================================================== */

USE aristools;

SELECT '--- ESTADO INICIAL ---' AS seccion;
SELECT p.codigo, b.codigo AS bodega, e.cantidad
  FROM existencia e JOIN producto p USING (id_producto) JOIN bodega b USING (id_bodega)
 ORDER BY p.codigo, b.codigo;
SELECT id_movimiento, id_producto, id_tipo_movimiento, estado, cantidad FROM movimiento_inventario;

/* ============================ PRUEBAS UNITARIAS ============================ */

SELECT '--- PU-01 cantidad cero (esperado: error cantidad > 0) ---' AS prueba;
CALL sp_registrar_movimiento(1, 1, NULL, 1, 1, 3, 0, 'x', 'x', 'x', @id);

SELECT '--- PU-02 salida mayor al stock: PRD-003 tiene 8 en BOD-001, se piden 100 ---' AS prueba;
SET @mov_antes = (SELECT COUNT(*) FROM movimiento_inventario);
SET @stock_antes = (SELECT cantidad FROM existencia WHERE id_producto = 3 AND id_bodega = 1);
CALL sp_registrar_movimiento(3, 2, 1, NULL, NULL, 3, 100, 'Prueba', 'x', 'x', @id);
SELECT (SELECT COUNT(*) FROM movimiento_inventario) - @mov_antes AS movimientos_nuevos,
       @stock_antes AS stock_antes,
       (SELECT cantidad FROM existencia WHERE id_producto = 3 AND id_bodega = 1) AS stock_despues;

SELECT '--- PU-03 entrada con bodega de origen ---' AS prueba;
CALL sp_registrar_movimiento(1, 1, 1, 2, 1, 3, 5, 'x', 'x', 'x', @id);

SELECT '--- PU-04 salida con bodega de destino ---' AS prueba;
CALL sp_registrar_movimiento(1, 2, 1, 2, NULL, 3, 5, 'x', 'x', 'x', @id);

SELECT '--- PU-05 transferencia a la misma bodega ---' AS prueba;
CALL sp_registrar_movimiento(1, 3, 1, 1, NULL, 3, 5, 'x', 'x', 'x', @id);

SELECT '--- PU-06 ajuste con dos bodegas ---' AS prueba;
CALL sp_registrar_movimiento(1, 4, 1, 2, NULL, 3, 5, 'x', 'x', 'x', @id);

SELECT '--- PU-07 producto inexistente (id 999) ---' AS prueba;
CALL sp_registrar_movimiento(999, 1, NULL, 1, 1, 3, 5, 'x', 'x', 'x', @id);

SELECT '--- PU-08 tipo de movimiento inexistente (id 99) ---' AS prueba;
CALL sp_registrar_movimiento(1, 99, NULL, 1, 1, 3, 5, 'x', 'x', 'x', @id);

SELECT '--- PU-09 autorizar con el mismo usuario que registro (mov 8 lo registro el usuario 3) ---' AS prueba;
CALL sp_autorizar_movimiento(8, 3);

SELECT '--- PU-10 autorizar con un rol que no corresponde (Administrador sobre una transferencia) ---' AS prueba;
CALL sp_autorizar_movimiento(8, 1);

SELECT '--- PU-11 autorizar dos veces: la primera con el Jefe de Bodega, la segunda debe fallar ---' AS prueba;
CALL sp_autorizar_movimiento(8, 2);
SELECT id_movimiento, estado, id_usuario_autoriza FROM movimiento_inventario WHERE id_movimiento = 8;
CALL sp_autorizar_movimiento(8, 2);

SELECT '--- PU-12 rechazar sin motivo ---' AS prueba;
CALL sp_rechazar_movimiento(8, 2, '   ');

/* ======================== PRUEBAS DE INTEGRACION ======================== */

SELECT '--- PI-01 transferencia completa PRD-002: 5 unidades BOD-001 -> BOD-002 ---' AS prueba;
SELECT 'Antes' AS momento, b.codigo AS bodega, e.cantidad FROM existencia e JOIN bodega b USING (id_bodega) WHERE e.id_producto = 2;
CALL sp_registrar_movimiento(2, 3, 1, 2, NULL, 3, 5, 'Reposicion', 'TR-0002', 'PI-01', @pi01);
SELECT 'Tras registrar' AS momento, @pi01 AS id_mov, estado, id_usuario_autoriza FROM movimiento_inventario WHERE id_movimiento = @pi01;
SELECT 'Tras registrar' AS momento, b.codigo AS bodega, e.cantidad FROM existencia e JOIN bodega b USING (id_bodega) WHERE e.id_producto = 2;
CALL sp_autorizar_movimiento(@pi01, 2);
SELECT 'Tras autorizar' AS momento, estado, id_usuario_autoriza, fecha_autorizacion IS NOT NULL AS tiene_fecha FROM movimiento_inventario WHERE id_movimiento = @pi01;
SELECT 'Tras autorizar' AS momento, b.codigo AS bodega, e.cantidad FROM existencia e JOIN bodega b USING (id_bodega) WHERE e.id_producto = 2;
SELECT 'Kardex PRD-002' AS consulta, m.id_movimiento, m.fecha, t.nombre AS tipo, m.estado, m.cantidad,
       bo.codigo AS origen, bd.codigo AS destino
  FROM movimiento_inventario m
  JOIN tipo_movimiento t ON t.id_tipo_movimiento = m.id_tipo_movimiento
  LEFT JOIN bodega bo ON bo.id_bodega = m.id_bodega_origen
  LEFT JOIN bodega bd ON bd.id_bodega = m.id_bodega_destino
 WHERE m.id_producto = 2
 ORDER BY m.fecha, m.id_movimiento;

SELECT '--- PI-02 transferencia rechazada PRD-004: 20 unidades ---' AS prueba;
SELECT 'Antes' AS momento, b.codigo AS bodega, e.cantidad FROM existencia e JOIN bodega b USING (id_bodega) WHERE e.id_producto = 4;
CALL sp_registrar_movimiento(4, 3, 1, 2, NULL, 3, 20, 'Reposicion', 'TR-0003', 'PI-02', @pi02);
CALL sp_rechazar_movimiento(@pi02, 2, 'La cantidad no coincide con el pedido');
SELECT 'Tras rechazar' AS momento, estado, motivo_rechazo, id_usuario_autoriza FROM movimiento_inventario WHERE id_movimiento = @pi02;
SELECT 'Tras rechazar' AS momento, b.codigo AS bodega, e.cantidad FROM existencia e JOIN bodega b USING (id_bodega) WHERE e.id_producto = 4;
SELECT 'Reintento de autorizar (esperado: error)' AS paso;
CALL sp_autorizar_movimiento(@pi02, 2);

SELECT '--- PI-03 entrada +20 y salida -5 de PRD-006 y reporte de stock bajo ---' AS prueba;
SELECT 'Antes' AS momento, p.codigo, SUM(e.cantidad) AS stock, p.stock_minimo,
       IF(SUM(e.cantidad) < p.stock_minimo, 'BAJO', 'OK') AS nivel
  FROM producto p JOIN existencia e USING (id_producto) WHERE p.id_producto = 6 GROUP BY p.id_producto;
CALL sp_registrar_movimiento(6, 1, NULL, 1, 1, 3, 20, 'Compra', 'FAC-0004', 'PI-03', @pi03a);
CALL sp_registrar_movimiento(6, 2, 1, NULL, NULL, 3, 5, 'Entrega a obra', 'REM-0002', 'PI-03', @pi03b);
SELECT 'Movimientos' AS consulta, id_movimiento, id_tipo_movimiento, estado, cantidad FROM movimiento_inventario WHERE id_movimiento IN (@pi03a, @pi03b);
SELECT 'Despues' AS momento, p.codigo, SUM(e.cantidad) AS stock, p.stock_minimo,
       IF(SUM(e.cantidad) < p.stock_minimo, 'BAJO', 'OK') AS nivel
  FROM producto p JOIN existencia e USING (id_producto) WHERE p.id_producto = 6 GROUP BY p.id_producto;
SELECT 'Productos bajo el minimo ahora' AS reporte, p.codigo, SUM(e.cantidad) AS stock, p.stock_minimo
  FROM producto p JOIN existencia e USING (id_producto) GROUP BY p.id_producto HAVING SUM(e.cantidad) < p.stock_minimo;

SELECT '--- PI-04 ajuste negativo de 2 martillos (PRD-001) en BOD-001 ---' AS prueba;
SELECT 'Antes' AS momento, cantidad FROM existencia WHERE id_producto = 1 AND id_bodega = 1;
CALL sp_registrar_movimiento(1, 4, 1, NULL, NULL, 3, 2, 'Producto danado', 'AJ-0001', 'PI-04', @pi04);
SELECT 'Tras registrar' AS momento, estado FROM movimiento_inventario WHERE id_movimiento = @pi04;
SELECT 'Jefe de Bodega intenta autorizar (esperado: error de rol)' AS paso;
CALL sp_autorizar_movimiento(@pi04, 2);
CALL sp_autorizar_movimiento(@pi04, 1);
SELECT 'Despues' AS momento, m.estado, m.id_usuario_autoriza, e.cantidad AS stock
  FROM movimiento_inventario m JOIN existencia e ON e.id_producto = m.id_producto AND e.id_bodega = 1
 WHERE m.id_movimiento = @pi04;

SELECT '--- PI-05 atomicidad: dos transferencias pendientes de PRD-003 que juntas superan el stock ---' AS prueba;
SELECT 'Stock inicial BOD-001' AS momento, cantidad FROM existencia WHERE id_producto = 3 AND id_bodega = 1;
CALL sp_registrar_movimiento(3, 3, 1, 2, NULL, 3, 8, 'Reposicion', 'TR-0004', 'PI-05 A', @pi05a);
CALL sp_registrar_movimiento(3, 3, 1, 2, NULL, 3, 5, 'Reposicion', 'TR-0005', 'PI-05 B', @pi05b);
CALL sp_autorizar_movimiento(@pi05a, 2);
SELECT 'Tras autorizar A' AS momento, b.codigo AS bodega, e.cantidad FROM existencia e JOIN bodega b USING (id_bodega) WHERE e.id_producto = 3;
SELECT 'Autorizar B (esperado: stock insuficiente)' AS paso;
CALL sp_autorizar_movimiento(@pi05b, 2);
SELECT 'Tras el intento B' AS momento, estado, id_usuario_autoriza FROM movimiento_inventario WHERE id_movimiento = @pi05b;
SELECT 'Tras el intento B' AS momento, b.codigo AS bodega, e.cantidad FROM existencia e JOIN bodega b USING (id_bodega) WHERE e.id_producto = 3;

SELECT '--- PI-06 coherencia final ---' AS prueba;
SELECT COUNT(*) AS existencias_negativas FROM existencia WHERE cantidad < 0;
SELECT estado, COUNT(*) AS movimientos FROM movimiento_inventario GROUP BY estado;
-- El stock de cada producto/bodega debe ser igual a lo que suman los movimientos Autorizados
SELECT COUNT(*) AS filas_descuadradas FROM (
  SELECT e.id_producto, e.id_bodega, e.cantidad AS stock,
         COALESCE((SELECT SUM(m.cantidad) FROM movimiento_inventario m
                    WHERE m.estado = 'Autorizado' AND m.id_producto = e.id_producto AND m.id_bodega_destino = e.id_bodega), 0)
       - COALESCE((SELECT SUM(m.cantidad) FROM movimiento_inventario m
                    WHERE m.estado = 'Autorizado' AND m.id_producto = e.id_producto AND m.id_bodega_origen = e.id_bodega), 0) AS calculado
    FROM existencia e) x
 WHERE stock <> calculado;

/* ===================== PRUEBAS ADICIONALES (extra) ===================== */
SELECT '--- EX-01 movimiento inexistente al autorizar (id 9999) ---' AS prueba;
CALL sp_autorizar_movimiento(9999, 2);

SELECT '--- EX-02 observacion 1: que pasa con el parametro OUT cuando el procedimiento falla ---' AS prueba;
SET @id_out = 12345;
CALL sp_registrar_movimiento(3, 2, 1, NULL, NULL, 3, 100, 'x', 'x', 'x', @id_out);
SELECT @id_out AS valor_de_salida_tras_el_error;

SELECT '--- EX-03 observacion 2: el que registra puede rechazar su propia solicitud? ---' AS prueba;
CALL sp_registrar_movimiento(1, 4, 1, NULL, NULL, 1, 1, 'Ajuste propio', 'AJ-0002', 'EX-03', @ex03);
CALL sp_rechazar_movimiento(@ex03, 1, 'Me equivoque');
SELECT estado, id_usuario, id_usuario_autoriza, motivo_rechazo FROM movimiento_inventario WHERE id_movimiento = @ex03;
