# Livox Gen2 ROS2 en Docker

La carpeta `livox_gen2` contiene los ficheros necesarios para instalar los paquetes ROS2 de LiDARs Livox de segunda generación (HAP y Mid-360), junto con sus dependencias, en una imagen Docker.
Tanto los paquetes ROS2 como la dependencia Livox SDK se instalan desde código fuente clonando sus repositorios.

Repositorios oficiales:
- Paquetes ROS2 de Livox: `https://github.com/Livox-SDK/livox_ros_driver2`
- Livox SDK2: `https://github.com/Livox-SDK/Livox-SDK2`

Actualmente este proyecto usa forks mantenidos para `livox_ros_driver2` y `livox_sdk2`, seleccionados en `examples/refs.txt`.

Los scripts `setup.sh`, `compile.sh` y `eut_sensor.launch.py` están diseñados para usarse desde un `Dockerfile` y automatizar la construcción de la imagen.

## Ejemplo de uso

Para ilustrar cómo usar los ficheros anteriores, se incluye un ejemplo en la carpeta `examples/`, donde hay un `Dockerfile` para construir una imagen que permite ejecutar los paquetes ROS2 de Livox Gen2 dentro de un contenedor Docker.

El proceso está pensado para que sea cómodo para el usuario: ejecuta `examples/build.py` e indica la distro de ROS2 que quieres usar (`humble` o `jazzy`).

Ejemplo:
```bash
cd sensors/lidars/livox_gen2/examples
./build.py jazzy
```

El script incluye flags opcionales que pueden ser útiles (por ejemplo, control de caché, pull de imagen base, metadatos o nombre de imagen). Para verlos:
```bash
./build.py -h
```

En `examples/`, el fichero `refs.txt` define las referencias remotas (tags/ramas) que se clonan para:
- `livox_sdk2`
- `livox_ros_driver2`
- `ros2_launch_helpers`

Formato esperado:
```txt
livox_sdk2 main
livox_ros_driver2 main
ros2_launch_helpers main
```

El ejemplo de Livox soporta dos configuraciones:
- `example 1`: un LiDAR frontal (`example_1.front_livox_mid360.json` + `example_1.front_livox_mid360.yaml`)
- `example 2`: LiDAR frontal y trasero (`example_2.front_back_livox_mid360.json` + `example_2.front_back_livox_mid360.yaml`)

Nota importante sobre JSON:
- Los ficheros usados por el driver (`example_*.json`, o cualquier fichero apuntado por `user_config_path`) deben ser JSON estricto.
- No incluyas comentarios `//` en esos ficheros. El parser del código fuente de `livox_ros_driver2` (driver del fabricante) falla y puede mostrar `parse lidar type failed.`
- Este repositorio aporta plantillas comentadas para explicar el objetivo de cada campo:
  - `examples/template_user_config_1_lidar.json` (un LiDAR)
  - `examples/template_user_config_2_lidars.json` (dos LiDARs)
- Usa esas plantillas como guía para crear los JSON de tu proyecto, pero en ejecución entrega al driver ficheros JSON sin comentarios.

Una vez construida la imagen con `examples/build.py`, puedes iniciar el contenedor en dos modos usando `examples/run_docker_container.sh`:

- modo `automatic`: el contenedor arranca y ejecuta automáticamente el launch del driver ROS2.
- modo `manual`: el contenedor arranca sin lanzar el driver, para que puedas entrar a una shell y ejecutarlo manualmente.

Ejemplo (si construiste con `./build.py jazzy`, el `img_id` por defecto es `livox_gen2:jazzy`):

```bash
cd sensors/lidars/livox_gen2/examples
./run_docker_container.sh livox_gen2:jazzy automatic --example 1
```

Si prefieres modo manual:

```bash
cd sensors/lidars/livox_gen2/examples
./run_docker_container.sh livox_gen2:jazzy manual --example 2
docker compose exec -it livox_gen2_srvc bash
bash /tmp/run_launch_in_terminal.sh
```

