package aristools;

import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.util.List;

/**
 * Pruebas desde Java de cada procedimiento. Se ejecuta con la base recien creada
 * (aristools_db.sql + aristools_procedimientos_extra.sql) y va mostrando OK / FALLO.
 */
public class PruebasProcedimientos {

    private static int ok = 0;
    private static int fallos = 0;

    public static void main(String[] args) throws Exception {
        try (Connection cn = ConexionBD.obtenerConexion()) {
            MovimientoDAO dao = new MovimientoDAO(cn);

            // PJ-01 conexion
            verificar("PJ-01 Conexion a la base de datos", !cn.isClosed(), "conexion abierta");

            // PJ-02 INSERTAR (movimiento inmediato): entrada de 20 guantes (PRD-006), usuario 3
            int stockAntes = stock(cn, 6, 1);
            int idEntrada = dao.registrarMovimiento(6, 1, null, 1, 1, 3, 20,
                    "Compra", "FAC-J001", "Prueba desde Java");
            verificar("PJ-02 registrar entrada (INSERTAR + parametro OUT)",
                    idEntrada > 0 && estado(cn, idEntrada).equals("Autorizado")
                            && stock(cn, 6, 1) == stockAntes + 20,
                    "id OUT=" + idEntrada + ", estado=" + estado(cn, idEntrada)
                            + ", stock " + stockAntes + " -> " + stock(cn, 6, 1));

            // PJ-03 INSERTAR (queda pendiente): transferencia de 5 destornilladores (PRD-002)
            int origenAntes = stock(cn, 2, 1);
            int idTransf = dao.registrarMovimiento(2, 3, 1, 2, null, 3, 5,
                    "Reposicion", "TR-J001", "Prueba desde Java");
            verificar("PJ-03 registrar transferencia (queda Pendiente, stock igual)",
                    estado(cn, idTransf).equals("Pendiente") && stock(cn, 2, 1) == origenAntes,
                    "id OUT=" + idTransf + ", estado=" + estado(cn, idTransf)
                            + ", stock origen=" + stock(cn, 2, 1));

            // PJ-04 ACTUALIZAR: autorizar con el Jefe de Bodega (usuario 2)
            dao.autorizarMovimiento(idTransf, 2);
            verificar("PJ-04 autorizar movimiento (ACTUALIZAR)",
                    estado(cn, idTransf).equals("Autorizado") && stock(cn, 2, 1) == origenAntes - 5,
                    "estado=" + estado(cn, idTransf) + ", stock origen " + origenAntes
                            + " -> " + stock(cn, 2, 1));

            // PJ-05 ACTUALIZAR: rechazar con motivo
            int idRech = dao.registrarMovimiento(4, 3, 1, 2, null, 3, 10,
                    "Reposicion", "TR-J002", "Prueba desde Java");
            int stockRech = stock(cn, 4, 1);
            dao.rechazarMovimiento(idRech, 2, "La cantidad no coincide con el pedido");
            verificar("PJ-05 rechazar movimiento con motivo (ACTUALIZAR)",
                    estado(cn, idRech).equals("Rechazado") && stock(cn, 4, 1) == stockRech,
                    "estado=" + estado(cn, idRech) + ", stock sin cambio=" + stock(cn, 4, 1));

            // PJ-06 CONSULTAR: kardex del producto 2
            List<FilaKardex> kardex = dao.consultarKardex(2);
            System.out.println("      Kardex PRD-002 (" + kardex.size() + " filas):");
            kardex.forEach(f -> System.out.println("        " + f));
            verificar("PJ-06 consultar kardex (CONSULTAR, ResultSet)",
                    kardex.size() >= 3 && kardex.stream().anyMatch(f -> f.idMovimiento == idTransf),
                    kardex.size() + " filas e incluye el movimiento " + idTransf);

            // PJ-07 BORRAR (inactivar): producto 5
            dao.inactivarProducto(5);
            verificar("PJ-07 inactivar producto (BORRAR logico)",
                    estadoProducto(cn, 5).equals("Inactivo"), "estado producto 5 = " + estadoProducto(cn, 5));

            // Casos de error: los SIGNAL llegan como SQLException
            esperarError("PJ-08 error: autorizar con el mismo usuario que registro",
                    () -> {
                        int id = dao.registrarMovimiento(1, 3, 1, 2, null, 3, 1, "x", "x", "x");
                        dao.autorizarMovimiento(id, 3);
                    }, "Quien registra el movimiento no puede autorizarlo");
            esperarError("PJ-09 error: salida mayor al stock",
                    () -> dao.registrarMovimiento(3, 2, 1, null, null, 3, 1000, "x", "x", "x"),
                    "Stock insuficiente en la bodega de origen");
            esperarError("PJ-10 error: rechazar sin motivo",
                    () -> dao.rechazarMovimiento(idTransf, 2, ""),
                    "Debe indicar el motivo del rechazo");
            esperarError("PJ-11 error: registrar sobre un producto inactivo",
                    () -> dao.registrarMovimiento(5, 1, null, 1, 1, 3, 1, "x", "x", "x"),
                    "El producto no existe o esta inactivo");
        }
        System.out.println();
        System.out.println("Resultado: " + ok + " pruebas OK, " + fallos + " con FALLO");
        System.exit(fallos == 0 ? 0 : 1);
    }

    // ---------- utilidades de prueba ----------

    private interface Accion {
        void ejecutar() throws SQLException;
    }

    private static void esperarError(String nombre, Accion accion, String mensajeEsperado) {
        try {
            accion.ejecutar();
            verificar(nombre, false, "no lanzo ninguna excepcion");
        } catch (SQLException e) {
            boolean bien = e.getMessage().contains(mensajeEsperado)
                    && "45000".equals(e.getSQLState()) && e.getErrorCode() == 1644;
            verificar(nombre, bien, "SQLState=" + e.getSQLState() + ", codigo=" + e.getErrorCode()
                    + ", mensaje=\"" + e.getMessage() + "\"");
        }
    }

    private static void verificar(String nombre, boolean condicion, String detalle) {
        if (condicion) {
            ok++;
        } else {
            fallos++;
        }
        System.out.println((condicion ? "[OK]    " : "[FALLO] ") + nombre);
        System.out.println("      " + detalle);
    }

    private static int stock(Connection cn, int producto, int bodega) throws SQLException {
        try (PreparedStatement ps = cn.prepareStatement(
                "SELECT COALESCE(SUM(cantidad),0) FROM existencia WHERE id_producto=? AND id_bodega=?")) {
            ps.setInt(1, producto);
            ps.setInt(2, bodega);
            try (ResultSet rs = ps.executeQuery()) {
                rs.next();
                return rs.getInt(1);
            }
        }
    }

    private static String estado(Connection cn, int idMovimiento) throws SQLException {
        try (PreparedStatement ps = cn.prepareStatement(
                "SELECT estado FROM movimiento_inventario WHERE id_movimiento=?")) {
            ps.setInt(1, idMovimiento);
            try (ResultSet rs = ps.executeQuery()) {
                return rs.next() ? rs.getString(1) : "(no existe)";
            }
        }
    }

    private static String estadoProducto(Connection cn, int idProducto) throws SQLException {
        try (PreparedStatement ps = cn.prepareStatement("SELECT estado FROM producto WHERE id_producto=?")) {
            ps.setInt(1, idProducto);
            try (ResultSet rs = ps.executeQuery()) {
                return rs.next() ? rs.getString(1) : "(no existe)";
            }
        }
    }
}
