# RealSense ROS2 in Docker

La carpeta `realsense` contiene los ficheros necesarios para instalar los paquetes ROS2 para cámaras RealSense en varias distribuciones de ROS2, junto con sus dependencias, en una imagen Docker.
Tanto los paquetes ROS2 como la librería `librealsense2` se instalan desde código fuente, clonando sus repositorios oficiales.

Repositorios oficiales:
- Paquetes ROS2 RealSense: `https://github.com/realsenseai/realsense-ros`
- Libreria librealsense2: `https://github.com/realsenseai/librealsense`

Los scripts `setup.sh`, `install_librealsense2_from_source.sh`, `compile.sh` y `sensor.launch.py` están diseñados para ser usados desde un `Dockerfile` y automatizar la construcción de la imagen.

La guía [how_to_patch_the_kernel_and_install_librealsense2_in_host_operating_system.md](how_to_patch_the_kernel_and_install_librealsense2_in_host_operating_system.md) resume las opciones de instalación de `librealsense2` y ofrece criterios prácticos para escoger la más adecuada según el entorno y el caso de uso.

Además, el fichero [examples.md](examples.md) recopila ejemplos prácticos para facilitar la puesta en marcha y validación del entorno.

## Ejemplo de uso

Para ilustrar el uso de los ficheros mencionados anteriormente, se ha creado un ejemplo en la carpeta `examples/`, donde se proporciona un `Dockerfile` para construir una imagen que permite ejecutar los paquetes ROS2 de las cámaras RealSense dentro de un contenedor Docker.

El proceso está pensado para que sea cómodo para el usuario: basta con ejecutar `examples/build.py` e indicar la distro de ROS2 que quiere se usar (`humble` o `jazzy`).

Ejemplo:
```bash
cd sensors/cameras/realsense/examples
./build.py humble
```

El script incluye flags opcionales que pueden ser de interés (por ejemplo, control de caché, pull de imagen base, metadatos o nombre de imagen). Para verlos:
```bash
./build.py -h
```

En `examples/` hay dos ficheros que controlan que versiones se clonan y como se compila `librealsense2`:

- `refs.txt`: define las referencias remotas (tags/branches) que se clonan para:
  - `librealsense2`
  - `realsense-ros`
  - `ros2_launch_helpers`
- `librealsense2_compile_flags.txt`: define opciones CMake para compilar `librealsense2`.

Modifica `refs.txt` si quieres:
- fijar una version concreta por estabilidad o reproducibilidad,
- probar una version mas nueva (feature/bugfix),
- alinear versiones compatibles entre `realsense-ros` y `librealsense2`.

Formato esperado:
```txt
librealsense2 v2.56.5
realsense-ros 4.56.4
ros2_launch_helpers main
```

