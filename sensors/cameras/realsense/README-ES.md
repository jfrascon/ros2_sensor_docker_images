# RealSense ROS2 in Docker

La carpeta `realsense` contiene los ficheros necesarios para instalar los paquetes ROS2 para cámaras RealSense en varias distribuciones de ROS2, junto con sus dependencias, en una imagen Docker.
Tanto los paquetes ROS2 como la librería `librealsense2` se instalan desde código fuente, clonando sus repositorios oficiales.

Repositorios oficiales:
- Paquetes ROS2 RealSense: `https://github.com/realsenseai/realsense-ros`
- Libreria librealsense2: `https://github.com/realsenseai/librealsense`

Los scripts `setup.sh`, `install_librealsense2_from_source.sh` y `compile.sh` están diseñados para ser usados desde un `Dockerfile` y automatizar la construcción de la imagen.

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
bash /tmp/run_realsense_launch_in_terminal.sh
```

Este ejemplo también está preparado para ejecutar aplicaciones gráficas desde el contenedor (por ejemplo `rviz2` y `realsense-viewer`) y mostrarlas en el host mediante X11/XWayland. Ten en cuenta que `realsense-viewer` sólo estará disponible si `librealsense2` se compiló con `BUILD_EXAMPLES=ON` y `BUILD_GRAPHICAL_EXAMPLES=ON`.

El script `run_docker_container.sh` permite configurar variables mediante `--env KEY=VALUE`.

Variables con valor por defecto en este ejemplo:

- `NAMESPACE` (por defecto: vacío)
- `ROBOT_NAME` (por defecto: `robot`)
- `ROS_DOMAIN_ID` (por defecto: `11`)
- `NODE_OPTIONS` (por defecto: `name=realsense_camera,output=screen,emulate_tty=True,respawn=False,respawn_delay=0.0`)
- `LOGGING_OPTIONS` (por defecto: `log-level=info,disable-stdout-logs=true,disable-rosout-logs=false,disable-external-lib-logs=true`)

Las variables `NODE_OPTIONS` y `LOGGING_OPTIONS` son de tipo `kvs` (key-value-string), es decir, un string formado por pares `key=value` separados por comas.

Variables adicionales soportadas por el script:

- `ROS_LOCALHOST_ONLY=1|0` (ROS2 Humble y anteriores, sin valor por defecto)
- `ROS_AUTOMATIC_DISCOVERY_RANGE=LOCALHOST|SUBNET|OFF|SYSTEM_DEFAULT` (ROS2 Jazzy y posteriores, sin valor por defecto)
- `ROS_STATIC_PEERS='192.168.0.1;remote.com'` (ROS2 Jazzy y posteriores, sin valor por defecto)
- `TODO`: añadir documentación de `TOPIC_REMAPPINGS` cuando se complete su validación en pruebas.

Además, puedes pasar otras variables extra con `--env`; el script las reenvía al contenedor.

Hay variables que no se pueden configurar con `--env` en este flujo:

- `RMW_IMPLEMENTATION`: está fijada en `docker_compose_base.yaml` con `rmw_cyclonedds_cpp`. Este ejemplo usa CycloneDDS como middleware DDS. Si quieres cambiar de middleware, debes editar `docker_compose_base.yaml`.
- `CYCLONEDDS_URI`: está fijada en `docker_compose_base.yaml`.
- `PARAMS_FILE`: está fijada en `docker_compose_base.yaml`. Indica la ruta del fichero YAML con los parámetros de la cámara.
- `IMG_ID`: se toma del argumento posicional `<img_id>` del script. Identifica la imagen Docker que se va a ejecutar.
- `ENV_FILE`: lo gestiona internamente el propio script. Es el fichero temporal `.env` que `docker compose` carga mediante `env_file` (en `docker_compose_base.yaml`) para pasar variables de entorno al contenedor del servicio `realsense_srvc`.

La configuración de CycloneDDS usada en el ejemplo se define en el fichero `examples/cyclonedds_config.xml`. El middleware la carga mediante la variable `CYCLONEDDS_URI`, definida en `docker_compose_base.yaml`.

La configuración de parámetros de la cámara se define en el fichero `examples/realsense_params.yaml`. Si quieres cambiar perfiles, streams, `frame_id` o cualquier parámetro del nodo de `realsense2_camera`, edita ese fichero.

Ejemplo de ejecución con overrides:

```bash
./run_docker_container.sh realsense:humble automatic \
  --env ROBOT_NAME=robot1 \
  --env ROS_DOMAIN_ID=21 \
  --env ROS_LOCALHOST_ONLY=1
```

Para ver todas las opciones disponibles:

```bash
./run_docker_container.sh -h
```
