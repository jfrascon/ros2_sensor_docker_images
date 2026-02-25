# RoboSense ROS2 en Docker

La carpeta `robosense` contiene los ficheros necesarios para instalar los paquetes ROS2 de LiDARs RoboSense, junto con sus dependencias, en una imagen Docker.
Los paquetes ROS2 se instalan desde código fuente clonando repositorios.

Repositorios oficiales:
- Paquetes ROS2 de RoboSense: `https://github.com/RoboSense-LiDAR/rslidar_sdk`
- Driver base `rs_driver`: `https://github.com/RoboSense-LiDAR/rs_driver`

Actualmente este proyecto usa forks mantenidos para `rslidar_sdk`, `rslidar_msg` y `ros2_launch_helpers`, seleccionados en `examples/refs.txt`.

Los scripts `setup.sh`, `compile.sh` y `sensor.launch.py` están diseñados para usarse desde un `Dockerfile` y automatizar la construcción de la imagen.

## Ejemplo de uso

Para ilustrar cómo usar los ficheros anteriores, se incluye un ejemplo en la carpeta `examples/`, donde hay un `Dockerfile` para construir una imagen que permite ejecutar los paquetes ROS2 de RoboSense dentro de un contenedor Docker.

El proceso está pensado para que sea cómodo para el usuario: ejecuta `examples/build.py` e indica la distro de ROS2 que quieres usar (`humble` o `jazzy`).

Ejemplo:
```bash
cd sensors/lidars/robosense/examples
./build.py jazzy
```

El script incluye flags opcionales que pueden ser útiles (por ejemplo, control de caché, pull de imagen base, metadatos o nombre de imagen). Para verlos:
```bash
./build.py -h
```

En `examples/`, el fichero `refs.txt` define las referencias remotas (tags/ramas) que se clonan para:
- `rslidar_sdk`
- `rslidar_msg`
- `ros2_launch_helpers`

Formato esperado:
```txt
rslidar_sdk main
rslidar_msg main
ros2_launch_helpers main
```

El ejemplo de RoboSense soporta dos configuraciones:
- `example 1`: un LiDAR frontal (`example_1.front_robosense_helios_16p_config.yaml`)
- `example 2`: LiDAR frontal y trasero (`example_2.front_back_robosense_helios_16p_config.yaml`)

Una vez construida la imagen con `examples/build.py`, puedes iniciar el contenedor en dos modos usando `examples/run_docker_container.sh`:

- modo `automatic`: el contenedor arranca y ejecuta automáticamente el launch del driver ROS2.
- modo `manual`: el contenedor arranca sin lanzar el driver, para que puedas entrar a una shell y ejecutarlo manualmente.

Nota sobre el alcance de estos ficheros de ejemplo:
- `run_docker_container.sh` y los compose fragmentados (`docker_compose_mode_automatic.yaml`, `docker_compose_mode_manual.yaml`, `docker_compose_gui.yaml`) están orientados a facilitar pruebas y experimentación.
- En un despliegue de producción, lo habitual es definir un único `docker compose` propio con la configuración del sensor, el comando de arranque y, si aplica, la parte de GUI.
- En ese caso no es necesario usar `run_docker_container.sh` ni separar la configuración en modos `automatic/manual/gui`.

El script solo recibe argumentos posicionales:
- `<img_id>`
- `<mode>` (`automatic` o `manual`)

El fichero de configuración de RoboSense se selecciona en `examples/docker_compose_base.yaml`:
- Por defecto (ya activo): `example_1.front_robosense_helios_16p_config.yaml` (un LiDAR).
- Alternativa: descomentar `example_2.front_back_robosense_helios_16p_config.yaml` y comentar la línea de `example_1`.

Ejemplo 1 (si construiste con `./build.py jazzy`, el `img_id` por defecto es `robosense:jazzy`):

```bash
cd sensors/lidars/robosense/examples
./run_docker_container.sh robosense:jazzy automatic
```

Ejemplo 2 en modo manual:

```bash
cd sensors/lidars/robosense/examples
# En docker_compose_base.yaml:
# - comentar la línea de volumen de example_1
# - descomentar la línea de volumen de example_2
./run_docker_container.sh robosense:jazzy manual
docker compose exec -it robosense_srvc bash
ros2 launch rslidar_sdk sensor.launch.py
```

El flujo de GUI es automático:
- Si `DISPLAY` está definido en el host, `run_docker_container.sh` añade `docker_compose_gui.yaml` y ejecuta `xhost +local:`.
- Si `DISPLAY` no está definido, el contenedor arranca en modo headless (sin montaje de X11).

Las variables de entorno de ejecución están definidas en `examples/docker_compose_base.yaml`, en la sección `environment`.
En particular, `sensor.launch.py` usa:

- `NAMESPACE` (opcional)
- `ROBOT_NAME` (obligatoria para el launch)
- `CONFIG_FILE` (obligatoria para el launch; fijada a `/tmp/config.yaml` en compose)
- `NODE_OPTIONS` (opcional, formato `kvs`: `key=value,key=value,...`)
- `LOGGING_OPTIONS` (opcional, formato `kvs`: `key=value,key=value,...`)

Otras variables usadas en este ejemplo:
- `ROS_DOMAIN_ID`
- `RMW_IMPLEMENTATION` (fijada a `rmw_cyclonedds_cpp`)
- `CYCLONEDDS_URI` (fijada a `examples/cyclonedds_config.xml`)

La configuración de CycloneDDS usada en este ejemplo está definida en `examples/cyclonedds_config.xml`.

El flujo de launch soporta plantillas en la configuración:
- Los ficheros de configuración pueden contener `{{robot_prefix}}`.
- `sensor.launch.py` renderiza el fichero con Jinja2 usando `robot_prefix`, derivado de `ROBOT_NAME`.
- Variables de plantilla no definidas provocan error (`StrictUndefined`).
- Si el render modifica el contenido, se genera y usa el fichero efectivo `/tmp/robosense_config_YYYYMMDD.yaml`.

Para ver todas las opciones disponibles:

```bash
./run_docker_container.sh -h
```

Para más información sobre configuración del sensor y el proyecto del driver:
- https://github.com/RoboSense-LiDAR/rslidar_sdk
