# Inventarioferre (Aristools)

> Sistema de gestión y control de inventarios para ferretería basado en procedimientos almacenados, control transaccional estricto en base de datos y consumo desacoplado mediante una capa de integración en Java con JDBC.

Proyecto desarrollado para el módulo de **Bases de Datos** en la **Institución Universitaria Antonio José Camacho (UNIAJC)**.

---

## Tabla de Contenidos
1. [Descripción del Proyecto](#descripción-del-proyecto)
2. [Arquitectura y Reglas del Negocio](#arquitectura-y-reglas-del-negocio)
3. [Requisitos del Sistema](#requisitos-del-sistema)
4. [Cómo Clonar o Descargar el Proyecto](#cómo-clonar-o-descargar-el-proyecto)
5. [Puesta en Marcha de la Base de Datos](#puesta-en-marcha-de-la-base-de-datos)
6. [Ejecución de Pruebas en MySQL](#ejecución-de-pruebas-en-mysql)
7. [Compilación y Ejecución del Módulo Java](#compilación-y-ejecución-del-módulo-java)
8. [Estructura del Repositorio](#estructura-del-repositorio)
9. [Flujo de Contribución (Open Source Standard)](#flujo-de-contribución-open-source-standard)
10. [Autor](#autor)

---

## Descripción del Proyecto

**Inventarioferre** implementa el núcleo transaccional para la gestión de productos, bodegas y movimientos de inventario de una ferretería industrial. 

A diferencia de los enfoques tradicionales donde la lógica reside enteramente en el servidor web o backend, aquí la integridad, validaciones críticas, concurrencia y auditoría están blindadas directamente en el motor de base de datos a través de **Procedimientos Almacenados (Stored Procedures)** transaccionales con aislamiento por bloqueos (`SELECT ... FOR UPDATE`), garantizando atomicidad y consistencia absoluta.

---

## Arquitectura y Reglas del Negocio

El sistema maneja las siguientes entidades clave:
- **Productos y Bodegas:** Catálogo de productos con umbrales de stock mínimo y múltiples bodegas de almacenamiento (Principal `BOD-001`, Secundaria `BOD-002`, etc.).
- **Existencias:** Registro del stock real desagregado por cada combinación `(id_producto, id_bodega)`.
- **Procedimientos Almacenados:**
  1. `sp_registrar_movimiento`: Registra entradas, salidas, transferencias y ajustes. Si el movimiento requiere validación previa, queda en estado `Pendiente`; si no, se autoriza y aplica de inmediato.
  2. `sp_autorizar_movimiento`: Valida separación de funciones (quien registra jamás puede auto-autorizar) y rol autorizado (Jefe de Bodega, Administrador), aplicando la transacción al stock mediante bloqueos pesimistas.
  3. `sp_rechazar_movimiento`: Requiere motivo obligatorio; deja trazabilidad del rechazo sin alterar existencias físicas.
  4. `sp_aplicar_movimiento`: Procedimiento de soporte interno que debita y/o acredita existencias usando `INSERT ... ON DUPLICATE KEY UPDATE` de forma atómica.
  5. `sp_kardex_producto`: Consulta histórica y cronológica de transacciones por producto.
  6. `sp_inactivar_producto`: Borrado lógico que preserva la integridad referencial histórica.

---

## Requisitos del Sistema

Antes de iniciar, asegúrate de tener instalado en tu máquina:
- **Motor de Base de Datos:** MySQL Server 8.0+ o MariaDB 10.4+ (ej. a través de XAMPP, Laragon o servicio nativo).
- **Java Development Kit:** Java JDK 17 o JDK 21 instalado y configurado en el `PATH` (`javac -version`, `java -version`).
- **Git:** Git 2.x+ instalado (`git --version`).
- **Conector JDBC:** `mysql-connector-j-8.4.0.jar` (o descarga automática vía Maven si cuentas con `mvn`).

---

## Cómo Clonar o Descargar el Proyecto

Tienes dos formas estándar de obtener el proyecto en tu entorno local:

### Opción A: Clonar usando Git (Recomendada)
Abre tu terminal (PowerShell, Git Bash o CMD) en la carpeta donde deseas ubicar el proyecto y ejecuta:

```bash
# Vía HTTPS
git clone https://github.com/juanse34tf/Inventarioferre.git

# Entrar al directorio
cd Inventarioferre
```

> **Tip:** Si tienes llaves SSH configuradas en tu cuenta de GitHub, también puedes clonarlo con:
> ```bash
> git clone git@github.com:juanse34tf/Inventarioferre.git
> ```

### Opción B: Descargar el archivo ZIP (Sin Git)
1. Ve a la página principal del repositorio en GitHub: [https://github.com/juanse34tf/Inventarioferre](https://github.com/juanse34tf/Inventarioferre).
2. Haz clic en el botón verde **Code**.
3. Selecciona **Download ZIP**.
4. Descomprime el archivo en tu carpeta preferida y abre una consola allí.

---

## Puesta en Marcha de la Base de Datos

El orden de ejecución de los scripts es fundamental para que las tablas, relaciones y procedimientos queden enlazados correctamente.

1. **Asegúrate de que tu servicio MySQL/MariaDB esté iniciado** (por ejemplo, el módulo MySQL en el panel de XAMPP en el puerto `3306`).
2. **Ejecutar los scripts en orden:**

#### Desde la consola (CLI de MySQL):
```bash
# 1. Crear la base, tablas, datos iniciales y procedimientos base
mysql -u root -p < aristools_db.sql

# 2. Registrar los procedimientos adicionales (kardex y borrado lógico)
mysql -u root -p aristools < aristools_procedimientos_extra.sql
```
*(Si tu usuario `root` no tiene contraseña, como en configuraciones por defecto de XAMPP, simplemente omite `-p`)*.

#### Desde MySQL Workbench / phpMyAdmin / DBeaver:
1. Abre y ejecuta completamente `aristools_db.sql`.
2. Selecciona la base de datos `aristools`.
3. Abre y ejecuta `aristools_procedimientos_extra.sql`.

---

## Ejecución de Pruebas en MySQL

Para certificar la integridad de los procedimientos almacenados, se diseñó una batería de 12 pruebas unitarias (`PU-01` a `PU-12`) y 6 pruebas de integración (`PI-01` a `PI-06`).

Dado que muchas pruebas inducen errores deliberadamente para verificar que los `SIGNAL SQLSTATE '45000'` capturen violaciones de negocio (ej. cantidad <= 0, stock insuficiente, auto-autorización), debes ejecutar el script con la bandera de forzar continuación:

```bash
mysql -u root --default-character-set=utf8mb4 --force -t aristools < aristools_pruebas_procedimientos.sql
```

Los resultados generados validan:
- Rechazo inmediato de cantidades no positivas y bodegas incongruentes.
- Transaccionalidad ante stock insuficiente (no descuadra existencias).
- Separación de funciones (el usuario que solicita no puede aprobar).
- Trazabilidad en Kardex y coherencia de balance general.

---

## Compilación y Ejecución del Módulo Java

El módulo Java ubicado en `aristools-java` consume los Stored Procedures mediante objetos `CallableStatement` de JDBC.

### 1. Configuración de credenciales
Edita el archivo `aristools-java/src/main/resources/db.properties` con los datos de tu motor local:

```properties
db.url=jdbc:mysql://localhost:3306/aristools?useSSL=false&allowPublicKeyRetrieval=true&serverTimezone=America/Bogota
db.user=root
db.password=
```

### 2. Compilar y correr sin Maven (CLI directo)

Asegúrate de tener el controlador `mysql-connector-j-8.4.0.jar` disponible (puedes descargarlo desde el repositorio oficial de Maven Central).

**En Windows (PowerShell / CMD):**
```powershell
# 1. Crear carpeta de salida
mkdir out -ErrorAction SilentlyContinue

# 2. Compilar clases
javac -encoding UTF-8 -d out (Get-ChildItem aristools-java/src/main/java/aristools/*.java).FullName

# 3. Copiar configuración al classpath
Copy-Item aristools-java/src/main/resources/db.properties out/ -Force

# 4. Ejecutar suite de pruebas
java -cp "out;./mysql-connector-j-8.4.0.jar" aristools.PruebasProcedimientos
```

**En Linux / macOS:**
```bash
mkdir -p out
javac -encoding UTF-8 -d out aristools-java/src/main/java/aristools/*.java
cp aristools-java/src/main/resources/db.properties out/
java -cp "out:./mysql-connector-j-8.4.0.jar" aristools.PruebasProcedimientos
```

### 3. Con Maven (Opcional)
Si tienes Apache Maven instalado:
```bash
cd aristools-java
mvn clean package
java -cp "target/classes;../mysql-connector-j-8.4.0.jar" aristools.PruebasProcedimientos
```

### Salida esperada de las 11 pruebas Java:
```text
[OK]    PJ-01 Conexion a la base de datos
[OK]    PJ-02 registrar entrada (INSERTAR + parametro OUT)
[OK]    PJ-03 registrar transferencia (queda Pendiente, stock igual)
[OK]    PJ-04 autorizar movimiento (ACTUALIZAR)
[OK]    PJ-05 rechazar movimiento con motivo (ACTUALIZAR)
[OK]    PJ-06 consultar kardex (CONSULTAR, ResultSet)
[OK]    PJ-07 inactivar producto (BORRAR logico)
[OK]    PJ-08 error: autorizar con el mismo usuario que registro
[OK]    PJ-09 error: salida mayor al stock
[OK]    PJ-10 error: rechazar sin motivo
[OK]    PJ-11 error: registrar sobre un producto inactivo

Resultado: 11 pruebas OK, 0 con FALLO
```

---

## Estructura del Repositorio

```text
Inventarioferre/
├── .gitignore                                      # Filtro de binarios, temporales y librerías
├── README.md                                       # Documentación general del proyecto
├── Desarrollo_Procedimientos_Almacenados_APA.docx   # Informe técnico y sustentación académica
├── aristools_db.sql                                # DDL, DML y procedimientos base
├── aristools_procedimientos_extra.sql              # Procedimientos de consulta y borrado lógico
├── aristools_pruebas_procedimientos.sql            # Suite completa de pruebas SQL (PU y PI)
├── resultados_pruebas_1.txt                        # Log de referencia de pruebas en BD
├── resultados_java_1.txt                           # Log de referencia de pruebas Java
└── aristools-java/                                 # Módulo de integración Java JDBC
    ├── pom.xml                                     # Descriptor Maven
    ├── README.md                                   # Guía específica del cliente Java
    └── src/
        └── main/
            ├── java/aristools/
            │   ├── ConexionBD.java                 # Gestor de conexiones con db.properties
            │   ├── FilaKardex.java                 # DTO para mapeo de resultados del kardex
            │   ├── MovimientoDAO.java              # Métodos JDBC para llamar a cada SP
            │   └── PruebasProcedimientos.java      # Ejecutor de las 11 pruebas automatizadas
            └── resources/
                └── db.properties                   # Parámetros de conexión a la BD
```

---

## Flujo de Contribución (Open Source Standard)

Si deseas colaborar, sugerir mejoras o extender la funcionalidad, sigue el estándar habitual de GitHub:

1. **Fork del Repositorio:** Haz clic en el botón **Fork** arriba a la derecha para tener tu propia copia.
2. **Crea una Rama de Funcionalidad:**
   ```bash
   git checkout -b feature/nueva-funcionalidad
   ```
3. **Realiza tus Cambios:** Sigue las convenciones de código y documenta tus commits con mensajes claros:
   ```bash
   git commit -m "feat: agrega procedimiento para reporte de inventario valorizado"
   ```
4. **Envía tu Rama a GitHub:**
   ```bash
   git push origin feature/nueva-funcionalidad
   ```
5. **Abre un Pull Request:** Dirígete a la pestaña **Pull Requests** del repositorio original y haz clic en **New Pull Request**.

---

## Autor

- **Juan Sebastián Muñoz Calderón**  
  Correo institucional: `jsmunozcalderon@estudiante.uniajc.edu.co`  
  Institución Universitaria Antonio José Camacho (UNIAJC) — Cali, Colombia
