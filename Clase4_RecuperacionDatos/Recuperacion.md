
RESPALDO COMPLETO

**MySQL Local**: 
```bash
mysqldump -u root -p tienda_online > respaldo.sql
```
---

## RESPALDO COMPLETO (Docker)

### Crear Respaldo
```bash
# Comando básico 
docker exec backups mysqldump -u root -pejemplo3clase3 --set-gtid-purged=OFF tienda_online > respaldo_completo.sql

# Con fecha
docker exec backups mysqldump -u root -pejemplo3clase3 --set-gtid-purged=OFF tienda_online > "respaldo_completo_$(Get-Date -Format 'yyyyMMdd').sql"
```

---

## RESTAURACIÓN (Docker)

### Restaurar Respaldo

```powershell
# Método 1: Con Get-Content 
Get-Content respaldo_completo.sql | docker exec -i backups mysql -u root -pejemplo3clase3 tienda_online

# Método 2: Copiar archivo y restaurar
docker cp respaldo_completo.sql backups:/tmp/
docker exec -i backups sh -c "mysql -u root -pejemplo3clase3 tienda_online < /tmp/respaldo_completo.sql"
```


---



### Acceso a MySQL dentro del contenedor

```bash
# Conectarse a MySQL
docker exec -it backups mysql -u root -pejemplo3clase3

# Ejecutar consulta directa
docker exec backups mysql -u root -pejemplo3clase3 -e "SHOW DATABASES;"

# Ejecutar archivo SQL (PowerShell)
Get-Content archivo.sql | docker exec -i backups mysql -u root -pejemplo3clase3
```

### Ver archivos dentro del contenedor
```bash
# Listar archivos de base de datos
docker exec backups ls -lh /var/lib/mysql

# Ver archivos binlog (MySQL 8.0)
docker exec backups mysql -u root -pejemplo3clase3 -e "SHOW BINARY LOGS;"

# Ver archivos de log
docker exec backups tail -f /var/log/mysql/error.log
```

---

##  RESPALDOS INCREMENTALES/DIFERENCIALES CON DOCKER

docker run --name backups  -e MYSQL_ROOT_PASSWORD=ejemplo3clase3  -e MYSQL_LOG_BIN=mysql-bin  -p 3306:3306  -d mysql:latest



# Ver binlogs actuales (los archivos que contienen los cambios)

docker exec backups mysql -u root -pejemplo3clase3 -e "SHOW BINARY LOGS;"


### Respaldo Incremental Simple ( Cambios desde el último incremental)

```powershell
# 1. Crear respaldo completo base con rotación de binlog
docker exec backups mysqldump -u root -pejemplo3clase3 --single-transaction --flush-logs --master-data=2 --set-gtid-purged=OFF tienda_online > base_completo.sql

# 2. Ver qué binlog se creó después del respaldo
docker exec backups mysql -u root -pejemplo3clase3 -e "SHOW BINARY LOGS;"

# 3. Hacer cambios en la BD (simular trabajo del día)
docker exec backups mysql -u root -pejemplo3clase3 tienda_online -e "INSERT INTO clientes (nombre, email) VALUES ('Cliente Nuevo 1', 'nuevo1@test.com');"
docker exec backups mysql -u root -pejemplo3clase3 tienda_online -e "INSERT INTO clientes (nombre, email) VALUES ('Cliente Nuevo 2', 'nuevo2@test.com');"

# 4. Rotar binlog (esto cierra el binlog actual y crea uno nuevo)
docker exec backups mysql -u root -pejemplo3clase3 -e "FLUSH LOGS;"

# 5. Copiar el binlog que contiene los cambios del día
# Nota: Copia el binlog ANTERIOR al último (ese tiene los cambios)
docker exec backups mysql -u root -pejemplo3clase3 -e "SHOW BINARY LOGS;"
docker cp backups:/var/lib/mysql/binlog.000002 incremental_dia1.bin

# 6. Simular pérdida de datos (eliminar BD)
docker exec backups mysql -u root -pejemplo3clase3 -e "DROP DATABASE tienda_online; CREATE DATABASE tienda_online;"

# 7. Restaurar respaldo completo
Get-Content base_completo.sql | docker exec -i backups mysql -u root -pejemplo3clase3 tienda_online

# 8. Verificar que los nuevos clientes NO están (solo hay 10)
docker exec backups mysql -u root -pejemplo3clase3 -e "USE tienda_online; SELECT COUNT(*) AS total FROM clientes;"

# 9. Aplicar binlog incremental (recuperar cambios del día)
docker cp incremental_dia1.bin backups:/tmp/
docker exec backups sh -c "/usr/libexec/mysqlsh/mysqlbinlog --skip-gtids /tmp/incremental_dia1.bin | mysql -u root -pejemplo3clase3 tienda_online"

# 10. Verificar que AHORA sí están los nuevos clientes (12 total)
docker exec backups mysql -u root -pejemplo3clase3 -e "USE tienda_online; SELECT COUNT(*) AS total FROM clientes; SELECT * FROM clientes ORDER BY id_cliente DESC LIMIT 3;"

#PARA REINICIAR LOS BINLOGS Y COMENZAR DE NUEVO:
docker exec backups mysql -u root -pejemplo3clase3 -e "RESET BINARY LOGS AND GTIDS;"


---

## EJERCICIO PARA LA CLASE

Usa estos comandos en orden:

```powershell
# 1. Crear BD de prueba
Get-Content 01_BASE_DATOS_PRUEBA.sql | docker exec -i backups mysql -u root -pejemplo3clase3

