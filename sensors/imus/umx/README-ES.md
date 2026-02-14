# UMX ROS2 en Docker

La carpeta `umx` contiene los ficheros necesarios para instalar los paquetes de ROS2 para IMUs CH Robotics UM6/UM7, junto con sus dependencias, en una imagen Docker.
Tanto los paquetes de ROS2 como la dependencia serial se instalan desde código fuente clonando sus repositorios oficiales.

Repositorios oficiales:
- Paquetes ROS2 de UM7/UM6: `https://github.com/ros-drivers/um7/tree/ros2`
- Librería `serial-ros2`: `https://github.com/RoverRobotics-forks/serial-ros2`

Los scripts `setup.sh`, `compile.sh` y `eut_sensor.launch.py` están diseñados para usarse desde un `Dockerfile` y automatizar la construcción de la imagen.

## Ejemplo de uso

Para ilustrar cómo usar los ficheros anteriores, se incluye un ejemplo en la carpeta `examples/`, donde hay un `Dockerfile` para construir una imagen que permite ejecutar los paquetes ROS2 de IMUs UM6/UM7 dentro de un contenedor Docker.

El proceso está pensado para que sea cómodo para el usuario: ejecuta `examples/build.py` e indica la distro de ROS2 que quieres usar (`humble` o `jazzy`).

Ejemplo:
```bash
cd sensors/imus/umx/examples
./build.py jazzy
```

El script incluye flags opcionales que pueden ser útiles (por ejemplo, control de caché, pull de imagen base, metadatos o nombre de imagen). Para verlos:
```bash
./build.py -h
```

En `examples/`, el fichero `refs.txt` define las referencias remotas (tags/ramas) que clona `setup.sh` para:
- `serial-ros2`
- `um7`
- `ros2_launch_helpers`

Formato esperado:
```txt
serial-ros2 master
um7 ros2
ros2_launch_helpers main
```

Una vez construida la imagen con `examples/build.py`, puedes iniciar el contenedor en dos modos usando `examples/run_docker_container.sh`:

- modo `automatic`: el contenedor arranca y ejecuta automáticamente el launch del driver ROS2.
- modo `manual`: el contenedor arranca sin lanzar el driver, para que puedas entrar a una shell y ejecutarlo manualmente.

Ejemplo (si construiste con `./build.py jazzy`, el `img_id` por defecto es `umx:jazzy`):

```bash
cd sensors/imus/umx/examples
./run_docker_container.sh umx:jazzy automatic --um-model 7
```

Si prefieres modo manual:

```bash
cd sensors/imus/umx/examples
./run_docker_container.sh umx:jazzy manual --um-model 7
docker compose exec -it um_srvc bash
bash /tmp/run_launch_in_terminal.sh
```

Este ejemplo también está preparado para ejecutar aplicaciones gráficas desde el contenedor y mostrarlas en el host mediante X11/XWayland.

El script `run_docker_container.sh` permite configurar variables mediante `--env KEY=VALUE`.

Variables con valores por defecto en este ejemplo:

- `NAMESPACE` (por defecto: vacío)
- `ROBOT_NAME` (por defecto: `robot`)
- `ROS_DOMAIN_ID` (por defecto: `11`)
- `NODE_OPTIONS` (por defecto: `name=umx,output=screen,emulate_tty=True,respawn=False,respawn_delay=0.0`)
- `LOGGING_OPTIONS` (por defecto: `log-level=info,disable-stdout-logs=true,disable-rosout-logs=false,disable-external-lib-logs=true`)

`NODE_OPTIONS` y `LOGGING_OPTIONS` son variables de tipo `kvs` (key-value-string), es decir, un string formado por pares `key=value` separados por comas.

Variables adicionales soportadas por el script:

- `TOPIC_REMAPPINGS`: string de remapeo en formato `OLD:=NEW`, con pares separados por comas.
- `ROS_LOCALHOST_ONLY=1|0` (ROS2 Humble y anteriores, sin valor por defecto)
- `ROS_AUTOMATIC_DISCOVERY_RANGE=LOCALHOST|SUBNET|OFF|SYSTEM_DEFAULT` (ROS2 Jazzy y posteriores, sin valor por defecto)
- `ROS_STATIC_PEERS='192.168.0.1;remote.com'` (ROS2 Jazzy y posteriores, sin valor por defecto)

En este ejemplo, si no usas `TOPIC_REMAPPINGS`, los nombres de tópicos incluyen el nombre del nodo. Para jerarquías de tópicos más claras, usa un nombre de nodo que represente el dispositivo físico (por ejemplo `front_imu`, `rear_imu`) en lugar de sufijos orientados a implementación.

Hay variables que no se pueden configurar con `--env` en este flujo:

- `RMW_IMPLEMENTATION`: fijada en `examples/docker_compose_base.yaml` como `rmw_cyclonedds_cpp`.
- `CYCLONEDDS_URI`: fijada en `examples/docker_compose_base.yaml`.
- `PARAMS_FILE`: se selecciona desde `--um-model` y queda fijada en `examples/docker_compose_base.yaml` como `/tmp/params.yaml`.
- `IMG_ID`: se toma del argumento posicional `<img_id>` del script.
- `ENV_FILE`: lo gestiona internamente el script. Es el fichero `.env` temporal que `docker compose` carga mediante `env_file` (en `examples/docker_compose_base.yaml`) para pasar variables de entorno al contenedor del servicio `um_srvc`.

La configuración de CycloneDDS usada en este ejemplo está definida en `examples/cyclonedds_config.xml`.

La configuración de parámetros por modelo UM está definida en:
- `examples/um6_params.yaml`
- `examples/um7_params.yaml`

Ejemplo de ejecución con overrides:

```bash
./run_docker_container.sh umx:jazzy automatic --um-model 6 \
  --env ROBOT_NAME=imu_front \
  --env ROS_DOMAIN_ID=21 \
  --env ROS_AUTOMATIC_DISCOVERY_RANGE=LOCALHOST
```

Para ver todas las opciones disponibles:

```bash
./run_docker_container.sh -h
```

Para más información sobre configuración del sensor y el proyecto del driver:
- https://github.com/ros-drivers/um7/tree/ros2
- https://github.com/RoverRobotics-forks/serial-ros2
