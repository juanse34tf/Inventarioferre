package aristools;

import java.sql.CallableStatement;
import java.sql.Connection;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Types;
import java.util.ArrayList;
import java.util.List;

/**
 * Llama a los procedimientos almacenados de movimientos de inventario usando
 * CallableStatement. Los errores que lanzan los procedimientos con SIGNAL
 * llegan como SQLException (SQLState 45000, codigo 1644 en MySQL); esta clase
 * no los captura, para que la capa que la use decida como mostrarlos.
 */
public class MovimientoDAO {

    private final Connection cn;

    public MovimientoDAO(Connection cn) {
        this.cn = cn;
    }

    /** INSERTAR: sp_registrar_movimiento. Devuelve el id generado (parametro OUT). */
    public int registrarMovimiento(int idProducto, int idTipoMovimiento,
                                   Integer idBodegaOrigen, Integer idBodegaDestino,
                                   Integer idProveedor, int idUsuario, int cantidad,
                                   String motivo, String documentoSoporte, String observacion)
            throws SQLException {
        String sql = "{call sp_registrar_movimiento(?,?,?,?,?,?,?,?,?,?,?)}";
        try (CallableStatement cs = cn.prepareCall(sql)) {
            cs.setInt(1, idProducto);
            cs.setInt(2, idTipoMovimiento);
            asignarEnteroONulo(cs, 3, idBodegaOrigen);
            asignarEnteroONulo(cs, 4, idBodegaDestino);
            asignarEnteroONulo(cs, 5, idProveedor);
            cs.setInt(6, idUsuario);
            cs.setInt(7, cantidad);
            cs.setString(8, motivo);
            cs.setString(9, documentoSoporte);
            cs.setString(10, observacion);
            cs.registerOutParameter(11, Types.INTEGER);
            cs.execute();
            return cs.getInt(11);
        }
    }

    /** ACTUALIZAR: sp_autorizar_movimiento. */
    public void autorizarMovimiento(int idMovimiento, int idUsuarioAutoriza) throws SQLException {
        try (CallableStatement cs = cn.prepareCall("{call sp_autorizar_movimiento(?,?)}")) {
            cs.setInt(1, idMovimiento);
            cs.setInt(2, idUsuarioAutoriza);
            cs.execute();
        }
    }

    /** ACTUALIZAR: sp_rechazar_movimiento. */
    public void rechazarMovimiento(int idMovimiento, int idUsuarioAutoriza, String motivoRechazo)
            throws SQLException {
        try (CallableStatement cs = cn.prepareCall("{call sp_rechazar_movimiento(?,?,?)}")) {
            cs.setInt(1, idMovimiento);
            cs.setInt(2, idUsuarioAutoriza);
            cs.setString(3, motivoRechazo);
            cs.execute();
        }
    }

    /** CONSULTAR: sp_kardex_producto devuelve un ResultSet. */
    public List<FilaKardex> consultarKardex(int idProducto) throws SQLException {
        List<FilaKardex> filas = new ArrayList<>();
        try (CallableStatement cs = cn.prepareCall("{call sp_kardex_producto(?)}")) {
            cs.setInt(1, idProducto);
            try (ResultSet rs = cs.executeQuery()) {
                while (rs.next()) {
                    filas.add(new FilaKardex(
                            rs.getInt("id_movimiento"),
                            rs.getTimestamp("fecha"),
                            rs.getString("tipo_movimiento"),
                            rs.getString("estado"),
                            rs.getInt("cantidad"),
                            rs.getString("bodega_origen"),
                            rs.getString("bodega_destino"),
                            rs.getString("registrado_por")));
                }
            }
        }
        return filas;
    }

    /** "BORRAR": el proyecto no elimina datos con historial, inactiva el producto. */
    public void inactivarProducto(int idProducto) throws SQLException {
        try (CallableStatement cs = cn.prepareCall("{call sp_inactivar_producto(?)}")) {
            cs.setInt(1, idProducto);
            cs.executeUpdate();
        }
    }

    private static void asignarEnteroONulo(CallableStatement cs, int pos, Integer valor) throws SQLException {
        if (valor == null) {
            cs.setNull(pos, Types.INTEGER);
        } else {
            cs.setInt(pos, valor);
        }
    }
}
