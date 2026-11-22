package aristools;

import java.sql.Timestamp;

/** Una fila del kardex de un producto (resultado de sp_kardex_producto). */
public class FilaKardex {
    public final int idMovimiento;
    public final Timestamp fecha;
    public final String tipoMovimiento;
    public final String estado;
    public final int cantidad;
    public final String bodegaOrigen;
    public final String bodegaDestino;
    public final String registradoPor;

    public FilaKardex(int idMovimiento, Timestamp fecha, String tipoMovimiento, String estado,
                      int cantidad, String bodegaOrigen, String bodegaDestino, String registradoPor) {
        this.idMovimiento = idMovimiento;
        this.fecha = fecha;
        this.tipoMovimiento = tipoMovimiento;
        this.estado = estado;
        this.cantidad = cantidad;
        this.bodegaOrigen = bodegaOrigen;
        this.bodegaDestino = bodegaDestino;
        this.registradoPor = registradoPor;
    }

    @Override
    public String toString() {
        return String.format("#%d | %s | %s | %s | %d | %s -> %s | %s",
                idMovimiento, fecha, tipoMovimiento, estado, cantidad,
                bodegaOrigen == null ? "-" : bodegaOrigen,
                bodegaDestino == null ? "-" : bodegaDestino, registradoPor);
    }
}