# 2. Verificar
docker exec backups mysql -u root -pejemplo3clase3 -e "USE tienda_online; SELECT COUNT(*) FROM clientes;"

# 3. Crear respaldo
docker exec backups mysqldump -u root -pejemplo3clase3 --set-gtid-purged=OFF tienda_online > respaldo_clase.sql

# 4. Eliminar BD
docker exec backups mysql -u root -pejemplo3clase3 -e "DROP DATABASE tienda_online;"

# 5. Restaurar
docker exec backups mysql -u root -pejemplo3clase3 -e "CREATE DATABASE tienda_online;"
Get-Content respaldo_clase.sql | docker exec -i backups mysql -u root -pejemplo3clase3 tienda_online

# 6. Verificar recuperación
docker exec backups mysql -u root -pejemplo3clase3 -e "USE tienda_online; SHOW TABLES;"
```

## RESPALDO DIFERENCIAL (Cambios acumulados desde el último COMPLETO)

- **DIFERENCIAL**: Acumula TODOS los cambios desde el último respaldo COMPLETO
- **Ventaja**: Restauración SIMPLE → **Base + SOLO último diferencial**
- **Desventaja**: Usa más espacio que incremental (cada diferencial crece)

---

### Paso a Paso con Ejemplo de 3 Días

```powershell
# ===== DÍA 0: RESPALDO COMPLETO BASE =====
docker exec backups mysqldump -u root -pejemplo3clase3 --single-transaction --flush-logs --master-data=2 --set-gtid-purged=OFF tienda_online > base_completo_diferencial.sql

# Ver el binlog después del respaldo completo
docker exec backups mysql -u root -pejemplo3clase3 -e "SHOW BINARY LOGS;"
# Resultado: binlog.000002 (PUNTO DE PARTIDA para todos los diferenciales)

# ===== DÍA 1: Cambios + crear primer diferencial =====
docker exec backups mysql -u root -pejemplo3clase3 tienda_online -e "INSERT INTO clientes (nombre, email) VALUES ('Cliente Dia 1', 'dia1@test.com');"

# Rotar binlog del día 1
docker exec backups mysql -u root -pejemplo3clase3 -e "FLUSH LOGS;"

# DIFERENCIAL DÍA 1: Solo 1 binlog (cambios desde base)
docker cp backups:/var/lib/mysql/binlog.000002 diferencial_dia1.bin

# ===== DÍA 2: Más cambios + diferencial más grande =====
docker exec backups mysql -u root -pejemplo3clase3 tienda_online -e "INSERT INTO clientes (nombre, email) VALUES ('Cliente Dia 2', 'dia2@test.com');"

# Rotar binlog del día 2
docker exec backups mysql -u root -pejemplo3clase3 -e "FLUSH LOGS;"

# DIFERENCIAL DÍA 2: 2 binlogs juntos (TODOS los cambios desde base)
# Nota: Este diferencial reemplaza al del día 1, no lo complementa
docker cp backups:/var/lib/mysql/binlog.000002 diff2_parte1.bin
docker cp backups:/var/lib/mysql/binlog.000003 diff2_parte2.bin

# ===== DÍA 3: Más cambios + diferencial completo final =====
docker exec backups mysql -u root -pejemplo3clase3 tienda_online -e "INSERT INTO clientes (nombre, email) VALUES ('Cliente Dia 3', 'dia3@test.com');"

# Rotar para cerrar el día 3
docker exec backups mysql -u root -pejemplo3clase3 -e "FLUSH LOGS;"

# Ver todos los binlogs acumulados
docker exec backups mysql -u root -pejemplo3clase3 -e "SHOW BINARY LOGS;"

# DIFERENCIAL DÍA 3: 3 binlogs juntos (TODOS los cambios desde base)
# Este diferencial reemplaza completamente los anteriores
docker cp backups:/var/lib/mysql/binlog.000002 diff3_parte1.bin
docker cp backups:/var/lib/mysql/binlog.000003 diff3_parte2.bin
docker cp backups:/var/lib/mysql/binlog.000004 diff3_parte3.bin

# ===== RECUPERACIÓN CON DIFERENCIAL (Lo más simple) =====
# Simular pérdida total
docker exec backups mysql -u root -pejemplo3clase3 -e "DROP DATABASE tienda_online; CREATE DATABASE tienda_online;"

# 1. Restaurar base completa (10 clientes originales)
Get-Content base_completo_diferencial.sql | docker exec -i backups mysql -u root -pejemplo3clase3 tienda_online

# 2. Aplicar SOLO el diferencial del día 3 (ignorar día 1 y 2)
# El diferencial del día 3 YA contiene todo lo necesario
docker cp diff3_parte1.bin backups:/tmp/
docker cp diff3_parte2.bin backups:/tmp/
docker cp diff3_parte3.bin backups:/tmp/

# Aplicar los binlogs del último diferencial en UN solo comando
docker exec backups sh -c "/usr/libexec/mysqlsh/mysqlbinlog --skip-gtids /tmp/diff3_parte1.bin /tmp/diff3_parte2.bin /tmp/diff3_parte3.bin | mysql -u root -pejemplo3clase3 tienda_online"

# 3. Verificar: Deben estar los 10 originales + 3 nuevos = 13
docker exec backups mysql -u root -pejemplo3clase3 -e "USE tienda_online; SELECT COUNT(*) FROM clientes; SELECT * FROM clientes ORDER BY id_cliente DESC LIMIT 4;"
```

---
