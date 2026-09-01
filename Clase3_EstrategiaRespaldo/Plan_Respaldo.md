PLAN DE RESPALDO 

## Objetivo
Definir un plan de respaldo para bases de datos que sea realista, verificable y alineado al uso y tamano del sistema.

## Tipos de respaldo
### Completo
- Copia total de la base en un punto de tiempo.
- Cuando conviene: bases pequenas o para crear un punto base confiable.
- Ventajas: restauracion simple y directa.
- Desventajas: mayor tiempo y espacio.

### Incremental
- Copia solo los cambios desde el ultimo respaldo (completo o incremental).
- Cuando conviene: bases con cambios frecuentes y ventanas cortas.
- Ventajas: backups mas rapidos y livianos.
- Desventajas: restauracion mas compleja (base + todos los incrementales).

### Diferencial
- Copia los cambios desde el ultimo respaldo completo.
- Cuando conviene: equilibrio entre rapidez y simplicidad.
- Ventajas: restauracion simple (base + ultimo diferencial).
- Desventajas: cada diferencial crece con el tiempo.

## Estrategias segun tamano y uso
- Base pequena y poco cambio: completo semanal + incremental diario.
- Base mediana con cambio moderado: completo semanal + diferencial diario.
- Base grande y alto volumen: completo semanal o mensual + incremental varias veces por dia.
- Definir RPO (perdida maxima aceptable) y RTO (tiempo maximo de recuperacion).
- Probar restauraciones en un entorno de prueba de forma periodica.

## Herramientas de respaldo (ventajas y desventajas)
- Respaldos logicos (ej: mysqldump, mysqlpump)
  - Ventajas: portables, faciles de inspeccionar, compatibles entre versiones.
  - Desventajas: mas lentos en bases grandes, mayor tiempo de restauracion.
- Respaldos fisicos (ej: Percona XtraBackup)
  - Ventajas: mas rapidos, adecuados para grandes volumenes.
  - Desventajas: requieren mas espacio y manejo de archivos.
- Snapshots de volumen
  - Ventajas: muy rapidos, buena opcion en infraestructura virtualizada.
  - Desventajas: requieren coordinacion para consistencia.
- Servicios gestionados (cloud)
  - Ventajas: automatizan retencion y replicas.
  - Desventajas: costo y menor control fino.

## Automatizacion de respaldos
- Usar scripts con registro de ejecucion (logs).
- Programar tareas con cron o Task Scheduler.
- Incluir verificacion basica: tamanos de archivo, checksum y alertas.
- Guardar copias fuera del servidor principal.

## Planificacion de respaldos
- Frecuencia basada en RPO/RTO y volumen de cambios.
- Retencion y rotacion (ej: diario, semanal, mensual).
- Cifrado y control de acceso a los archivos.
- Documentar responsabilidades y procedimientos.

## Comandos de prueba para MySQL 
### Caso practico 
Una empresa de ventas en linea necesita un plan de respaldo para la base `tienda_online`.
La empresa trabaja 24/7 y requiere:
- Respaldo completo semanal (domingos 02:00).
- Incrementales diarios (lunes a sabado 02:00).
- Diferenciales semanales como alternativa cuando el volumen diario crece.

### Paso 1: respaldo completo de referencia
```bash
# Genera un respaldo completo consistente de la base
mysqldump -u root -p --single-transaction --set-gtid-purged=OFF tienda_online > respaldo_completo_semana1.sql

# Cierra el binlog actual para separar los cambios posteriores al respaldo completo
mysql -u root -p -e "FLUSH LOGS;"
```

### Paso 2: respaldo incremental diario
```bash
# Muestra los binlogs disponibles para identificar el archivo del dia
mysql -u root -p -e "SHOW BINARY LOGS;"

# Copia el binlog que contiene los cambios del dia (incremental)
cp /var/lib/mysql/binlog.000123 incremental_lunes.bin
```

### Paso 3: respaldo diferencial semanal (alternativa)
```bash
# Copia todos los binlogs desde el ultimo respaldo completo
# Este diferencial reemplaza a los diferenciales anteriores de la misma semana
cp /var/lib/mysql/binlog.000120 diff_semana1_parte1.bin
cp /var/lib/mysql/binlog.000121 diff_semana1_parte2.bin
cp /var/lib/mysql/binlog.000122 diff_semana1_parte3.bin
```

### Paso 4: notas de verificacion
```bash
# Verifica que los archivos de respaldo existan y tengan tamano esperado
ls -lh respaldo_completo_semana1.sql incremental_lunes.bin diff_semana1_parte*.bin
```

## Recuperacion a partir de diferentes tipos de respaldos
- Con respaldo completo: restaurar la copia completa.
- Con incremental: restaurar el completo y aplicar incrementales en orden.
- Con diferencial: restaurar el completo y aplicar el ultimo diferencial.
- Verificar integridad y consistencia antes de volver a produccion.

## Ejercicio practico 
Plantea un plan de respaldo para una base de datos con:
- Tamano: 120 GB
- Crecimiento diario: 2 GB
- Ventana de mantenimiento: 1 hora diaria
- RPO (Recovery Point Objective): 4 horas
- RTO (Recovery Time Objective): 2 horas


