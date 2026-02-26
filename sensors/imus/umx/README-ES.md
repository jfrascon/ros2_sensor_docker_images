# UMX ROS2 en Docker

La carpeta `umx` contiene los ficheros necesarios para instalar los paquetes de ROS2 para IMUs CH Robotics UM6/UM7, junto con sus dependencias, en una imagen Docker.
Tanto los paquetes de ROS2 como la dependencia serial se instalan desde código fuente clonando sus repositorios oficiales.

Repositorios oficiales:
- Paquetes ROS2 de UM7/UM6: [https://github.com/ros-drivers/um7/tree/ros2](https://github.com/ros-drivers/um7/tree/ros2)
- Librería `serial-ros2`: [https://github.com/RoverRobotics-forks/serial-ros2](https://github.com/RoverRobotics-forks/serial-ros2)

Los scripts [`setup.sh`](setup.sh), [`compile.sh`](compile.sh) y [`sensor.launch.py`](sensor.launch.py) están diseñados para usarse desde un `Dockerfile` y automatizar la construcción de la imagen.

## Ejemplo de uso

Para ilustrar cómo usar los ficheros anteriores, se incluye un ejemplo en la carpeta `examples/`, donde hay un `Dockerfile` para construir una imagen que permite ejecutar los paquetes ROS2 de IMUs UM6/UM7 dentro de un contenedor Docker.

El proceso está pensado para que sea cómodo para el usuario: ejecuta [`examples/build.py`](examples/build.py) e indica la distro de ROS2 que quieres usar (`humble` o `jazzy`).

Ejemplo:
```bash
cd sensors/imus/umx/examples
./build.py jazzy
```

El script incluye flags opcionales que pueden ser útiles (por ejemplo, control de caché, pull de imagen base, metadatos o nombre de imagen). Para verlos:
```bash
./build.py -h
```

En `examples/`, el fichero [`refs.txt`](examples/refs.txt) define las referencias remotas (tags/ramas) que clona [`setup.sh`](setup.sh) para:
- `serial-ros2`
- `um7`
- `ros2_launch_helpers`

Formato esperado:
```txt
serial-ros2 master
um7 ros2
ros2_launch_helpers main
```

Una vez construida la imagen con [`examples/build.py`](examples/build.py), puedes iniciar el contenedor en dos modos usando [`examples/run_docker_container.sh`](examples/run_docker_container.sh):

- modo `automatic`: el contenedor arranca y ejecuta automáticamente el launch del driver ROS2.
- modo `manual`: el contenedor arranca sin lanzar el driver, para que puedas entrar a una shell y ejecutarlo manualmente.

Nota sobre el alcance de estos ficheros de ejemplo:
- [`run_docker_container.sh`](examples/run_docker_container.sh) y los compose fragmentados ([`docker_compose_mode_automatic.yaml`](examples/docker_compose_mode_automatic.yaml), [`docker_compose_mode_manual.yaml`](examples/docker_compose_mode_manual.yaml), [`docker_compose_gui.yaml`](examples/docker_compose_gui.yaml)) están orientados a facilitar pruebas y experimentación.
- En un despliegue de producción, lo habitual es definir un único `docker compose` propio con la configuración del sensor, el comando de arranque y, si aplica, la parte de GUI.
- En ese caso no es necesario usar [`run_docker_container.sh`](examples/run_docker_container.sh) ni separar la configuración en modos `automatic/manual/gui`.

El script solo recibe argumentos posicionales:
- `<img_id>`
- `<mode>` (`automatic` o `manual`)

Los parámetros de UMX se seleccionan en [`examples/docker_compose_base.yaml`](examples/docker_compose_base.yaml):
- Por defecto (ya activo): [`um7_params.yaml`](examples/um7_params.yaml).
- Alternativa: descomentar [`um6_params.yaml`](examples/um6_params.yaml) y comentar la línea de `um7`.

Ejemplo (si construiste con `./build.py jazzy`, el `img_id` por defecto es `umx:jazzy`):

```bash
cd sensors/imus/umx/examples
./run_docker_container.sh umx:jazzy automatic
```

Si prefieres modo manual (UM6 como ejemplo):

```bash
cd sensors/imus/umx/examples
# En docker_compose_base.yaml:
# - comentar la línea de volumen de um7_params
# - descomentar la línea de volumen de um6_params
# - fijar UM_MODEL a \"6\"
# - ajustar TOPIC_REMAPPINGS para usar tópicos um6/...
./run_docker_container.sh umx:jazzy manual
docker compose exec -it umx_srvc bash
ros2 launch umx_bringup sensor.launch.py
```

El flujo de GUI es automático:
- Si `DISPLAY` está definido en el host, [`run_docker_container.sh`](examples/run_docker_container.sh) añade [`docker_compose_gui.yaml`](examples/docker_compose_gui.yaml) y ejecuta `xhost +local:`.
- Si `DISPLAY` no está definido, el contenedor arranca en modo headless (sin montaje de X11).

Las variables de entorno de ejecución están definidas en [`examples/docker_compose_base.yaml`](examples/docker_compose_base.yaml), en la sección `environment`.
En particular, [`sensor.launch.py`](sensor.launch.py) usa:
- `ROBOT_NAME` (obligatoria para el launch)
- `PARAMS_FILE` (obligatoria para el launch; fijada a `/tmp/params.yaml` en compose)
- `NAMESPACE` (opcional)
- `UM_MODEL` (opcional, por defecto `7`, valores permitidos: `6` o `7`)
- `TOPIC_REMAPPINGS` (opcional, string de remapeo `OLD:=NEW,OLD:=NEW,...`)
- `NODE_OPTIONS` (opcional, formato `kvs`: `key=value,key=value,...`)
- `LOGGING_OPTIONS` (opcional, formato `kvs`: `key=value,key=value,...`)

Otras variables usadas en este ejemplo:
- `ROS_DOMAIN_ID`
- `RMW_IMPLEMENTATION` (fijada a `rmw_cyclonedds_cpp`)
- `CYCLONEDDS_URI` (fijada a [`examples/cyclonedds_config.xml`](examples/cyclonedds_config.xml))

La configuración de CycloneDDS usada en este ejemplo está definida en [`examples/cyclonedds_config.xml`](examples/cyclonedds_config.xml).

La configuración de parámetros por modelo UM está definida en:
- [`examples/um6_params.yaml`](examples/um6_params.yaml)
- [`examples/um7_params.yaml`](examples/um7_params.yaml)

Para ver todas las opciones disponibles:

```bash
./run_docker_container.sh -h
```

Para más información sobre configuración del sensor y el proyecto del driver:
- [https://github.com/ros-drivers/um7/tree/ros2](https://github.com/ros-drivers/um7/tree/ros2)
- [https://github.com/RoverRobotics-forks/serial-ros2](https://github.com/RoverRobotics-forks/serial-ros2)
