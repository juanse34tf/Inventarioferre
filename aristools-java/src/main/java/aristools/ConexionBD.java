package aristools;

import java.io.IOException;
import java.io.InputStream;
import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.SQLException;
import java.util.Properties;

/**
 * Establece la conexion con la base de datos aristools.
 * Las credenciales se leen del archivo db.properties (o de las variables de
 * entorno ARISTOOLS_DB_URL, ARISTOOLS_DB_USER y ARISTOOLS_DB_PASSWORD si existen).
 */
public class ConexionBD {

    private static final Properties CONFIG = cargarConfiguracion();

    private ConexionBD() {
    }

    private static Properties cargarConfiguracion() {
        Properties p = new Properties();
        try (InputStream in = ConexionBD.class.getResourceAsStream("/db.properties")) {
            if (in != null) {
                p.load(in);
            }
        } catch (IOException e) {
            throw new IllegalStateException("No se pudo leer db.properties", e);
        }
        return p;
    }

    private static String valor(String variableEntorno, String clave) {
        String env = System.getenv(variableEntorno);
        return env != null ? env : CONFIG.getProperty(clave, "");
    }

    /** Abre una conexion nueva. Quien la reciba debe cerrarla (try-with-resources). */
    public static Connection obtenerConexion() throws SQLException {
        return DriverManager.getConnection(
                valor("ARISTOOLS_DB_URL", "db.url"),
                valor("ARISTOOLS_DB_USER", "db.user"),
                valor("ARISTOOLS_DB_PASSWORD", "db.password"));
    }
}
