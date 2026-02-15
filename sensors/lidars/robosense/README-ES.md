# RoboSense ROS2 en Docker

La carpeta `robosense` contiene los ficheros necesarios para instalar los paquetes ROS2 de LiDARs RoboSense, junto con sus dependencias, en una imagen Docker.
Los paquetes ROS2 se instalan desde código fuente clonando repositorios.

Repositorios oficiales:
- Paquetes ROS2 de RoboSense: `https://github.com/RoboSense-LiDAR/rslidar_sdk`
- Driver base `rs_driver`: `https://github.com/RoboSense-LiDAR/rs_driver`

Actualmente este proyecto usa forks mantenidos para `rslidar_sdk`, `rslidar_msg` y `ros2_launch_helpers`, seleccionados en `examples/refs.txt`.

Los scripts `setup.sh`, `compile.sh` y `eut_sensor.launch.py` están diseñados para usarse desde un `Dockerfile` y automatizar la construcción de la imagen.

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

Ejemplo (si construiste con `./build.py jazzy`, el `img_id` por defecto es `robosense:jazzy`):

```bash
cd sensors/lidars/robosense/examples
./run_docker_container.sh robosense:jazzy automatic --example 1
```

Si prefieres modo manual:

```bash
cd sensors/lidars/robosense/examples
./run_docker_container.sh robosense:jazzy manual --example 2
docker compose exec -it robosense_srvc bash
bash /tmp/run_launch_in_terminal.sh
```

Este ejemplo también está preparado para ejecutar aplicaciones gráficas desde el contenedor y mostrarlas en el host mediante X11/XWayland.

El script `run_docker_container.sh` permite configurar variables mediante `--env KEY=VALUE`.

Variables con valores por defecto en este ejemplo:

- `NAMESPACE` (por defecto: vacío)
- `ROBOT_NAME` (por defecto: `robot`)
- `ROS_DOMAIN_ID` (por defecto: `11`)
- `NODE_OPTIONS` (por defecto: `name=robosense_lidar_ros2_handler,output=screen,emulate_tty=True,respawn=False,respawn_delay=0.0`)
- `LOGGING_OPTIONS` (por defecto: `log-level=info,disable-stdout-logs=true,disable-rosout-logs=false,disable-external-lib-logs=true`)

`NODE_OPTIONS` y `LOGGING_OPTIONS` son variables de tipo `kvs` (key-value-string), es decir, un string formado por pares `key=value` separados por comas.

Variables adicionales soportadas por el script:

- `ROS_LOCALHOST_ONLY=1|0` (ROS2 Humble y anteriores, sin valor por defecto)
- `ROS_AUTOMATIC_DISCOVERY_RANGE=LOCALHOST|SUBNET|OFF|SYSTEM_DEFAULT` (ROS2 Jazzy y posteriores, sin valor por defecto)
- `ROS_STATIC_PEERS='192.168.0.1;remote.com'` (ROS2 Jazzy y posteriores, sin valor por defecto)

Hay variables que no se pueden configurar con `--env` en este flujo:

- `RMW_IMPLEMENTATION`: fijada en `examples/docker_compose_base.yaml` como `rmw_cyclonedds_cpp`.
- `CYCLONEDDS_URI`: fijada en `examples/docker_compose_base.yaml`.
- `TOPIC_REMAPPINGS`: no está soportada en RoboSense; los remapeos se definen directamente en el fichero de configuración seleccionado.
- `CONFIG_FILE`: fijada en `examples/docker_compose_base.yaml`. Apunta al fichero de configuración seleccionado montado como `/tmp/config.yaml`.
- `CONFIG_FILE_HOST`: la selecciona internamente `run_docker_container.sh` a partir de `--example`.
- `IMG_ID`: se toma del argumento posicional `<img_id>` del script.
- `ENV_FILE`: lo gestiona internamente el script. Es el fichero `.env` temporal que `docker compose` carga mediante `env_file` (en `examples/docker_compose_base.yaml`) para pasar variables de entorno al contenedor del servicio `robosense_srvc`.

La configuración de CycloneDDS usada en este ejemplo está definida en `examples/cyclonedds_config.xml`.

El flujo de launch mantiene el comportamiento actual de sustitución de placeholders en la configuración:
- Los ficheros de configuración pueden contener `{{robot_prefix}}`.
- en este flujo, `run_docker_container.sh` monta el fichero de configuración seleccionado como `/tmp/config.yaml` según `--example`.
- `run_launch.sh` resuelve `{{robot_prefix}}` en el fichero de configuración y lanza el driver usando la ruta de configuración efectiva.

Ejemplo de ejecución con overrides:

```bash
./run_docker_container.sh robosense:jazzy automatic --example 2 \
  --env ROBOT_NAME=robot1 \
  --env ROS_DOMAIN_ID=21 \
  --env ROS_AUTOMATIC_DISCOVERY_RANGE=LOCALHOST
```

Para ver todas las opciones disponibles:

```bash
./run_docker_container.sh -h
```

Para más información sobre configuración del sensor y el proyecto del driver:
- https://github.com/RoboSense-LiDAR/rslidar_sdk