Ten en cuenta que la versión de `librealsense2` y la release de los paquetes ROS2 del repositorio `realsense-ros` están vinculadas: no cualquier combinación de versiones es compatible. Para saber qué versión de `librealsense2` corresponde a una release concreta de `realsense-ros`, lo más fiable es revisar el fichero [realsense2_camera/CMakeLists.txt](https://github.com/realsenseai/realsense-ros/blob/ros2-master/realsense2_camera/CMakeLists.txt) (usa el fichero de la release que necesites en `realsense-ros`; este enlace apunta a `ros2-master`) e identificar la versión indicada en `find_package(realsense2 X.Y.Z)`.

Modifica `librealsense2_compile_flags.txt` si quieres:
- habilitar/deshabilitar herramientas o ejemplos (`BUILD_TOOLS`, `BUILD_GRAPHICAL_EXAMPLES`, `BUILD_EXAMPLES`),
- ajustar backend (`FORCE_RSUSB_BACKEND`),
- activar o desactivar CUDA (`BUILD_WITH_CUDA`).

Formato esperado:
- una opcion por linea con `NAME=VALUE`,
- sin prefijo `-D`,
- valores booleanos `ON|OFF|TRUE|FALSE`.

Todos los flags de compilación de `librealsense2` se describen en la URL:
[https://github.com/realsenseai/librealsense/blob/master/CMake/lrs_options.cmake](https://github.com/realsenseai/librealsense/blob/master/CMake/lrs_options.cmake)

Las herramientas extras se describen en la URL:
[https://github.com/realsenseai/librealsense/tree/master/tools](https://github.com/realsenseai/librealsense/blob/master/tools).

Los ejemplos se describen en la URL:
[https://github.com/realsenseai/librealsense/tree/master/examples](https://github.com/realsenseai/librealsense/tree/master/examples).

Si `BUILD_EXAMPLES=ON`, se construyen los binarios `rs-callback`, `rs-color`, `rs-depth`, `rs-distance`, `rs-embedded-filter`, `rs-eth-config`, `rs-infrared`, `rs-hello-realsense`, `rs-on-chip-calib` y `rs-save-to-disk`.<br/><br/>
Si además `BUILD_GRAPHICAL_EXAMPLES=ON`, también se generan `realsense-viewer`, `rs-align`, `rs-align-gl`, `rs-align-advanced`, `rs-benchmark`, `rs-capture`, `rs-data-collect`, `rs-depth-quality`, `rs-gl`, `rs-hdr`, `rs-labeled-pointcloud`, `rs-measure`, `rs-motion`, `rs-multicam`, `rs-pointcloud`, `rs-post-processing`, `rs-record-playback`, `rs-rosbag-inspector`, `rs-sensor-control` y `rs-software-device`.<br/><br/>
Si `BUILD_EXAMPLES=OFF`, no se construye ninguno de los binarios anteriores, ni los gráficos ni los no gráficos, aunque `BUILD_GRAPHICAL_EXAMPLES` esté a `ON`.<br/><br/>
Si sólo quieres los ejemplos no gráficos, usa `BUILD_EXAMPLES=ON` y `BUILD_GRAPHICAL_EXAMPLES=OFF`.<br/><br/>
Si quieres los ejemplos gráficos, usa `BUILD_EXAMPLES=ON` y `BUILD_GRAPHICAL_EXAMPLES=ON`, lo que implica que también tendrás los ejemplos no gráficos.

Si `BUILD_TOOLS=ON`, se construyen los binarios `rs-convert`, `rs-enumerate-devices`, `rs-fw-logger`, `rs-terminal`, `rs-record`, `rs-fw-update` y `rs-embed`.<br/><br/>
Si además `BUILD_WITH_DDS=ON`, también se generan `rs-dds-adapter`, `rs-dds-config` y `rs-dds-sniffer`.<br/><br/>
Si `BUILD_TOOLS=OFF`, no se construye ninguno de los binarios anteriores, ni los DDS ni los no-DDS, aunque `BUILD_WITH_DDS` esté a `ON`.<br/><br/>
Si sólo quieres las herramientas base, usa `BUILD_TOOLS=ON` y `BUILD_WITH_DDS=OFF`.<br/><br/>
Si quieres las herramientas DDS, usa `BUILD_TOOLS=ON` y `BUILD_WITH_DDS=ON`, lo que implica que también tendrás las herramientas base.

Ejemplo de fichero con flags de compilación para `librealsense2`:
```txt
BUILD_WITH_CUDA=OFF
BUILD_EXAMPLES=ON
BUILD_GRAPHICAL_EXAMPLES=ON
BUILD_TOOLS=ON
FORCE_RSUSB_BACKEND=ON
```

Una vez construida la imagen con `examples/build.py`, puedes levantar el contenedor en dos modos usando `examples/run_docker_container.sh`:

- Modo `automatic`: el contenedor arranca y ejecuta automáticamente el launch del driver ROS2.
- Modo `manual`: el contenedor arranca sin lanzar el driver, para que puedas entrar por terminal y ejecutarlo manualmente.

Nota sobre el alcance de estos ficheros de ejemplo:
- `run_docker_container.sh` y los compose fragmentados (`docker_compose_mode_automatic.yaml`, `docker_compose_mode_manual.yaml`, `docker_compose_gui.yaml`) están orientados a facilitar pruebas y experimentación.
- En un despliegue de producción, lo habitual es definir un único `docker compose` propio con la configuración de la cámara, el comando de arranque y, si aplica, la parte de GUI.
- En ese caso no es necesario usar `run_docker_container.sh` ni separar la configuración en modos `automatic/manual/gui`.

El script solo recibe argumentos posicionales:
- `<img_id>`
- `<mode>` (`automatic` o `manual`)

Ejemplo (si has construido con `./build.py humble`, el `img_id` por defecto es `realsense:humble`):

```bash
cd sensors/cameras/realsense/examples
./run_docker_container.sh realsense:humble automatic
```

Si prefieres modo manual:

```bash
cd sensors/cameras/realsense/examples
./run_docker_container.sh realsense:humble manual
docker compose exec -it realsense_srvc bash
ros2 launch realsense2_camera sensor.launch.py
```

El flujo de GUI es automático:
- Si `DISPLAY` está definido en el host, `run_docker_container.sh` añade `docker_compose_gui.yaml` y ejecuta `xhost +local:`.
- Si `DISPLAY` no está definido, el contenedor arranca en modo headless (sin montaje de X11).

Este ejemplo está preparado para ejecutar aplicaciones gráficas desde el contenedor (por ejemplo `rviz2` y `realsense-viewer`) y mostrarlas en el host mediante X11/XWayland. Ten en cuenta que `realsense-viewer` sólo estará disponible si `librealsense2` se compiló con `BUILD_EXAMPLES=ON` y `BUILD_GRAPHICAL_EXAMPLES=ON`.

Las variables de entorno de ejecución se configuran en `examples/docker_compose_base.yaml`, sección `environment`.
En particular, `sensor.launch.py` usa:

- `ROBOT_NAME` (obligatoria para el launch)
- `PARAMS_FILE` (obligatoria para el launch; fijada a `/tmp/params.yaml` en compose)
- `NAMESPACE` (opcional)
- `TOPIC_REMAPPINGS` (opcional, string de remapeo `OLD:=NEW,OLD:=NEW,...`)
- `NODE_OPTIONS` (opcional, formato `kvs`: `key=value,key=value,...`)
- `LOGGING_OPTIONS` (opcional, formato `kvs`: `key=value,key=value,...`)

Otras variables usadas en este ejemplo:
- `ROS_DOMAIN_ID`
- `RMW_IMPLEMENTATION` (fijada a `rmw_cyclonedds_cpp`)
- `CYCLONEDDS_URI` (fijada a `examples/cyclonedds_config.xml`)

Los tópicos definidos por el nodo en su código fuente son privados (usan `~`). Por ello, si quieres remapear uno de esos tópicos, debes usar la ruta completa en el lado izquierdo. En el lado derecho, el uso de `~` es opcional. Si usas `~` en el lado derecho, el remapeo incluirá el nombre del nodo, es decir, `<NAMESPACE>/<ROBOT_NAME>/<NODE_NAME>/<NEW_TOPIC>`. Si no usas `~` en el lado derecho, y el nuevo tópico no empieza con `/`, el remapeo se resolverá como `<NAMESPACE>/<ROBOT_NAME>/<NEW_TOPIC>`. Si el nuevo tópico empieza con `/`, se mantendrá como está (remapeo global).

`<NAMESPACE>/<ROBOT_NAME>/<NODE_NAME>/<OLD_TOPIC>:=~/<NEW_TOPIC>`

Ejemplo en `docker_compose_base.yaml`:

```yaml
TOPIC_REMAPPINGS: "/test/myrobot/realsense_camera/color/camera_info:=~/color/ci"
```

Con ese ejemplo, el nuevo nombre completo del tópico es `/test/myrobot/realsense_camera/color/ci`.

Dado que por defecto (si no usas `TOPIC_REMAPPINGS`) los tópicos son privados y por tanto incluyen el nombre del nodo, lo recomendable es usar como nombre de nodo el nombre del dispositivo/cámara (por ejemplo `front_camera`, `rear_camera`, etc.) y evitar sufijos como `_node`, ya que ese sufijo aparecerá también en los nombres de los tópicos. Recuerda que el nombre del nodo se define en `NODE_OPTIONS`, con la clave `name`.

Si usas `TOPIC_REMAPPINGS`, puedes usar como nombre de nodo el que consideres oportuno, incluso con sufijo `_node` (por ejemplo `front_camera_node`), siempre que en el remapeo expongas tópicos con nombres centrados en la cámara/dispositivo.

Ejemplo en `docker_compose_base.yaml`:

```yaml
NODE_OPTIONS: "name=realsense_camera_node,output=screen,emulate_tty=True,respawn=False,respawn_delay=0.0"
TOPIC_REMAPPINGS: "/test/myrobot/realsense_camera_node/color/camera_info:=/test/myrobot/realsense_camera/color/camera_info"
```

Puedes fijar ese remapeo editando `TOPIC_REMAPPINGS` en `docker_compose_base.yaml`.

La configuración de CycloneDDS usada en el ejemplo se define en `examples/cyclonedds_config.xml`.

La configuración de parámetros de la cámara se define en `examples/realsense_params.yaml`.
Ese fichero puede usar `$(var robot_prefix)` (por ejemplo en `camera_name`), y `sensor.launch.py` lo resuelve estableciendo `robot_prefix` en el contexto de ROS2 launch antes de arrancar el nodo.

Para ver todas las opciones disponibles:

```bash
./run_docker_container.sh -h
```
