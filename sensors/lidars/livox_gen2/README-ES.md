# Livox Gen2 ROS2 en Docker

La carpeta `livox_gen2` contiene los ficheros necesarios para instalar los paquetes ROS2 de LiDARs Livox de segunda generación (HAP y Mid-360), junto con sus dependencias, en una imagen Docker.
Tanto los paquetes ROS2 como la dependencia Livox SDK se instalan desde código fuente clonando sus repositorios.

Repositorios oficiales:
- Paquetes ROS2 de Livox: `https://github.com/Livox-SDK/livox_ros_driver2`
- Livox SDK2: `https://github.com/Livox-SDK/Livox-SDK2`

Actualmente este proyecto usa forks mantenidos para `livox_ros_driver2`, `livox_sdk2` y `ros2_launch_helpers`, seleccionados en `examples/refs.txt`.

Los scripts `setup.sh`, `compile.sh` y `sensor.launch.py` están diseñados para usarse desde un `Dockerfile` y automatizar la construcción de la imagen.

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

Nota sobre el alcance de estos ficheros de ejemplo:
- `run_docker_container.sh` y los compose fragmentados (`docker_compose_mode_automatic.yaml`, `docker_compose_mode_manual.yaml`, `docker_compose_gui.yaml`) están orientados a facilitar pruebas y experimentación.
- En un despliegue de producción, lo habitual es definir un único `docker compose` propio con la configuración del sensor, el comando de arranque y, si aplica, la parte de GUI.
- En ese caso no es necesario usar `run_docker_container.sh` ni separar la configuración en modos `automatic/manual/gui`.

El script solo recibe argumentos posicionales:
- `<img_id>`
- `<mode>` (`automatic` o `manual`)

Los ficheros de configuración se seleccionan en `examples/docker_compose_base.yaml`:
- Por defecto (ya activo): `example_1.front_livox_mid360.json` + `example_1.front_livox_mid360.yaml`.
- Alternativa: descomentar `example_2.front_back_livox_mid360.json` + `example_2.front_back_livox_mid360.yaml` y comentar las líneas de `example_1`.

Ejemplo 1 (si construiste con `./build.py jazzy`, el `img_id` por defecto es `livox_gen2:jazzy`):

```bash
cd sensors/lidars/livox_gen2/examples
./run_docker_container.sh livox_gen2:jazzy automatic
```

Ejemplo 2 en modo manual:

```bash
cd sensors/lidars/livox_gen2/examples
# En docker_compose_base.yaml:
# - comentar las líneas de volumen de example_1
# - descomentar las líneas de volumen de example_2
./run_docker_container.sh livox_gen2:jazzy manual
docker compose exec -it livox_gen2_srvc bash
ros2 launch livox_ros_driver2 sensor.launch.py
```

El flujo de GUI es automático:
- Si `DISPLAY` está definido en el host, `run_docker_container.sh` añade `docker_compose_gui.yaml` y ejecuta `xhost +local:`.
- Si `DISPLAY` no está definido, el contenedor arranca en modo headless (sin montaje de X11).

Las variables de entorno de ejecución están definidas en `examples/docker_compose_base.yaml`, en la sección `environment`.
En particular, `sensor.launch.py` usa:

- `NAMESPACE` (opcional)
- `ROBOT_NAME` (obligatoria para el launch)
- `PARAMS_FILE` (obligatoria para el launch; fijada a `/tmp/params.yaml` en compose)
- `TOPIC_REMAPPINGS` (opcional, string de remapeo `OLD:=NEW,OLD:=NEW,...`)
- `NODE_OPTIONS` (opcional, formato `kvs`: `key=value,key=value,...`)
- `LOGGING_OPTIONS` (opcional, formato `kvs`: `key=value,key=value,...`)

Otras variables usadas en este ejemplo:
- `ROS_DOMAIN_ID`
- `RMW_IMPLEMENTATION` (fijada a `rmw_cyclonedds_cpp`)
- `CYCLONEDDS_URI` (fijada a `examples/cyclonedds_config.xml`)

La configuración de CycloneDDS usada en este ejemplo está definida en `examples/cyclonedds_config.xml`.

El flujo de launch soporta plantillas en el JSON de usuario:
- `sensor.launch.py` lee `PARAMS_FILE`, obtiene `user_config_path` y renderiza ese JSON con Jinja2 usando `robot_prefix` (derivado de `ROBOT_NAME`).
- Variables Jinja2 no definidas provocan error (`StrictUndefined`).
- Si el render no cambia el contenido, se usa el `PARAMS_FILE` original.
- Si el render cambia el contenido, se generan y usan:
  - `/tmp/livox_config_YYYYMMDD.json`
  - `/tmp/livox_params_YYYYMMDD.yaml`

Para ver todas las opciones disponibles:

```bash
./run_docker_container.sh -h
```

Para más información sobre configuración del sensor y el proyecto del driver:
- https://github.com/Livox-SDK/livox_ros_driver2