Este ejemplo también está preparado para ejecutar aplicaciones gráficas desde el contenedor y mostrarlas en el host mediante X11/XWayland.

El script `run_docker_container.sh` permite configurar variables mediante `--env KEY=VALUE`.

Variables con valores por defecto en este ejemplo:

- `NAMESPACE` (por defecto: vacío)
- `ROBOT_NAME` (por defecto: `robot`)
- `ROS_DOMAIN_ID` (por defecto: `11`)
- `NODE_OPTIONS` (por defecto: `name=livox_gen2_lidar_ros2_handler,output=screen,emulate_tty=True,respawn=False,respawn_delay=0.0`)
- `LOGGING_OPTIONS` (por defecto: `log-level=info,disable-stdout-logs=true,disable-rosout-logs=false,disable-external-lib-logs=true`)

`NODE_OPTIONS` y `LOGGING_OPTIONS` son variables de tipo `kvs` (key-value-string), es decir, un string formado por pares `key=value` separados por comas.

Variables adicionales soportadas por el script:

- `TOPIC_REMAPPINGS`: string de remapeo en formato `OLD:=NEW`, con pares separados por comas.
- `ROS_LOCALHOST_ONLY=1|0` (ROS2 Humble y anteriores, sin valor por defecto)
- `ROS_AUTOMATIC_DISCOVERY_RANGE=LOCALHOST|SUBNET|OFF|SYSTEM_DEFAULT` (ROS2 Jazzy y posteriores, sin valor por defecto)
- `ROS_STATIC_PEERS='192.168.0.1;remote.com'` (ROS2 Jazzy y posteriores, sin valor por defecto)

Hay variables que no se pueden configurar con `--env` en este flujo:

- `RMW_IMPLEMENTATION`: fijada en `examples/docker_compose_base.yaml` como `rmw_cyclonedds_cpp`.
- `CYCLONEDDS_URI`: fijada en `examples/docker_compose_base.yaml`.
- `PARAMS_FILE`: fijada en `examples/docker_compose_base.yaml`. Apunta al YAML seleccionado montado como `/tmp/params.yaml`.
- `USER_CONFIG_FILE_HOST`: la selecciona internamente `run_docker_container.sh` a partir de `--example`.
- `PARAMS_FILE_HOST`: la selecciona internamente `run_docker_container.sh` a partir de `--example`.
- `IMG_ID`: se toma del argumento posicional `<img_id>` del script.
- `ENV_FILE`: lo gestiona internamente el script. Es el fichero `.env` temporal que `docker compose` carga mediante `env_file` (en `examples/docker_compose_base.yaml`) para pasar variables de entorno al contenedor del servicio `livox_gen2_srvc`.

La configuración de CycloneDDS usada en este ejemplo está definida en `examples/cyclonedds_config.xml`.

El flujo de launch mantiene el comportamiento actual de sustitución de placeholders JSON/YAML:
- Los ficheros JSON pueden contener `{{robot_prefix}}`.
- en este flujo, `run_docker_container.sh` monta el JSON seleccionado como `/tmp/user_config.json` según `--example`.
- `user_config_path` en `PARAMS_FILE` debe apuntar a `/tmp/user_config.json`.
- `run_launch.sh` resuelve `{{robot_prefix}}` en el JSON apuntado por `user_config_path` y actualiza `user_config_path` en un YAML temporal cuando es necesario.

Ejemplo de ejecución con overrides:

```bash
./run_docker_container.sh livox_gen2:jazzy automatic --example 2 \
  --env ROBOT_NAME=robot1 \
  --env ROS_DOMAIN_ID=21 \
  --env ROS_AUTOMATIC_DISCOVERY_RANGE=LOCALHOST
```

Para ver todas las opciones disponibles:

```bash
./run_docker_container.sh -h
```

Para más información sobre configuración del sensor y el proyecto del driver:
- https://github.com/Livox-SDK/livox_ros_driver2
