# aristools-java

Clases Java para llamar los procedimientos almacenados de Aristools con JDBC (CallableStatement).

## Antes de correrlo
1. Crear la base: ejecutar `aristools_db.sql` y luego `aristools_procedimientos_extra.sql` en MySQL.
2. Editar `src/main/resources/db.properties` con su usuario y clave de MySQL.
3. Tener el controlador MySQL Connector/J (el .jar) o dejar que Maven lo descargue.

## Con Maven
    mvn package
    java -cp target/classes:RUTA/mysql-connector-j-8.4.0.jar aristools.PruebasProcedimientos

(En Windows el separador del classpath es `;` en vez de `:`.)

## Sin Maven
    javac -encoding UTF-8 -d out src/main/java/aristools/*.java
    copy src\main\resources\db.properties out\        (en Linux/Mac: cp)
    java -cp out:RUTA/mysql-connector-j-8.4.0.jar aristools.PruebasProcedimientos

La clase de pruebas espera la base recién creada: si la corre dos veces seguidas, algunas
pruebas fallan porque PRD-005 ya quedó inactivo. Vuelva a crear la base antes de repetirla.

## Clases
- `ConexionBD`: abre la conexion con los datos de db.properties.
- `MovimientoDAO`: un metodo por procedimiento (registrar, autorizar, rechazar, kardex, inactivar producto).
- `FilaKardex`: una fila del resultado del kardex.
- `PruebasProcedimientos`: 11 pruebas con OK / FALLO.
