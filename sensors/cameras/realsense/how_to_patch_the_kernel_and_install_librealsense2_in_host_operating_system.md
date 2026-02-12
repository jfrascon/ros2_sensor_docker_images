<p align="center">
  ROS Wrapper for RealSense(TM) Cameras<br>
  <a href="https://github.com/IntelRealSense/realsense-ros/releases">Latest release notes</a>
</p>

Esta guía está escrita con el objetivo de describir las opciones disponibles para el uso de una cámara RealSense en ROS2 dentro de un contenedor Docker, que se ejecuta en una máquina con arquitectura x86_64 (verifiable con el comando `uname -a`) y sistema operativo host Ubuntu, de version variada, podría ser LTS (20.04, 22.04, 24.04, otras versiones a futuro) o no LTS.

> **Nota:**<br/>
> Por **sistema operativo host** me refiero al sistema operativo instalado en la máquina física (**host**) donde se ejecuta el contenedor Docker. Tu máquina (**host**) puede ser un ordenador de sobremesa, un portátil, un mini-PC como un NUC, etc.

Creo que hay usuarios que usan como sistema operativo host CentOs, Debian, Windows, MacOS, etc, pero esta guía no cubre esos casos.
En esta guía no cubro aspectos relacionados con los dispositivos **Jetson**, por lo que no entraré en detalles sobre los pasos que en las guías oficiales se indican para estos dispositivos, como
el paso 2, opción 1, Jetson users - use the [Jetson Installation Guide](https://github.com/IntelRealSense/librealsense/blob/master/doc/installation_jetson.md), que aparecerá más adelante en la guía.

Se considera que dispones de un Dockerfile que tiene soporte para ROS2, bien porque uses una imagen base oficial de ROS2, o una imagen base en la que ROS2 ya está instalado o bien tengas instrucciones en el Dockerfile para instalar ROS2. La guía no fija como requisitos una versión específica de ROS2 y por lo tanto no fija tampoco como requisito una versión específica de la versión del sistema operativo Ubuntu subyacente instalada en la imagen Docker, tan sólo que la versión de ROS2 que uses sea compatible con la versión de Ubuntu que tengas en la imagen Docker.

Antes de entrar en materia, una idea clave a recordar es que **un contenedor no tiene su propio kernel, sino que utiliza el kernel del host donde se ejecuta.** Volveremos a esta idea más adelante, durante la explicación de las opciones disponibles.

En esta guía muestro fragmentos de ficheros Markdown y scripts alojados en los repositorios [https://github.com/realsenseai/realsense-ros](https://github.com/realsenseai/realsense-ros) y [https://github.com/realsenseai/librealsense.git](https://github.com/realsenseai/librealsense.git) a fecha de febrero de 2026. Es posible que para cuando leas esta guía, los repositorios hayan cambiado, por lo que es recomendable que verifiques la información en los repositorios oficiales.

La URL [https://github.com/realsenseai/realsense-ros/blob/ros2-master/README.md](https://github.com/realsenseai/realsense-ros/blob/ros2-master/README.md) es el punto de entrada cuando uno quiere usar una cámara RealSense en ROS2.

De lo primero que te vas a encontrar en el fichero [README.md](https://github.com/realsenseai/realsense-ros/blob/ros2-master/README.md) del repositorio `realsense-ros` es un bloque de texto con el título `Installation on Ubuntu` donde se describen tres pasos para la instalación del software necesario para usar una cámara RealSense en ROS2, y cada paso tiene varias opciones. El bloque de texto es el siguiente:

---
# Installation on Ubuntu

<details>
  <summary>
    Step 1: Install the ROS2 distribution
  </summary>

  `<Texto original omitido>`
</details>

<details>
  <summary>
    Step 2: Install latest RealSense&trade; SDK 2.0
  </summary>

  **Please choose only one option from the 3 options below (in order to prevent multiple versions installation and workspace conflicts)**

- #### Option 1: Install librealsense2 debian package from RealSense servers

  - Jetson users - use the [Jetson Installation Guide](https://github.com/IntelRealSense/librealsense/blob/master/doc/installation_jetson.md)
  - Otherwise, install from [Linux Debian Installation Guide](https://github.com/IntelRealSense/librealsense/blob/master/doc/distribution_linux.md#installing-the-packages)
    - In this case treat yourself as a developer: make sure to follow the instructions to also install librealsense2-dev and librealsense2-dkms packages

- #### Option 2: Install librealsense2 (without graphical tools and examples) debian package from ROS servers (Foxy EOL distro is not supported by this option):

  - [Configure](http://wiki.ros.org/Installation/Ubuntu/Sources) your Ubuntu repositories
  - Install all realsense ROS packages by ```sudo apt install ros-<ROS_DISTRO>-librealsense2*```
    - For example, for Humble distro: ```sudo apt install ros-humble-librealsense2*```

- #### Option 3: Build from source

  - Download the latest [RealSense&trade; SDK 2.0](https://github.com/IntelRealSense/librealsense)
  - Follow the instructions under [Linux Installation](https://github.com/IntelRealSense/librealsense/blob/master/doc/installation.md)

</details>

<details>
  <summary>
    Step 3: Install ROS Wrapper for RealSense&trade; cameras
  </summary>

  #### Option 1: Install debian package from ROS servers (Foxy EOL distro is not supported by this option):
  `<Texto original omitido>`
...

#### Option 2: Install from source
  `<Texto original omitido>`
  </details>

---

Si inspeccionas los tres pasos anteriores, sólo he dejado el texto original en el paso 2, `Install latest RealSense&trade; SDK 2.0`, porque es el paso que en mi opinión requiere más explicación.

En primer lugar, quiero indicar que la guía de instalación presente en la URL [https://github.com/realsenseai/realsense-ros/blob/ros2-master/README.md](https://github.com/realsenseai/realsense-ros/blob/ros2-master/README.md), en mi opinión, está escrita para un usuario que va a instalar todo el software en el sistema operativo host. Por lo tanto, la guía oficial no ofrece una explicación específica de qué software instalar en el sistema operativo host y qué software instalar en una imagen de Docker. Y es precisamente esta cuestión, distinguir qué instalar en el sistema operativo host y qué instalar en la imagen de Docker la que quiero aclarar en esta guía.

Es cierto que en la URL [https://github.com/realsenseai/librealsense/blob/master/scripts/Docker/readme.md](https://github.com/realsenseai/librealsense/blob/master/scripts/Docker/readme.md) puedes encontrar un guía de instalación de la librería `librealsense2` en un Dockerfile, pero, de nuevo en mi opinión (esta es una frase que usaré mucho durante la guía) presenta algunas inconsistencias a juzgar por el contenido que podrás leer en el resto de esta guía. Cuando finalices la lectura de esta guía, te recomiendo que vuelvas a leer la URL [https://github.com/realsenseai/librealsense/blob/master/scripts/Docker/readme.md](https://github.com/realsenseai/librealsense/blob/master/scripts/Docker/readme.md) y compares ambas guías.

Cuando fijes la vista sobre el paso 2, es posible que tu atención se vaya directamente hacia la opción 2,  `Install librealsense2 (without graphical tools and examples) debian package from ROS servers (Foxy EOL distro is not supported by this option)` porque hay un patrón que conoces. En la opción 2 reconocerás un patrón que seguramente te resultará familiar, `sudo apt install ros-${ROS_DISTRO}-librealsense2*`, y que habitualmente escribes en Dockerfiles para instalar paquetes de ROS2 en una imagen de Docker. Si no lees la opción 1 y la opción 3, seguramente pensarás '*¡Perfecto! Ya sé qué hacer, en el Dockerfile escribo `sudo apt-get install -y ros-${ROS_DISTRO}-librealsense2*` y listo.*' Pero, si te tomas la molestia de leer el paso 1 y el paso 3, es posible que te surjan dudas porque no comprendas cómo se relacionan las tres opciones entre sí, cuál es la más adecuada para tu caso, y qué debes instalar en el host y qué debes instalar en la imagen de Docker, entre otras.

Si pinchas en el enlace [Linux Debian Installation Guide](https://github.com/IntelRealSense/librealsense/blob/master/doc/distribution_linux.md#installing-the-packages), del paso 2, opción 1, acabarás leyendo un fichero de nombre [distribution_linux.md](https://github.com/IntelRealSense/librealsense/blob/master/doc/distribution_linux.md). Cuando leas este fichero, es posible que como me pasó a mi ya te empiecen a surgir las dudas, porque el tono del documento denota que se está hablando de la instalación de software en el sistema operativo host, no en una imagen de Docker. Y ¿por qué digo que el tono denota que se está hablando de la instalación en el host? Porque de las primeras líneas del fichero [distribution_linux.md](https://github.com/IntelRealSense/librealsense/blob/master/doc/distribution_linux.md) se puede leer:

> The Realsense [DKMS](https://en.wikipedia.org/wiki/Dynamic_Kernel_Module_Support) kernel drivers package (`librealsense2-dkms`) supports Ubuntu LTS HWE kernels 5.15, 5.19 and 6.5. Please refer to [Ubuntu Kernel Release Schedule](https://wiki.ubuntu.com/Kernel/Support) for further details.
>
> #### Configuring and building from the source code
>
> While we strongly recommend to use DKMS package whenever possible, there are certain cases where installing and patching the system manually is necessary:
>
> - Using SDK with non-LTS Ubuntu kernel versions
> - Integration of user-specific patches/modules with `librealsense` SDK.
> - Adjusting the patches for alternative kernels/distributions.
>
> The steps are described in [Linux manual installation guide](https://github.com/IntelRealSense/librealsense/blob/master/doc/installation.md)

Es posible que sepas que los paquetes DKMS gestionan el **soporte dinámico del kernel**. Esto significa que, en lugar de instalar un driver estático, el sistema utiliza el código fuente para generar un módulo a medida de tu versión actual de Linux, evitando así que las actualizaciones de sistema rompan la compatibilidad con el hardware. Su función principal es garantizar que, ante cualquier actualización del kernel, el driver se reconstruya automáticamente para mantenerse siempre operativo. No obstante, para que este proceso de re-compilación tenga éxito, es indispensable que el sistema cuente con los `linux-headers` (cabeceras de Linux) correspondientes a tu versión del núcleo instalada.

Ya sólo la aparición del sufijo `-dkms` en el nombre del paquete `librealsense2-dkms` te debe hacer sospechar que el documento [distribution-linux.md](https://github.com/IntelRealSense/librealsense/blob/master/doc/distribution_linux.md) habla de la instalación de software en el sistema operativo host, porque los módulos del kernel se instalan en el sistema operativo host, no en una imagen de Docker.

En este punto, considero que es importante darte un poco de contexto sobre los APIs de comunicación que puede usar la librería `librealsense2` en Linux. La información que te expondré a continuación se encuentra enterrada entre las URLs que he ido poniendo anteriormente, pero creo que es importante que la tengas clara para entender las opciones que tienes disponibles.

La librería **librealsense2** puede comunicarse con cámaras RealSense en Linux de dos formas. A lo largo del documento llamaremos a estas formas *backends*.

1. **Modo estándar del sistema** (también llamado *backend nativo del kernel*): usa los controladores estándar de Linux ya presentes en el sistema. **Esto significa que `librealsense2` no trae su propia implementación de vídeo o sensores**, sino que se apoya en los mismos drivers que usaría cualquier otra aplicación Linux.
   Para el vídeo, el estándar es **UVC (USB Video Class)**, y en Linux lo implementa **Video4Linux (V4L2)**.
   Para la IMU, el estándar es **HID (Human Interface Device)**, y en Linux lo implementa **IIO (Industrial I/O)**.
   El transporte común para ambos es **USB**.
2. **Backend RS-USB (en espacio de usuario)**: aquí **`librealsense2`** reimplementa UVC e HID dentro del propio SDK y se activa con el flag `-DFORCE_RSUSB_BACKEND` (en versiones anteriores a la v2.30 se llamaba `-DFORCE_LIBUVC`). Al estar en espacio de usuario, la lógica vive en la propia librería y no en los módulos del kernel.

Cuando se elige **RS-USB**, `librealsense2` se comunica con la cámara usando el controlador USB estándar, y la interpretación del vídeo (**UVC**) y de la IMU (**HID**) ocurre íntegramente en **user-space**, sin depender de los controladores nativos del sistema operativo host.

En general, el backend nativo del kernel es el camino estándar y suele ser la primera opción en Linux, especialmente en **entornos de producción** (como recomienda RealSense). El backend RS-USB se usa cuando necesitas evitar dependencias del kernel, probar en entornos donde los drivers no están disponibles, o reproducir un comportamiento consistente entre distintos sistemas.

| Aspecto | Backend nativo (kernel) | Backend RS-USB (user-space) |
|---|---|---|
| Dónde vive la lógica UVC/HID | En el kernel de Linux | En la librería `librealsense2` |
| Controladores usados | V4L2, IIO y USB del kernel | Implementación propia de RS-USB |
| Cómo se activa | Por defecto | `-DFORCE_RSUSB_BACKEND` |
| Ventaja principal | Integración estándar con Linux | Independencia de drivers del kernel |
| Casos típicos | Entornos de producción en Linux | Entornos sin drivers adecuados o con necesidades específicas |

Actualmente, los dos backends son mutuamente excluyentes.

**Como regla general, se recomienda usar los controladores nativos (modificados) del kernel, especialmente en entornos de producción. RS‑USB es una alternativa válida y funcional, pero no ofrece todas las funciones y su rendimiento es menor.**

**¿Cuál es el dilema?**

Para obtener el uso más eficiente de los dispositivos RealSense, se deben aplicar ciertas modificaciones en los módulos del kernel del sistema operativo host. Estas modificaciones bien pueden hacerse instalando el paquete `librealsense2-dkms` desde el repositorio oficial de paquetes de RealSense o bien compilando e instalando manualmente los módulos del kernel, si tu kernel es soportado. En ambos casos, se está modificando el sistema operativo host.

En el siguiente [issue de GitHub](https://github.com/realsenseai/librealsense/issues/5212) puedes leer una conversación interesante donde se trata de este dilema. A continuación reproduzco un comentario de la conversación indicada, del usuario [@ev-mp](https://github.com/realsenseai/librealsense/issues/5212#issuecomment-552184604), que es desarrollador del equipo RealSense, donde explica las ventajas/desventajas de cada API.

Texto literal del issue:

> RS-USB advantages:
>
> - Cross-platform (at least for Linux & MacOS).
> - User-space UVC implementation :
>   - No kernel patches required
>   - Easily to deploy (gcc + libusb dependencies only) - thus is the preferred choice of Librealsense for ARM/Jetsons/Mac platforms
>   - Easier to Debug
>
> RS-USB disadvantages:
>
> - No official support/maintainers.
> - Most of the implementation is build around UVC 1.1, while most contemporary cameras (including realsense) are UVC 1.5 devices
> - User-space UVC implementation:
>   - Power-management - In case an application crushes/get stuck the the underlying device is not being released and continues to run in orphan mode. This may require manual re-plugging to recover (reliability).
>   - Single Consumer - most kernel drivers (Linux/Windows) allow to connect and communicate with device from multiple processes (except for streaming). With RS-USB only one application can get device handle. This is one of the limitations for multicam on MacOS, for instance. There are attempts to address this by community enthusiasts, so this may change one day.
>
> Kernel patches advantages:
>
> - Kernels are fast and (mostly) stable. Adding patched modules into kernel tree in controlled and pier-reviewed manner allows to get most of the benefits and also get the additional features.
> - All kernel patches should eventually get upstreamed into Linux or abandoned,
>   **From the user's perspective the main obstacle in accepting the kernel patch model is the deployment scheme that requires certain engineering skills level**.
>   **WE ADDRESS THIS BY WRAPPING AND REDISTRIBUTING THE PATCHES WITH DKMS DEBIAN PACKAGE, AT LEAST FOR UBUNTU LTS KERNELS**.

He remarcado algunas frases clave en negrita.

En este otro [issue de GitHub](https://github.com/realsenseai/librealsense/issues/5315#issuecomment-559054292) el usuario `iban-rodriguez` expone sus conclusiones sobre el uso de RS-USB vs kernel patches:

> Hi @dorodnic
>
> Yes, we tried the Debian packages 2-3 weeks ago more or less and also compiled the last version of the library forcing RS-USB, and we decided to go on patching the kernel and using V4L2 backend because we found other issues we couldn't overcome:
>
> - CPU usage is greater for the same channels/fps requested when using libuvc instead of V4L2. We tested it on PC and verified after on Jetson when V4L2 worked.
> - Impossible to get 30 FPS on Jetson TX2 when requesting RGB, depth and IR streams simultaneously. CPU goes quite up and resulting FPS never goes higher than 22.
> - Camera open failure when tried to open it more than twice. This is the most serious issue as it requires unplugging and plugging camera again to make it usable
>
> All these issues have disappeared using V4L2 backend, being the only problem the reported in this ticket.

Referencias:

- Las URLs indicadas explicitas en el texto.
- https://docs.ros.org/en/iron/p/librealsense2/user_docs/installation_jetson.html
- https://github.com/realsenseai/librealsense/issues/9157
- https://github.com/realsenseai/librealsense/issues/5212
- https://github.com/realsenseai/librealsense/issues/5212#issuecomment-552184604
- https://github.com/realsenseai/librealsense/issues/5315
- https://github.com/realsenseai/librealsense/issues/5315#issuecomment-559054292

Ahora que ya conoces los dos mecanismos de comunicación que puede usar la librería `librealsense2`, quiero hacer algunas aclaraciones sobre el bloque de texto siguiente, extraído de la URL [https://github.com/IntelRealSense/librealsense/blob/master/doc/distribution_linux.md](https://github.com/IntelRealSense/librealsense/blob/master/doc/distribution_linux.md):

> The Realsense [DKMS](https://en.wikipedia.org/wiki/Dynamic_Kernel_Module_Support) kernel drivers package (`librealsense2-dkms`) supports Ubuntu LTS HWE kernels 5.15, 5.19 and 6.5. Please refer to [Ubuntu Kernel Release Schedule](https://wiki.ubuntu.com/Kernel/Support) for further details.

El texto mostrado no lista todos los kernels que puede modificar el paquete `librealsense2-dkms`, alojado en el servidor de paquetes de RealSense, para una distribución Ubuntu LTS en particular; se han dejado algunos kernels por especificar. El texto debería listar también los kernel 5.4, 5.8, 5.11, 5.13, 6.2, y 6.8 para la última versión estable (no beta) de la librería `librealsense2`, `v2.56.5`, a fecha de febrero de 2026. Te daré mas información sobre los paquetes `librealsense2-dkms` más adelante en la guía. Sospecho, por esta omisión en este fichero y otras que se dan en otros ficheros relacionados, que el equipo de RealSense no actualiza toda la documentación cuando añaden soporte para nuevos kernels en los paquetes `librealsense2-dkms` (o se les ha pasado).

Por otro lado, el texto siguiente es completamente **ERRÓNEO**:

> #### Configuring and building from the source code
>
> While we strongly recommend to use DKMS package whenever possible, there are certain cases where installing and patching the system manually is necessary:
>
> - Using SDK with non-LTS Ubuntu kernel versions
> - Integration of user-specific patches/modules with `librealsense` SDK.
> - Adjusting the patches for alternative kernels/distributions.
>
> The steps are described in [Linux manual installation guide](https://github.com/IntelRealSense/librealsense/blob/master/doc/installation.md)

En la primera línea dice, **si tienes una version de Ubuntu no-LTS, entonces debes instalar y parchear manualmente el sistema operativo host**, y te indica que los pasos para realizar esta instalación manual se encuentran en la URL [Linux manual installation guide](https://github.com/IntelRealSense/librealsense/blob/master/doc/installation.md) (fichero [installation.md](https://github.com/IntelRealSense/librealsense/blob/master/doc/installation.md))

---
Te doy la conclusión ahora y te demuestro a continuación:

**Si tienes una versión de Ubuntu no-LTS, NO PUEDES USAR EL CÓDIGO FUENTE PARA PARCHEAR MANUALMENTE EL SISTEMA OPERATIVO HOST, porque RealSense únicamente permite parchear el kernel de forma manual si usas distribuciones LTS de Ubuntu (y es preferible usar versiones de Ubuntu LTS desde 20.04 en adelante: 20.04, 22.04, 24.04, otras a futuro).**

Si usas una versión de Ubuntu no-LTS, la única opción que tienes es usar el enfoque **RS-USB**, ya que no puedes instalar el paquete `librealsense2-dkms` disponible en el servidor de paquetes de RealSense, porque este paquete sólo está disponible para versiones LTS de Ubuntu, y no puedes parchear manualmente el sistema operativo host usando el código fuente del repositorio de [librealsense](https://github.com/realsenseai/librealsense) porque RealSense únicamente permite parchear el kernel de forma manual si usas distribuciones LTS de Ubuntu. Hablaré más adelante sobre el enfoque **RS-USB**.

---

Para seguir con la demostración, si acudes al enlace [Linux manual installation guide](https://github.com/IntelRealSense/librealsense/blob/master/doc/installation.md) (fichero [installation.md](https://github.com/IntelRealSense/librealsense/blob/master/doc/installation.md)) leerás:

> ## Prerequisites
>
> Supported versions are:  **Ubuntu 20/22/24 LTS** versions.

Leíste en el fichero [distribution_linux.md](https://github.com/IntelRealSense/librealsense/blob/master/doc/distribution_linux.md) que si usas una versión de Ubuntu no-LTS, debes instalar y parchear manualmente el sistema operativo host, y que fueras al fichero [installation.md](https://github.com/IntelRealSense/librealsense/blob/master/doc/installation.md) para encontrar más explicaciones, y resulta que ahora en el fichero [installation.md](https://github.com/IntelRealSense/librealsense/blob/master/doc/installation.md) te dicen que sólo se soportan versiones LTS de Ubuntu. Así que es posible que te sientas un poco confundido. Quiero que avances en el fichero [installation.md](https://github.com/IntelRealSense/librealsense/blob/master/doc/installation.md) hasta que veas las líneas:

> 3. Build and apply patched kernel modules for:
>     * Ubuntu 20/22/24 (focal/jammy/noble) with LTS kernel 5.15, 5.19, 6.5, 6.8, 6.11, 6.14 \
>      `./scripts/patch-realsense-ubuntu-lts-hwe.sh`

De nuevo, sólo se mencionan versiones LTS de Ubuntu. Ahora también se mencionan más kernels soportados si sigues el proceso de parcheo manual del sistema operativo host. Pero que el texto del fichero [installation.md](https://github.com/IntelRealSense/librealsense/blob/master/doc/installation.md) diga que soporta únicamente versiones LTS de Ubuntu no es una prueba concluyente de que no se pueda parchear manualmente una versión de Ubuntu no-LTS, al fin y al cabo el fichero [distribution_linux.md](https://github.com/IntelRealSense/librealsense/blob/master/doc/distribution_linux.md) dice que sí se puede parchear manualmente una versión de Ubuntu no-LTS, podrían ser errores en la documentación.

La prueba definitiva de la conclusión que te he dado antes la encuentras investigando el código fuente del fichero `patch-realsense-ubuntu-lts-hwe.sh`. Allí se ejecuta la función `choose_kernel_branch`, cuyo código fuente se encuentra en el fichero `patch-utils-hwe.sh`.

**ESTA ES LA DEMOSTRACIÓN ->** La función `choose_kernel_branch` únicamente contempla versiones LTS de Ubuntu, eso sí, varios kernels dentro de cada versión LTS. A continuación, escribo la función [choose_kernel_branch](https://github.com/realsenseai/librealsense/blob/v2.57.6/scripts/patch-utils-hwe.sh#L26) tal cual aparece en la última versión beta de la librerería `librealsense2`, `v2.57.6`, a fecha de febrero de 2026.

```bash
#Ubuntu focal repo : https://kernel.ubuntu.com/git/ubuntu/ubuntu-focal.git/
#	Branch		Commit message
#	master		UBUNTU: Ubuntu-5.4.0-21.25
function choose_kernel_branch {

   # Split the kernel version string
   IFS='.' read -a kernel_version <<< "$1"

   if [ "$2" == "focal" ]; 				# Ubuntu 20
   then
      case "${kernel_version[0]}.${kernel_version[1]}" in
      "5.4")									# kernel 5.4
         echo master
         ;;
      "5.8")									# kernel 5.8
         echo hwe-5.8
         ;;
      "5.11")									# kernel 5.11
         echo hwe-5.11
         ;;
      "5.13")
         echo hwe-5.13
         ;;
      "5.15")
         echo hwe-5.15
         ;;
      *)
         #error message shall be redirected to stderr to be printed properly
         echo -e "\e[31mUnsupported kernel version $1 . The Focal patches are maintained for Ubuntu LTS with kernel 5.4, 5.8, 5.11 only\e[0m" >&2
         exit 1
         ;;
      esac
   elif [ "$2" == "jammy" ]; 				# Ubuntu 22
   then
      case "${kernel_version[0]}.${kernel_version[1]}" in
      "5.15")
         echo hwe-5.15
         ;;
      "5.19")
         echo hwe-5.19
         ;;
      "6.2")
         echo hwe-6.2
         ;;
      "6.5")
         echo hwe-6.5
         ;;
      "6.8")
         echo hwe-6.8
         ;;
      *)
         #error message shall be redirected to stderr to be printed properly
         echo -e "\e[31mUnsupported kernel version $1 . The Jammy patches are maintained for Ubuntu LTS with kernel 5.15, 5.19 only\e[0m" >&2
         exit 1
         ;;
      esac
   elif [ "$2" == "noble" ]; 				# Ubuntu 24
   then
      case "${kernel_version[0]}.${kernel_version[1]}" in
      "6.8")
         echo hwe-6.8
         ;;
      "6.11")
         echo hwe-6.11
         ;;
      "6.14")
         echo hwe-6.14
         ;;
      *)
         #error message shall be redirected to stderr to be printed properly
         echo -e "\e[31mUnsupported kernel version $1 . The Noble patches are maintained for Ubuntu LTS with kernel 6.8, 6.11, 6.14 only\e[0m" >&2
         exit 1
         ;;
      esac
   else
      echo -e "\e[31mUnsupported distribution $2, kernel version $1 . The patches are maintained for Ubuntu 20/22/24 LTS\e[0m" >&2
      exit 1
   fi
}
```

Haré un resumen:

Si se quiere modificar los controladores del kernel del sistema operativo host para tener la comunicación más eficiente entre la máquina host y la cámara RealSense **sólo se puede hacer si el sistema operativo host es una versión LTS de Ubuntu (20.04, 22.04, 24.04, otras a futuro)**. Si el sistema operativo host es un Ubuntu no-LTS, la única opción disponible es usar el enfoque **RS-USB**, que no requiere modificar los controladores del kernel del sistema operativo host, pero que tiene limitaciones funcionales y de rendimiento.
Aunque la versión del sistema operativo host sea una versión LTS de Ubuntu (20.04, 22.04, 24.04, otras a futuro), es posible que no puedas instalar con éxito en el sistema operativo host el paquete `librealsense2-dkms`, disponible en el servidor de paquetes de RealSense, porque la versión del kernel del sistema operativo host no sea exactamente la misma que aquella para la que se ha creado el paquete `librealsense2-dkms`. En este caso, tendrás que parchear manualmente el sistema operativo host usando el código fuente del repositorio de [librealsense](https://github.com/realsenseai/librealsense). Pero esto te lo cuento más en detalle a continuación.

LLegados a este punto, es posible que ya te hayas dado cuenta de la importancia de distinguir qué software instalar en el sistema operativo host y qué software instalar en la imagen de Docker.

Ya estamos en disposición de especificar qué instalar en el host y qué instalar en la imagen de Docker.

Los dos opciones disponibles son:

1. **Opción A: Modificar los controladores del kernel del sistema operativo host para tener la comunicación más eficiente con la cámara RealSense.**
2. **Opción B: Usar el enfoque RS-USB, que no requiere modificar los controladores del kernel del sistema operativo host, pero que tiene limitaciones funcionales y de rendimiento.**

Si esta es tu primera vez leyendo esta guía, te recomiendo que la leas completa, incluso aunque quieras seguir la opción B, ya que durante la explicación de la opción A, se explican detalles importantes que conviene conocer aunque finalmente optes por la opción B.

## Opción A: Modificar los controladores del kernel del sistema operativo host para tener la comunicación más eficiente con la cámara RealSense

Esta opción sólo es posible si el sistema operativo host es una versión LTS de Ubuntu (20.04, 22.04, 24.04, otras a futuro). Si el sistema operativo host es un Ubuntu no-LTS, debes usar la opción B.

### Paso 1: Modificar los controladores del kernel del sistema operativo host

A continuación, deberás seguir o la opción A.1.1 o la opción A.1.2, sólo una de las dos. Después de ejecutar una de las dos opciones, continúa ejecutando las pasos siguientes de la opción A.

La opción A.1.1 es más sencilla, pero puede que no funcione en tu sistema operativo host. Encontrarás más detalles sobre cómo verificar si la opción A.1.1 funciona en tu sistema operativo host en breve. Si ejecutas la opción A.1.1 y no funciona, entonces deberás ejecutar la opción A.1.2.
Puedes ir directamente a la opción A.1.2 si lo prefieres. La opción A.1.2 se debe ejecutar si la opción A.1.1 no funciona en tu sistema operativo host o si prefieres tener más control sobre el proceso de parcheo del sistema operativo host.

Si optas por la ejecución de la opción A.1.1 y falla, ejecuta la opción A.1.2, y si también falla, entonces no te queda más opción que usar la opción B.<br/>
Si optas por la ejecución de la opción A.1.2 directamente y falla, entonces, de nuevo, no te queda más opción que usar la opción B (Podrías probar la opción A.1.1, tras el fallo de ejecución de la opción A.1.2, pero lo más probable es que si la opción A.1.2 ha fallado, la opción A.1.1 también falle).

#### Opción A.1.1: Instalar el paquete librealsense2-dkms en el sistema operativo host desde el repositorios oficial de paquetes de RealSense

**Advertencia**<br/>
Aunque el paquete `librealsense2-dkms` esté disponible en el repositorio oficial de paquetes de RealSense para la versión Ubuntu LTS que tengas instalada en el sistema operativo host, es posible que **no puedas instalarlo con éxito**, porque la versión del kernel del sistema operativo host no sea exactamente la misma que aquella para la que se ha creado el paquete `librealsense2-dkms`. En este caso, deberás usar la opción A.2, parchear manualmente el sistema operativo host usando el código fuente del repositorio de [librealsense](https://github.com/realsenseai/librealsense). Sigue leyendo para más detalles.

```bash
# Ensure the directory exists
sudo mkdir -p /etc/apt/keyrings

# Download and dearmor
curl -sSf https://librealsense.realsenseai.com/Debian/librealsenseai.asc | gpg --dearmor | sudo tee /etc/apt/keyrings/librealsenseai.gpg > /dev/null

# Make sure apt HTTPS support is installed:
sudo apt-get install -y apt-transport-https

# Add the server to the list of repositories:
echo "deb [signed-by=/etc/apt/keyrings/librealsenseai.gpg] https://librealsense.realsenseai.com/Debian/apt-repo $(source /etc/os-release && echo ${VERSION_CODENAME}) main" | sudo tee /etc/apt/sources.list.d/librealsense.list

sudo apt-get update
```

El comando `sudo apt-get update` fallará si has ejecutado los pasos anteriores en un sistema operativo host Ubuntu no-LTS, porque el repositorio indicado en la línea `echo "deb [signed-by=/etc/apt/keyrings/librealsenseai.gpg] https://librealsense.realsenseai.com/Debian/apt-repo $(source /etc/os-release && echo ${VERSION_CODENAME}) main" | sudo tee /etc/apt/sources.list.d/librealsense.list` no tiene paquetes para la versión no-LTS de Ubuntu indicada por el comando `$(source /etc/os-release && echo ${VERSION_CODENAME})`.

El fallo que obtendrás será similar a este:

```bash
E: Failed to fetch https://librealsense.realsenseai.com/Debian/apt-repo/dists/<UBUNTU_NO_LTS_CODENAME>/InRelease
E: The repository 'https://librealsense.realsenseai.com/Debian/apt-repo <UBUNTU_NO_LTS_CODENAME> InRelease' is not signed.
N: Updating from such a repository can't be done securely, and is therefore disabled by default.
N: See apt-secure(8) manpage for repository creation and user configuration details.
```

Si el comando `sudo apt-get update` se ejecuta con éxito, sólo para estar seguros verificaremos que el paquete `librealsense2-dkms` está disponible para la versión LTS de Ubuntu que tengas instalada en el sistema operativo host, ejecutando el comando:

```bash
apt-cache policy librealsense2-dkms
```

A modo de ejemplo, si tienes Ubuntu 22.04 LTS instalado en el sistema operativo host, el comando anterior debería mostrar una salida similar a esta:

```bash
apt-cache policy librealsense2-dkms
    librealsense2-dkms:
      Installed: (none)
      Candidate: 1.3.28-0ubuntu1
      Version table:
         1.3.28-0ubuntu1 500
            500 https://librealsense.realsenseai.com/Debian/apt-repo jammy/main amd64 Packages
         1.3.27-0ubuntu1 500
            500 https://librealsense.realsenseai.com/Debian/apt-repo jammy/main amd64 Packages
         1.3.26-0ubuntu1 500
            500 https://librealsense.realsenseai.com/Debian/apt-repo jammy/main amd64 Packages
         1.3.24-0ubuntu1 500
            500 https://librealsense.realsenseai.com/Debian/apt-repo jammy/main amd64 Packages
         1.3.22-0ubuntu1 500
            500 https://librealsense.realsenseai.com/Debian/apt-repo jammy/main amd64 Packages
         1.3.19-0ubuntu1 500
            500 https://librealsense.realsenseai.com/Debian/apt-repo jammy/main amd64 Packages
```

Como ves, en la salida del comando se listan varias versiones del paquete `librealsense2-dkms` disponibles para Ubuntu 22.04 LTS (jammy).

Ahora vamos a descargar el paquete `librealsense2-dkms`, sin instalarlo todavía, para comprobar si es compatible con la versión del kernel que tienes instalada en el sistema operativo host. Para ello, ejecuta el comando:

```bash
# When downloading the librealsense2-dkms package, if you don't specify a version, the latest version will be
# downloaded.
# In this example, I am using an Ubuntu LTS 22.04, so the latest available version of librealsense2-dkms is
# 1.3.28-0ubuntu1 at the time of writing this guide, February 3rd, 2026.
apt-cache policy librealsense2-dkms
librealsense2-dkms:
  Installed: (none)
  Candidate: 1.3.28-0ubuntu1
  Version table:
     1.3.28-0ubuntu1 500
        500 https://librealsense.realsenseai.com/Debian/apt-repo jammy/main amd64 Packages
     1.3.27-0ubuntu1 500
        500 https://librealsense.realsenseai.com/Debian/apt-repo jammy/main amd64 Packages
     1.3.26-0ubuntu1 500
        500 https://librealsense.realsenseai.com/Debian/apt-repo jammy/main amd64 Packages
     1.3.24-0ubuntu1 500
        500 https://librealsense.realsenseai.com/Debian/apt-repo jammy/main amd64 Packages
     1.3.22-0ubuntu1 500
        500 https://librealsense.realsenseai.com/Debian/apt-repo jammy/main amd64 Packages
     1.3.19-0ubuntu1 500
        500 https://librealsense.realsenseai.com/Debian/apt-repo jammy/main amd64 Packages
# Create a temporary working directory
TMP_DIR="$(mktemp -d)"
cd "${TMP_DIR}"
apt-get download librealsense2-dkms
# Get the current kernel version of your host operating system (Ubuntu LTS)
echo "Your kernel is: $(uname -r)"
# Inspect the downloaded .deb package to see which kernel versions are supported.
echo "The librealsense2-dkms package supports the following kernel versions:"
dpkg-deb -c librealsense2-dkms*.deb | grep -oP 'usr/src/librealsense2-dkms-.*?/\K[0-9]+\.[0-9]+\.[0-9]+' | sort -u
# Clean up
cd /tmp && rm -rf "${TMP_DIR}"
```

Compara la salida de "Your kernel is" con la lista de "The librealsense2-dkms package supports the following kernel versions:"
Si tu kernel está en la lista, puedes proceder a instalar el paquete `librealsense2-dkms`, en caso contrario, no intentes instalar el paquete `librealsense2-dkms`, porque fallará. En ese caso deberás usar la opción A.1.2, parchear manualmente el sistema operativo host usando el código fuente del repositorio de librealsense.

Ejecuta el comando siguiente para instalar el paquete `librealsense2-dkms`:

```bash
sudo apt-get install -y --no-install-recommends librealsense2-udev-rules librealsense2-dkms
sudo udevadm control --reload-rules && sudo udevadm trigger

```

El paquete `librealsense2-udev-rules` se debe instalar porque contiene reglas `udev` necesarias para que el sistema operativo host reconozca correctamente las cámaras RealSense cuando se conecta a ellas por medio de un cable USB.

Ahora tienes que tomar otra decisión, **¿quieres instalar las herramientas como `realsense-viewer`, `rs-enumerate-devices`, o los ejemplos gráficos como `realsense-viewer`, `depth quality tool`,  etc, en el sistema operativo host?**

No es necesario instalar estas herramientas en el sistema operativo host, sólo son de utilidad en caso de que quieras hacer pruebas rápidas o verificar que la cámara funciona correctamente fuera del contenedor Docker. De hecho, puedes instalar estas herramientas dentro de la imagen de Docker, sin necesidad de instalarlas en el sistema operativo host, y usarlas desde dentro del contenedor Docker. O puedes instalarlas en ambos sitios, en el sistema operativo host y en la imagen de Docker.

Si decides instalar las herramientas en el sistema operativo host, tenemos que explicar algunos asuntos más. El paquete `librealsense2-utils` existe en el repositorio oficial de paquetes de RealSense y depende del paquete `librealsense2`.

```bash
> apt-cache policy librealsense2-utils
    librealsense2-utils:
      Installed: (none)
      Candidate: 2.56.5-0~realsense.17054
      Version table:
         2.56.5-0~realsense.17054 500
            500 https://librealsense.realsenseai.com/Debian/apt-repo jammy/main amd64 Packages
         2.56.4-0~realsense.16976 500
            500 https://librealsense.realsenseai.com/Debian/apt-repo jammy/main amd64 Packages
         2.55.1-0~realsense.12474 500
            500 https://librealsense.realsenseai.com/Debian/apt-repo jammy/main amd64 Packages
         2.55.1-0~realsense.12429 500
            500 https://librealsense.realsenseai.com/Debian/apt-repo jammy/main amd64 Packages
         2.55.1-0~realsense.12426 500
            500 https://librealsense.realsenseai.com/Debian/apt-repo jammy/main amd64 Packages
         2.55.1-0~realsense.12423 500
            500 https://librealsense.realsenseai.com/Debian/apt-repo jammy/main amd64 Packages
         2.54.2-0~realsense.10773 500
            500 https://librealsense.realsenseai.com/Debian/apt-repo jammy/main amd64 Packages
         2.54.1-0~realsense.9591 500
            500 https://librealsense.realsenseai.com/Debian/apt-repo jammy/main amd64 Packages
         2.54.1-0~realsense.9588 500
            500 https://librealsense.realsenseai.com/Debian/apt-repo jammy/main amd64 Packages
         2.53.1-0~realsense0.8251 500
            500 https://librealsense.realsenseai.com/Debian/apt-repo jammy/main amd64 Packages

# Fíjate como el paquete librealsense2-utils depende del paquete librealsense2.
> apt-cache depends librealsense2-utils
    librealsense2-utils
      Depends: rsync
      Depends: librealsense2
      Depends: librealsense2-gl
      Depends: libgtk-3-dev
      Depends: libc6
      Depends: libgcc-s1
      Depends: libglfw3
     |Depends: libglu1-mesa
      Depends: <libglu1>
        libglu1-mesa
      Depends: libopengl0
      Depends: libssl3
      Depends: libstdc++6

> apt-cache policy librealsense2
  librealsense2:
    Installed: (none)
    Candidate: 2.56.5-0~realsense.17054
    Version table:
       2.56.5-0~realsense.17054 500
          500 https://librealsense.realsenseai.com/Debian/apt-repo jammy/main amd64 Packages
       2.56.4-0~realsense.16976 500
          500 https://librealsense.realsenseai.com/Debian/apt-repo jammy/main amd64 Packages
       2.55.1-0~realsense.12474 500
          500 https://librealsense.realsenseai.com/Debian/apt-repo jammy/main amd64 Packages
       2.55.1-0~realsense.12429 500
          500 https://librealsense.realsenseai.com/Debian/apt-repo jammy/main amd64 Packages
       2.55.1-0~realsense.12426 500
          500 https://librealsense.realsenseai.com/Debian/apt-repo jammy/main amd64 Packages
       2.55.1-0~realsense.12423 500
          500 https://librealsense.realsenseai.com/Debian/apt-repo jammy/main amd64 Packages
       2.54.2-0~realsense.10773 500
          500 https://librealsense.realsenseai.com/Debian/apt-repo jammy/main amd64 Packages
       2.54.1-0~realsense.9591 500
          500 https://librealsense.realsenseai.com/Debian/apt-repo jammy/main amd64 Packages
       2.54.1-0~realsense.9588 500
          500 https://librealsense.realsenseai.com/Debian/apt-repo jammy/main amd64 Packages
       2.53.1-0~realsense0.8251 500
          500 https://librealsense.realsenseai.com/Debian/apt-repo jammy/main amd64 Packages
```

Podrías instalar el paquete `librealsense2-utils` con el comando `sudo apt-get install --no-install-recommends -y librealsense2-utils`, y este comando instalaría también el paquete `librealsense2` por ser depedencia del primero, pero la pregunta que tenemos que hacernos es **¿con qué flags se ha compilado el paquete `librealsense2` que se va a instalar como dependencia del paquete `librealsense2-utils`?**. Lamentablemente, no hay forma de saber con qué flags se ha compilado el paquete `librealsense2` que se instala como dependencia del paquete `librealsense2-utils`. La forma de saber con qué flags se ha compilado el paquete `librealsense2`, situado en el repositorio oficial de paquetes de RealSense, sería descargar el codigo fuente con el que se ha construído ese paquete, compilarlo y observar en el fichero `CMakeCache.txt` generado durante el proceso de compilación; allí se encuentran los valores de los flags usados en la compilación.
Sin embargo, no es posible realizar este procedimiento porque el repositorio oficial de paquetes de RealSense, a diferencia de otros servidores de paquetes, no almacena el código fuente con el que se han construido los paquetes disponibles en el, como se puede comprobar con los siguientes comandos:

```bash
# For Ubuntu 22.04 LTS (jammy)
# The Release file is the repository’s cryptographic manifest, and it lists the hash of each package available in the
# repository.
# There are matches for the 'Packages\.' pattern, as confirmed by the following command.
> curl -fsSL "https://librealsense.realsenseai.com/Debian/apt-repo/dists/jammy/Release" | grep -E "Packages\."
    ceb64867fc8ed770a4e9060c5a746fc6                                  16969 main/binary-amd64/Packages.bz2
    2c9d5bad253e32232d63c2913cc725ec                                  18791 main/binary-amd64/Packages.gz
    a7e694590e3c86e3f9c33faf8756f6e1                                   7102 main/binary-arm64/Packages.bz2
    c95a0deb8220e528380d7397a03e2b04                                   7571 main/binary-arm64/Packages.gz
    4059d198768f9f8dc9372dc1c54bc3c3                                     14 main/binary-i386/Packages.bz2
    3970e82605c7d109bb348fc94e9eecc0                                     20 main/binary-i386/Packages.gz
    85567e93b0ab9b4c2ac422dce7e5a1a9f73a156e                          16969 main/binary-amd64/Packages.bz2
    435b1dc344f84e32098f006872df26365d547d8f                          18791 main/binary-amd64/Packages.gz
    e7bcb825e18b7961ee6553664def753a03820f6c                           7102 main/binary-arm64/Packages.bz2
    a2087943b4a7b13f3945e6df44db9995b18631f7                           7571 main/binary-arm64/Packages.gz
    64a543afbb5f4bf728636bdcbbe7a2ed0804adc2                             14 main/binary-i386/Packages.bz2
    e03849ea786b9f7b28a35c17949e85a93eb1cff1                             20 main/binary-i386/Packages.gz
    4b4bddf220add7f561f4ebf200a429c3ed13cbd89d13fe733bd569a509795fda  16969 main/binary-amd64/Packages.bz2
    68c41cdaf3392ff5c2bd081ca3ea723d557e9e95db9dee87185dce0ac852d769  18791 main/binary-amd64/Packages.gz
    332f4517093413c01bf8e239390f017e2558de6d44c94964c7c99122e9373ffa   7102 main/binary-arm64/Packages.bz2
    c983fe384473301150f6bb50f5a30f169c141b6f51ca4b831b901a9c3517d156   7571 main/binary-arm64/Packages.gz
    d3dda84eb03b9738d118eb2be78e246106900493c0ae07819ad60815134a8058     14 main/binary-i386/Packages.bz2
    f5d031af01f137ae07fa71720fab94d16cc8a2a59868766002918b7c240f3967     20 main/binary-i386/Packages.gz

# However, there are no matches for the 'Sources\.' pattern, as confirmed by the following command.
# The empty output indicates that the official RealSense package repository does not store the source code used to build
# the packages available in the repository.
> curl -fsSL "https://librealsense.realsenseai.com/Debian/apt-repo/dists/jammy/Release" | grep -E "Sources\."
```

Como no puedes comprobar con qué flags se ha compilado el paquete `librealsense2` que se va a instalar como dependencia del paquete `librealsense2-utils`, no puedes saber si esta librería usará los controladores del kernel del sistema operativo host (backend nativo) o si usará el backend **RS-USB** (`-DFORCE_RSUSB_BACKEND=OFF|ON`), o si tiene soporte para **CUDA** (`-DBUILD_WITH_CUDA=ON|OFF`), etc.

> **Nota importante:**<br/>
> Cuando la librería `librealsense2` ha sido compilada con soporte para **CUDA** (`-DBUILD_WITH_CUDA=ON`), el procesamiento de la nube de puntos, algunos filtros (como el filtro espacial) y algunas operaciones como `align_depth_to_color` se aceleran usando la GPU de la máquina, lo que mejora el rendimiento. Desde la versión `v2.56.4` de la librería `librealsense2`, si se ha activado el soporte para **CUDA** en la compilación de la librería, pero el sistema carece de una GPU compatible con **CUDA** o de los controladores de NVIDIA necesarios para usar **CUDA**, entonces la librería `librealsense2` se ejecuta usando la CPU.
Las notas de la versión `v2.56.4` así lo indican: https://github.com/realsenseai/librealsense/releases/tag/v2.56.4

Un razonamiento plausible sería considerar que si el paquete `librealsense2` hubiera sido compilado haciendo uso del fichero [CMakeLists.txt](https://github.com/realsenseai/librealsense/blob/master/CMake/lrs_options.cmake) que está disponible en el [repositorio oficial de la librería](https://github.com/realsenseai/librealsense), sin modificaciones ni personalizaciones de ningún tipo, entonces, atendiendo a que este fichero posee la instrucción [include(CMake/lrs_options.cmake)](https://github.com/realsenseai/librealsense/blob/master/CMakeLists.txt#L11), que incluye el fichero [lrs_options.cmake](https://github.com/realsenseai/librealsense/blob/master/CMake/lrs_options.cmake), que lista los valores por defecto de todos los flags de compilación para la librería, la compilación habría usado los valores de los flags:

```cmake
...
# No CUDA support by default.
option(BUILD_WITH_CUDA "Enable CUDA" OFF)
...
# Using native backend by default, not the RS-USB backend.
option(FORCE_RSUSB_BACKEND "Use RS USB backend, mandatory for Win7/MacOS/Android, optional for Linux" OFF)
option(FORCE_LIBUVC "Explicitly turn-on libuvc backend - deprecated, use FORCE_RSUSB_BACKEND instead" OFF)
...
```

Pero aunque este es un razonamiento plausible, no es una prueba concluyente de que el paquete `librealsense2` que se va a instalar como dependencia del paquete `librealsense2-utils` haya sido compilado usando los valores por defecto de los flags de compilación listados en el fichero [lrs_options.cmake](https://github.com/realsenseai/librealsense/blob/master/CMake/lrs_options.cmake), porque el código fuente con el que se ha construido ese paquete no está disponible en el repositorio oficial de paquetes de RealSense, y por lo tanto no se puede comprobar si se han modificado o personalizado los flags de compilación respecto a los valores por defecto listados en ese fichero. Por lo tanto, como se dijo antes, seguimos sin poder estar seguros de los valores usados para los flags de compilación del paquete `librealsense2`. Por lo tanto, la opción más segura para instalar las herramientas como `rs-enumerate-devices`, `fw-update`, etc., los ejemplos gráficos como `realsense-viewer`, `depth quality tool`, etc., y configurar la librería exactamente como queramos es descargar el código fuente de la librería `librealsense` desde su repositorio oficial, en la versión que consideremos oportuna y compilarla con los valores de los flags que consideremos oportunos.

> **Nota importante:**<br/>
> Es importante que entiendas que aunque en el sistema operativo host hayas modificado los controladores nativos del kernel, nada te impide compilar la librería `librealsense2` para que use el enfoque **RS-USB** si así lo deseas, simplemente cambiando el flag `FORCE_RSUSB_BACKEND` a `ON` en el comando `cmake` apropiado. Si usas el enfoque **RS-USB**, entonces no importa qué controladores nativos del kernel del sistema operativo host tengas instalados; originales o modificados, porque la librería `librealsense2` usará sus propios controladores **RS-USB** para comunicarse con la cámara RealSense. En el código de ejemplo mostrado a continuación, se usa el backend nativo, no el backend **RS-USB**, ya que estamos dentro de la opción A.

```bash
# Update the system (deeply)
sudo apt-get update
# Update kenel to the latest stable kernel
sudo apt-get -y dist-upgrade
# Install required packages for building librealsense.
# Since we are installing the graphical examples (-DBUILD_GRAPHICAL_EXAMPLES=ON) we need to install graphical libraries:
# libgtk-3-dev, libglfw3-dev, libgl1-mesa-dev, libglu1-mesa-dev.
sudo apt-get install -y --no-install-recommends ca-certificates curl git wget cmake build-essential libssl-dev \
  libusb-1.0-0-dev \
  libudev-dev \
  pkg-config \
  libgtk-3-dev \
  libglfw3-dev \
  libgl1-mesa-dev \
  libglu1-mesa-dev

# Retrive the latest published release from the librealsense repository.
# As of February 3rd, 2026, the latest published release is v2.57.6, marked as beta.
LATEST_TAG=$(curl -s https://api.github.com/repos/realsenseai/librealsense/releases/latest | grep "tag_name" | cut -d '"' -f 4)
dst_dir="/tmp/librealsense" && [ -d "${dst_dir}" ] && rm -rf "${dst_dir}"
git clone --branch "${LATEST_TAG}" --depth 1 https://github.com/realsenseai/librealsense.git "${dst_dir}"

# You can also download the 'master' branch, if needed.
# dst_dir="/tmp/librealsense" && [ -d "${dst_dir}" ] && rm -rf "${dst_dir}"
# git clone --depth 1 https://github.com/realsenseai/librealsense.git "${dst_dir}"

# Or you can download a specific release.
# As of February 3rd, 2026, the latest stable (not beta) release is v2.56.5.
# dst_dir="/tmp/librealsense" && [ -d "${dst_dir}" ] && rm -rf "${dst_dir}"
# LIB_VERSION="v2.56.5"
# git clone --branch ${LIB_VERSION} --depth 1 https://github.com/realsenseai/librealsense.git "${dst_dir}"

cd "${dst_dir}" && [ -d "build" ] && rm -rf build
mkdir build && cd build
# In this example we are going to: disable CUDA support, enable graphical examples, enable tools, and use the native
# backend, not the RS-USB backend.
# For a list of all flags visit the URL https://github.com/realsenseai/librealsense/blob/master/CMake/lrs_options.cmake,
# and rememeber to choose the branch or tag you require.
# Alternatively, you can also visit the documentation page about build configuration at URL
# https://dev.realsenseai.com/docs/build-configuration.
# The lrs_options.cmake file, included in CMakeLists.txt, already indicates by default:
# option(BUILD_WITH_CUDA "Enable CUDA" OFF)
# If you set this flag to ON, but CUDA is not available on your system, the librealsense library should fallback to CPU
# processing since version v2.56.4, when this fallback mechanism was implemented, as indicated in the release notes of
# that version: https://github.com/realsenseai/librealsense/releases/tag/v2.56.4
# Anyway, try to be sure that CUDA is available on your system before setting this flag to ON and no issues arise.
# option(BUILD_EXAMPLES "Build examples (not including graphical examples -- see BUILD_GRAPHICAL_EXAMPLES)" ON)
# option(BUILD_GRAPHICAL_EXAMPLES "Build graphical examples (Viewer & DQT) -- Implies BUILD_GLSL_EXTENSIONS" ON)
# option(BUILD_TOOLS "Build tools (fw-updater, etc.) that are not examples" ON)
# option(FORCE_RSUSB_BACKEND "Use RS USB backend, mandatory for Win7/MacOS/Android, optional for Linux" OFF)
# option(FORCE_LIBUVC "Explicitly turn-on libuvc backend - deprecated, use FORCE_RSUSB_BACKEND instead" OFF)
# FORCE_RSUSB_BACKEND and FORCE_LIBUVC are meant to force the use of RS-USB backend (user-space UVC and HID).
# So, strictly speaking, it would only have been necessary to specify the flag -DBUILD_EXAMPLES=OFF, because the rest
# of the flags already have the desired value by default; but to be explicit and leave no room for doubt, we list all
# the flags that are relevant to us.
cmake .. -DCMAKE_BUILD_TYPE=Release \
         -DBUILD_WITH_CUDA=OFF \
         -DBUILD_EXAMPLES=OFF \
         -DBUILD_GRAPHICAL_EXAMPLES=ON \
         -DBUILD_TOOLS=ON \
         -DFORCE_RSUSB_BACKEND=OFF
sudo make uninstall && make clean && make && sudo make -j$(($(nproc)-1)) install
```

Puedes seguir con los pasos siguientes de la opción A (saltas la opción A.1.2).

#### Opción A.1.2: Parchear manualmente el sistema operativo host usando el código fuente del repositorio de librealsense

Si estás aquí es por una de estas dos razones:

- El sistema operativo host es una versión LTS de Ubuntu (20.04, 22.04, 24.04, otras a futuro) pero no has podido instalar el paquete `librealsense2-dkms` desde el repositorio oficial de paquetes de RealSense.
- Quieres tener control total sobre el proceso de parcheo del sistema operativo host.

Ejecuta los siguientes comandos en el sistema operativo host:

```bash
# Update the system (deeply)
sudo apt-get update
# Update kenel to the latest stable kernel
sudo apt-get -y dist-upgrade
# Install required packages for building librealsense and kernel modules (if not already installed)
sudo apt-get install -y --no-install-recommends ca-certificates curl git wget cmake build-essential libssl-dev \
  libusb-1.0-0-dev \
  libudev-dev \
  pkg-config \

dst_dir="/tmp/librealsense" && [ -d "${dst_dir}" ] && rm -rf "${dst_dir}"
# Retrive the latest published release from the librealsense repository.
# As of February 3rd, 2026, the latest published release is v2.57.6, marked as beta.
LATEST_TAG=$(curl -s https://api.github.com/repos/realsenseai/librealsense/releases/latest | grep "tag_name" | cut -d '"' -f 4)
git clone --branch "${LATEST_TAG}" --depth 1 https://github.com/realsenseai/librealsense.git "${dst_dir}"

# You can also download the 'master' branch, if needed.
# dst_dir="/tmp/librealsense" && [ -d "${dst_dir}" ] && rm -rf "${dst_dir}"
# git clone --depth 1 https://github.com/realsenseai/librealsense.git "${dst_dir}"

# Or you can download a specific release.
# As of February 3rd, 2026, the latest stable (not beta) release is v2.56.5.
# dst_dir="/tmp/librealsense" && [ -d "${dst_dir}" ] && rm -rf "${dst_dir}"
# LIB_VERSION="v2.56.5"
# git clone --branch ${LIB_VERSION} --depth 1 https://github.com/realsenseai/librealsense.git "${dst_dir}"

# Install the udev rules
bash "${dst_dir}/scripts/setup_udev_rules.sh"
sudo udevadm control --reload-rules && sudo udevadm trigger

# Patch the kernel modules for your Ubuntu LTS version
# Visit the function ${dst_dir}/scripts/patch-utils-hwe.sh::choose_kernel_branch to see which kernels are supported.
# As of february 3rd, 2026 the supported kernels listed in the function choose_kernel_branch for the latest published
# release, v2.57.6, marked as beta, are:
# Ubuntu 20.04 LTS (focal): 5.4, 5.8, 5.11, 5.13, 5.15.
# Ubuntu 22.04 LTS (jammy): 5.15, 5.19, 6.2, 6.5, 6.8.
# Ubuntu 24.04 LTS (noble): 6.8, 6.11, 6.14.
bash "${dst_dir}/scripts/patch-realsense-ubuntu-lts-hwe.sh"

# The script above will download, patch and build realsense-affected kernel modules (drivers).
# Then it will attempt to insert the patched module instead of the active one.
# If failed the original uvc modules will be restored.

# Refer to the URL https://github.com/realsenseai/librealsense/blob/master/doc/installation.md#troubleshooting-installation-and-patch-related-issues
# for troubleshooting installation and patch related issues.

# Check the patched modules installation by examining the generated log as well as inspecting the latest entries in
# kernel log.
# The log should indicate that a new _uvcvideo_ driver has been registered.
sudo dmesg | tail -n 50
```

Ahora tienes que tomar otra decisión, **¿quieres instalar las herramientas como `realsense-viewer`, `rs-enumerate-devices`, etc, en el sistema operativo host?**

Si la respuesta es no, puedes seguir con los pasos siguientes de la opción A, relativos a la instalación de paquetes dentro de la imagen de Docker.
Recuerda que las herramientas no son obligatorias, sólo son de utilidad en caso de que quieras hacer pruebas rápidas o verificar que la cámara funciona correctamente fuera del contenedor Docker. De hecho, puedes instalar estas herramientas dentro de la imagen de Docker, sin necesidad de instalarlas en el sistema operativo host, y usarlas desde dentro del contenedor Docker. Y si quieres, puedes instalarlas en ambos sitios, en el sistema operativo host y en la imagen de Docker.

Si la respuesta es sí, ejecuta los siguientes comandos en el sistema operativo host:

```bash
# Build and install librealsense2 from source (including tools)
cd "${dst_dir}" && [ -d "build" ] && rm -rf build
mkdir build && cd build
# For a list of all flags visit the URL https://github.com/realsenseai/librealsense/blob/master/CMake/lrs_options.cmake,
# and rememeber to choose the branch or tag you require.
# Alternatively, you can also visit the documentation page about build configuration at URL
# https://dev.realsenseai.com/docs/build-configuration.

# Common flags are:
# option(BUILD_WITH_CUDA "Enable CUDA" OFF)
# If you set this flag to ON, but CUDA is not available on your system, the lirary should fallback to CPU processing.
# I am sure I have read about this behavior somewhere in issues of the librealsense GitHub repo.
# Anyway, try to be sure that CUDA is available on your system before setting this flag to ON and no issues arise.
# option(BUILD_EXAMPLES "Build examples (not including graphical examples -- see BUILD_GRAPHICAL_EXAMPLES)" ON)
# option(BUILD_GRAPHICAL_EXAMPLES "Build graphical examples (Viewer & DQT) -- Implies BUILD_GLSL_EXTENSIONS" ON)
# option(BUILD_TOOLS "Build tools (fw-updater, etc.) that are not examples" ON)
# option(FORCE_RSUSB_BACKEND "Use RS USB backend, mandatory for Win7/MacOS/Android, optional for Linux" OFF)
# option(FORCE_LIBUVC "Explicitly turn-on libuvc backend - deprecated, use FORCE_RSUSB_BACKEND instead" OFF)
# FORCE_RSUSB_BACKEND and FORCE_LIBUVC are meant to force the use of RS-USB backend (user-space UVC and HID).
# Since we are in the option A, we DO NOT use RS-USB backend here, so we leave this flag to OFF.
# Since we are installing the graphical examples (-DBUILD_GRAPHICAL_EXAMPLES=ON) we need to install graphical libraries:
# libgtk-3-dev, libglfw3-dev, libgl1-mesa-dev, libglu1-mesa-dev.
sudo apt-get install -y --no-install-recommends git wget cmake build-essential libssl-dev \
  libusb-1.0-0-dev \
  libudev-dev \
  pkg-config \
  libgtk-3-dev \
  libglfw3-dev \
  libgl1-mesa-dev \
  libglu1-mesa-dev
cmake .. -DCMAKE_BUILD_TYPE=Release \
         -DBUILD_WITH_CUDA=OFF \
         -DBUILD_EXAMPLES=OFF \
         -DBUILD_GRAPHICAL_EXAMPLES=ON \
         -DBUILD_CV_EXAMPLES=OFF \
         -DBUILD_PCL_EXAMPLES=OFF \
         -DBUILD_TOOLS=ON \
         -DFORCE_RSUSB_BACKEND=OFF
sudo make uninstall && make clean && make && sudo make -j$(($(nproc)-1)) install

# The binary demos, tutorials and test files will be copied into /usr/local/bin
```

### Paso 2: Instalar el paquete de ROS2 realsense2-camera y la librería librealsense2 en la imagen de Docker

En la imagen de Docker se debe instalar el paquete de ROS2 `realsense2-camera` y la librería `librealsense2`.
El paquete `realsense2-camera` hace uso de la librería `librealsense2`, y la librería, dependiendo de cómo se haya compilado, bien se comunica con la cámara RealSense usando los controladores nativos del kernel del sistema operativo host o bien usando el backend **RS-USB**.

**IMPORTANTE:**<br/>
El paquete de ROS2 `ros-${ROS_DISTRO}-realsense2-camera` depende de la librería `ros-${ROS_DISTRO}-librealsense2`, que es la librerería `librealsense2` empaquetada para **ROS2**.

Mira la salida del comando `apt-cache depends ros-humble-realsense2-camera` (suponiendo que usas **ROS2-Humble**):

```bash
apt-cache depends ros-humble-realsense2-camera
    ros-humble-realsense2-camera
      Depends: libc6
      Depends: libconsole-bridge1.0
      Depends: libgcc-s1
      Depends: libopencv-core4.5d
      Depends: libstdc++6
      Depends: ros-humble-librealsense2 <==
      Depends: libeigen3-dev
      Depends: ros-humble-builtin-interfaces
      Depends: ros-humble-cv-bridge
      Depends: ros-humble-diagnostic-updater
      Depends: ros-humble-geometry-msgs
      Depends: ros-humble-image-transport
      Depends: ros-humble-launch-ros
      Depends: ros-humble-lifecycle-msgs
      Depends: ros-humble-nav-msgs
      Depends: ros-humble-rclcpp
      Depends: ros-humble-rclcpp-components
      Depends: ros-humble-rclcpp-lifecycle
      Depends: ros-humble-realsense2-camera-msgs
      Depends: ros-humble-sensor-msgs
      Depends: ros-humble-std-msgs
      Depends: ros-humble-std-srvs
      Depends: ros-humble-tf2
      Depends: ros-humble-tf2-ros
      Depends: ros-humble-ros-workspace
```

La **OSRF** (**Open Source Robotics Foundation**) usa la cuenta de GitHub [ros2-gbp](https://github.com/ros2-gbp) para almacenar repositorios de `releases` de paquetes **ROS2**. Un repositorio por paquete. En cada repositorio hay ramas y etiquetas que contienen el código fuente de un paquete **ROS2** específico, empaquetado para varias distribuciones de **ROS2**: Foxy, Galactic, Humble, Jazzy, Iron, etc.
El `build farm` de **ROS2** usa esos repositorios para compilar los paquetes y publicarlos en los servidor oficial de paquetes de **ROS2** ([packages.ros.org](http://packages.ros.org/)).

El repositorio [https://github.com/ros2-gbp/librealsense2-release](https://github.com/ros2-gbp/librealsense2-release) se utiliza para crear el paquete `ros-<ros_distro>-librealsense2`, para distintas distribuciones de **ROS2**. El fichero [README.md](https://github.com/ros2-gbp/librealsense2-release/blob/master/README.md) de ese repositorio es un resumen generado por la herramienta `bloom` (la herramienta de ROS que automatiza el proceso de generación un paquete `deb`, generando ramas de empaquetado y metadatos para que el `build farm` lo compile y lo publique). Ese fichero `README` muestra el historial de releases (qué versión se publicó para cada distribución de **ROS2**, cuándo, y con qué comando), y también la configuración que define cómo se gestiona cada distribución.

---

Por ejemplo, la sección [librealsense2 (humble) - 2.51.1-2](https://github.com/ros2-gbp/librealsense2-release?tab=readme-ov-file#librealsense2-humble---2511-1) del fichero [README.md]((https://github.com/ros2-gbp/librealsense2-release/blob/master/README.md)) dice:

> The packages in the `librealsense2` repository were released into the `humble` distro by running `/usr/bin/bloom-release --ros-distro humble --track humble librealsense2 --edit -d` on `Wed, 02 Nov 2022 08:55:18 -0000`
>
> The `librealsense2` package was released.
>
> Version of package(s) in repository `librealsense2`:
>
> - upstream repository: https://github.com/IntelRealSense/librealsense.git
> - release repository: https://github.com/IntelRealSense/librealsense2-release.git
> - rosdistro version: `2.51.1-1`
> - old version: `2.51.1-1`
> - new version: `2.51.1-2`
>
> Versions of tools used:
>
> - bloom version: `0.11.2`
> - catkin_pkg version: `0.5.2`
> - rosdep version: `0.22.1`
> - rosdistro version: `0.9.0`
> - vcstools version: `0.1.42`

---

Vamos a desglosar un poco esta información. Si acudes a la URL [https://github.com/ros2-gbp/librealsense2-release/tags](https://github.com/ros2-gbp/librealsense2-release/tags) observarás que hay muchas etiquetas, donde puedes observar el siguiente patrón:

- `upstream/<X.Y.Z>`: Esta etiqueta apunta a un `commit` que contiene una réplica exacta del código fuente de la librería `librealsense2`, tal cual está en el repositorio oficial [librealsense](https://github.com/realsenseai/librealsense), en la versión `X.Y.Z`. Para el ejemplo, la etiqueta [upstream/2.51.1](https://github.com/ros2-gbp/librealsense2-release/tree/upstream/2.51.1) apunta al [commit 8b08803](https://github.com/ros2-gbp/librealsense2-release/commit/8b08803af9923a93660abbfef7f935e9ef1b307b), que es una réplica exacta del código fuente de la librería [librealsense2 en la versión 2.51.1](https://github.com/realsenseai/librealsense/tree/v2.51.1) disponible en el repositorio oficial [librealsense](https://github.com/realsenseai/librealsense).
- `release/<rosdistro>/<pkg>/<X.Y.Z-R>`: Esta etiqueta apunta a un `commit` que contiene el código fuente de la librería `librealsense2` en la versión `X.Y.Z-R` (`R` de `número de release`), empaquetada para **ROS2** en la distribución `<rosdistro>`. Es decir, el código fuente original, junto con metadatos generados por la herramienta `bloom`. Para el ejemplo propuesto se tiene la etiqueta [release/humble/librealsense2/2.51.1-2](https://github.com/ros2-gbp/librealsense2-release/tree/release/humble/librealsense2/2.51.1-2).
- `debian/ros-<rosdistro>-<pkg>_<X.Y.Z-R>_<os>`: Esta etiqueta apunta a un `commit` que contiene el código fuente de la librería `librealsense2` en la versión `X.Y.Z-R`, empaquetada para ROS2 en la distribución `<rosdistro>`, adaptada para el sistema operativo `<os>` y que contiene los ficheros de empaquetado `debian/` (control, rules, changelog, parches, etc.) usados para construir el paquete binario `.deb` que se instala con `apt`. Para el ejemplo propuesto se tiene la etiqueta [debian/ros-humble-librealsense2_2.51.1-2_jammy](https://github.com/ros2-gbp/librealsense2-release/tree/debian/ros-humble-librealsense2_2.51.1-2_jammy).

En cambio, la ramas:

- `release/<rosdistro>/<pkg>` apunta a la última versión publicada por **ROS2** de la librería `librealsense2` para la distribución `<rosdistro>`. Ejemplo: A fecha de 3 de febrero de 2026, la rama [release/humble/librealsense2](https://github.com/ros2-gbp/librealsense2-release/tree/release/humble/librealsense2) apunta a la versión `2.56.4-1` de la librería `librealsense2` para **ROS2-humble**, es decir al [commit 10048a2](https://github.com/ros2-gbp/librealsense2-release/commit/10048a2fe82b7911584aa80fbfc9b5944d9b7d8d), que es el mismo commit al que siempre apuntará la etiqueta [release/humble/librealsense2/2.56.4-1](https://github.com/ros2-gbp/librealsense2-release/tree/release/humble/librealsense2/2.56.4-1). Si visitas la rama [release/humble/librealsense2](https://github.com/ros2-gbp/librealsense2-release/tree/release/humble/librealsense2) en el futuro, es posible que apunte a una versión más reciente de la librería `librealsense2` para **ROS2-humble**.
- `debian/<ros_distro>/<pkg>` apunta a la última versión publicada de la librería `librealsense2` para `<rosdistro>`, pero en este caso contiene además los ficheros de empaquetado `debian/` (control, rules, changelog, parches, etc.) que se usan para construir el paquete binario `deb` que se instala con el comando `apt-get install`. Ejemplo: A fecha de 3 de febrero de 2026, la rama [debian/humble/librealsense2](https://github.com/ros2-gbp/librealsense2-release/tree/debian/humble/librealsense2) apunta a la versión `2.56.4-1` de la librería `librealsense2` para **ROS2-Humble** lista para crear el paquete `deb`, es decir al [commit 2d3d5db](https://github.com/ros2-gbp/librealsense2-release/commit/2d3d5db09d9b51d7384762c13ad1eec59e32c88a), que es el mismo commit al que siempre apuntará la etiqueta [debian/ros-humble-librealsense2_2.56.4-1_jammy](https://github.com/ros2-gbp/librealsense2-release/tree/debian/ros-humble-librealsense2_2.56.4-1_jammy). Si visitas la rama [debian/humble/librealsense2](https://github.com/ros2-gbp/librealsense2-release/tree/debian/humble/librealsense2) en el futuro, es posible que apunte a una versión más reciente de la librería `librealsense2` para **ROS2-humble** lista para crear el paquete `deb`.

Usando el comando `apt-cache policy ros-humble-librealsense2` puedes comprobar qué versión de la librería `librealsense2` está publicada en el repositorio oficial de **ROS2** para la distribución **humble**. A fecha de 3 de febrero de 2026, la salida del comando es la siguiente:

```bash
rob@robpc:~$ date
Tue Feb  3 04:31:11 PM UTC 2026
rob@robpc:~$ apt-cache policy ros-humble-librealsense2
ros-humble-librealsense2:
  Installed: (none)
  Candidate: 2.56.4-1jammy.20250722.184252
  Version table:
     2.56.4-1jammy.20250722.184252 500
        500 http://packages.ros.org/ros2/ubuntu jammy/main amd64 Packages
eutrob@CL-JRASCON:~$
```

El ritmo al que se publican nuevas versiones de la librería `librealsense2` en el repositorio oficial [librealsense](https://github.com/realsenseai/librealsense) es más rápido que el ritmo al que se publica el paquete de **ROS2** de `librealsense2` para cada distribución. Es decir, vamos a encontrar versiones de la librería `librealsense2` en el repositorio oficial [librealsense](https://github.com/realsenseai/librealsense) que aún no están empaquetadas y publicadas en el repositorio oficial de **ROS2** para la distribución que estemos usando. A modo de ejemplo, a fecha de 3 de febrero de 2026, la última versión publicada en el repositorio oficial de la librarería `librealsense2` es la [`v2.57.6`](https://github.com/realsenseai/librealsense/tree/v2.57.6), versión beta, publicada el 28 de enero de 2026, mientras que la última versión publicada en el repositorio de **ROS2** para **Humble** es la `2.56.4-1`, publicada el 22 de julio de 2025. Este desincronismo es habitualmente la norma en todos los paquetes de **ROS2** desarrollados por terceros.

A continuación te doy varias opciones de instalación, elige una:

#### Opción A.2.1: Instalar el paquete ros-${ROS_DISTRO}-realsense2-camera en la imagen de Docker desde el repositorio oficial de ROS2 usando el comando apt

Esta opción es adecuada si consideras que la versión de los paquetes `ros-${ROS_DISTRO}-realsense2-camera` y `ros-${ROS_DISTRO}-librealsense2` publicados en el repositorio oficial de **ROS2** son suficientemente recientes para tu aplicación. En cambio, si necesitas una versión más reciente de alguno de los paquetes o si quieres tener más control sobre el proceso de compilación de los paquetes, deberías usar la opción A.2.2.

```Dockerfile
# Install librealsense2 and realsense2-camera ROS2 package
RUN apt-get update && apt-get install -y --no-install-recommends \
    ros-${ROS_DISTRO}-realsense2-camera \
    && rm -rf /var/lib/apt/lists/*
```

El paquete `ros-${ROS_DISTRO}-realsense2-camera` instalará automáticamente la dependencia `ros-${ROS_DISTRO}-librealsense2`. La pregunta es, **¿cómo se ha compilado el paquete `ros-${ROS_DISTRO}-librealsense2` que se instala como dependencia del paquete `ros-${ROS_DISTRO}-realsense2-camera`?**
A continuación voy a mostrarte, a modo de ejemplo, con qué flags se ha compilado el paquete [ros-humble-librealsense2](http://packages.ros.org/ros2/ubuntu/pool/main/r/ros-humble-librealsense2/) que se puede instalar desde el [servidor de paquetes oficial de **ROS2**](http://packages.ros.org/ros2/ubuntu/dists/jammy/main/binary-amd64/Packages). Si quieres puedes seguir tu mismo el procedimiento y comprobar lo que te cuento a continuación. Seguramente, el resto de versiones de `ros-${ROS_DISTRO}-librealsense2` para otras distribuciones de **ROS2** se han compilado con flags iguales.

Para la demostración voy a compilar el código fuente del paquete [ros-humble-librealsense2](http://packages.ros.org/ros2/ubuntu/pool/main/r/ros-humble-librealsense2/), que está alojado en el [servidor de paquetes oficial de **ROS2**](http://packages.ros.org/ros2/ubuntu/dists/jammy/main/binary-amd64/Packages), y que a fecha de 3 de febrero de 2026 está en la versión `2.56.4-1`, en un contenedor de Docker donde está instalado Ubuntu LTS 22.04 y **ROS2-Humble**. Cuando finalice la compilación podremos inspeccionar el fichero `CMakeCache.txt` principal, que contiene los flags usados en la compilación del paquete.

El código fuente del paquete [ros-humble-librealsense2](http://packages.ros.org/ros2/ubuntu/pool/main/r/ros-humble-librealsense2/), versión `2.56.4-1`, alojado en el [servidor de paquetes oficial de **ROS2**](http://packages.ros.org/ros2/ubuntu/dists/jammy/main/binary-amd64/Packages), es el mismo que el apuntado por las etiquetas [upstream/2.56.4](https://github.com/ros2-gbp/librealsense2-release/tree/upstream/2.56.4), [release/humble/librealsense2/2.56.4-1](https://github.com/ros2-gbp/librealsense2-release/tree/release/humble/librealsense2/2.56.4-1) y [debian/ros-humble-librealsense2_2.56.4-1_jammy](https://github.com/ros2-gbp/librealsense2-release/tree/debian/ros-humble-librealsense2_2.56.4-1_jammy) en el repositorio [https://github.com/ros2-gbp/librealsense2-release](https://github.com/ros2-gbp/librealsense2-release) (el commit apuntado por cada etiqueta puede tener configuración o metadatos diferentes, como se ha indicando anteriormente) y el mismo que el apuntado por la etiqueta [v2.56.4](https://github.com/realsenseai/librealsense/tree/v2.56.4) en el repositorio [https://github.com/realsenseai/librealsense](https://github.com/realsenseai/librealsense)

```bash
sudo apt-get update
apt-cache policy ros-humble-librealsense2
    ros-humble-librealsense2:
      Installed: (none)
      Candidate: 2.56.4-1jammy.20250722.184252
      Version table:
         2.56.4-1jammy.20250722.184252 500
            500 http://packages.ros.org/ros2/ubuntu jammy/main amd64 Packages
# Install build dependencies of the package ros-humble-librealsense2.
# No matter if we are compiling a specific version or the latest one, the build dependencies are (should be) the same.
sudo apt-get build-dep -y ros-humble-librealsense2
# Download the source code of the package ros-humble-librealsense2
cd /tmp
apt-get source ros-humble-librealsense2
ls -l
    total 31816
    -rw-r--r--  1 root root     624 Feb  2 10:56 elog.log
    drwxr-xr-x 17 rob  rob     4096 Feb  2 16:11 ros-humble-librealsense2-2.56.4
    -rw-r--r--  1 rob  rob     2136 Jul 22  2025 ros-humble-librealsense2_2.56.4-1jammy.debian.tar.xz
    -rw-r--r--  1 rob  rob     1193 Jul 22  2025 ros-humble-librealsense2_2.56.4-1jammy.dsc
    -rw-r--r--  1 rob  rob 32557686 Jul 22  2025 ros-humble-librealsense2_2.56.4.orig.tar.gz
cd ros-humble-librealsense2-2.56.4
# Verbose debhelper output (prints dh_auto_configure command)
export DH_VERBOSE=1
sudo dpkg-buildpackage -us -uc -b 2>&1 | tee build_debian.log
# Check Debian's global compile/link flags (not -D, but they matter)
dpkg-buildflags --get CFLAGS
dpkg-buildflags --get CXXFLAGS
dpkg-buildflags --get LDFLAGS
# After the compilation finishes, inspect the CMakeCache.txt file
cat .obj-x86_64-linux-gnu/CMakeCache.txt
# This is the CMakeCache file.
# For build in directory: /home/eutrob/ros-humble-librealsense2-2.56.4/.obj-x86_64-linux-gnu
# It was generated by CMake: /usr/bin/cmake
# You can edit this file to change values found and used by cmake.
# If you do not want to change any of the values, simply exit the editor.
# If you do want to change a value, simply edit, save, and exit the editor.
# The syntax for the file is as follows:
# KEY:TYPE=VALUE
# KEY is the name of a variable in the cache.
# TYPE is a hint to GUIs for the type of VALUE, DO NOT EDIT TYPE!.
# VALUE is the current value for the KEY.

########################
# EXTERNAL cache entries
########################

//Build UVC backend for Android - deprecated, use FORCE_RSUSB_BACKEND
// instead
ANDROID_USB_HOST_UVC:BOOL=OFF

//Enable AddressSanitizer
BUILD_ASAN:BOOL=OFF

//Build C# bindings
BUILD_CSHARP_BINDINGS:BOOL=OFF

//Build OpenCV examples
BUILD_CV_EXAMPLES:BOOL=OFF

//Build OpenCV KinectFusion example
BUILD_CV_KINFU_EXAMPLE:BOOL=OFF

//Build DLIB examples - requires DLIB_DIR
BUILD_DLIB_EXAMPLES:BOOL=OFF

//Build EasyLogging++ as a part of the build
BUILD_EASYLOGGINGPP:BOOL=ON

//Build examples (not including graphical examples -- see BUILD_GRAPHICAL_EXAMPLES)
BUILD_EXAMPLES:BOOL=ON

//Build GLSL extensions API
BUILD_GLSL_EXTENSIONS:BOOL=ON

//Build graphical examples (Viewer & DQT) -- Implies BUILD_GLSL_EXTENSIONS
BUILD_GRAPHICAL_EXAMPLES:BOOL=ON

//Build deprecated Python backend bindings
BUILD_LEGACY_PYBACKEND:BOOL=OFF

//Build Matlab bindings
BUILD_MATLAB_BINDINGS:BOOL=OFF

//Build Open3D examples
BUILD_OPEN3D_EXAMPLES:BOOL=OFF

//Build OpenNI bindings
BUILD_OPENNI2_BINDINGS:BOOL=OFF

//Build Intel OpenVINO Toolkit examples - requires INTEL_OPENVINO_DIR
BUILD_OPENVINO_EXAMPLES:BOOL=OFF

//Build PCL examples
BUILD_PCL_EXAMPLES:BOOL=OFF

//Build pointcloud-stitching example
BUILD_PC_STITCHING:BOOL=OFF

//Build Python bindings
BUILD_PYTHON_BINDINGS:BOOL=OFF

//Build Documentation for Python bindings
BUILD_PYTHON_DOCS:BOOL=OFF

//Build realsense2-all static bundle containing all realsense libraries
// (with BUILD_SHARED_LIBS=OFF)
BUILD_RS2_ALL:BOOL=ON

//Build shared library
BUILD_SHARED_LIBS:BOOL=ON

//Build tools (fw-updater, etc.) that are not examples
BUILD_TOOLS:BOOL=ON

//Copy the unity project to the build folder with the required
// dependencies
BUILD_UNITY_BINDINGS:BOOL=OFF

//Build LibCI unit tests. If enabled, additional test data may
// be downloaded
BUILD_UNIT_TESTS:BOOL=OFF

//Enable compiler optimizations using CPU extensions (such as AVX)
BUILD_WITH_CPU_EXTENSIONS:BOOL=ON

//Enable CUDA
BUILD_WITH_CUDA:BOOL=OFF

//Access camera devices through DDS topics (requires CMake 3.16.3)
BUILD_WITH_DDS:BOOL=OFF

//Use OpenMP
BUILD_WITH_OPENMP:BOOL=OFF

//Build with static link CRT
BUILD_WITH_STATIC_CRT:BOOL=ON

//Path to a program.
CCACHE_FOUND:FILEPATH=CCACHE_FOUND-NOTFOUND

//Checks for versions updates
CHECK_FOR_UPDATES:BOOL=ON

//Path to a program.
CMAKE_ADDR2LINE:FILEPATH=/usr/bin/addr2line

//Path to a program.
CMAKE_AR:FILEPATH=/usr/bin/ar

//Choose the type of build, options are: None Debug Release RelWithDebInfo
// MinSizeRel ...
CMAKE_BUILD_TYPE:STRING=None
... # The file is very long, I have omitted some lines for brevity
```

A continuación te enseño algunos flags relevantes extraídos del fichero `CMakeCache.txt` anterior:

```CMake
//Build OpenCV examples
BUILD_CV_EXAMPLES:BOOL=OFF

//Build examples (not including graphical examples -- see BUILD_GRAPHICAL_EXAMPLES)
BUILD_EXAMPLES:BOOL=ON

//Build GLSL extensions API
BUILD_GLSL_EXTENSIONS:BOOL=ON

//Build graphical examples (Viewer & DQT) -- Implies BUILD_GLSL_EXTENSIONS
BUILD_GRAPHICAL_EXAMPLES:BOOL=ON

BUILD_SHARED_LIBS:BOOL=ON

//Build tools (fw-updater, etc.) that are not examples
BUILD_TOOLS:BOOL=ON

//Enable compiler optimizations using CPU extensions (such as AVX)
BUILD_WITH_CPU_EXTENSIONS:BOOL=ON

//Enable CUDA
BUILD_WITH_CUDA:BOOL=OFF

//Access camera devices through DDS topics (requires CMake 3.16.3)
BUILD_WITH_DDS:BOOL=OFF

//Checks for versions updates
CHECK_FOR_UPDATES:BOOL=ON

//Explicitly turn-on libuvc backend - deprecated, use FORCE_RSUSB_BACKEND instead
FORCE_LIBUVC:BOOL=OFF

//Use RS USB backend, mandatory for Win7/MacOS/Android, optional for Linux
FORCE_RSUSB_BACKEND:BOOL=OFF

//Explicitly turn-on winusb_uvc (for win7) backend - deprecated, use FORCE_RSUSB_BACKEND instead
FORCE_WINUSB_UVC:BOOL=OFF

...

//Choose the type of build, options are: None Debug Release RelWithDebInfo
// MinSizeRel ...
CMAKE_BUILD_TYPE:STRING=None

//Flags used by the CXX compiler during all build types.
CMAKE_CXX_FLAGS:STRING=-g -O2 -ffile-prefix-map=/home/eutrob/ros-humble-librealsense2-2.56.4=. -flto=auto -ffat-lto-objects -flto=auto -ffat-lto-objects -fstack-protector-strong -Wformat -Werror=format-security -DNDEBUG -Wdate-time -D_FORTIFY_SOURCE=2

//Flags used by the C compiler during all build types.
CMAKE_C_FLAGS:STRING=-g -O2 -ffile-prefix-map=/home/eutrob/ros-humble-librealsense2-2.56.4=. -flto=auto -ffat-lto-objects -flto=auto -ffat-lto-objects -fstack-protector-strong -Wformat -Werror=format-security -Wdate-time -D_FORTIFY_SOURCE=2
```

Como ves, la librería `librealsense2` que se instala como dependencia del paquete `ros-${ROS_DISTRO}-realsense2-camera` está compilada para usar los controladores nativos del kernel del sistema operativo host (los flags `FORCE_LIBUVC` y `FORCE_RSUSB_BACKEND` están a `OFF` y en la traza impresa por terminal se ve el menasje `-- using RS2_USE_V4L2_BACKEND`), no tiene soporte para CUDA (el flag `BUILD_WITH_CUDA` está a `OFF`), y tiene compilados los ejemplos gráficos (`realsense-viewer`, `depth quality tool`, etc.) y las herramientas (`fw-update`, `rs-enumerate-devices`, etc).

La variable `CMAKE_BUILD_TYPE` controla qué conjunto de flags (`CMAKE_C_FLAGS_<CONFIG>`, `CMAKE_CXX_FLAGS_<CONFIG>`) se aplica por defecto. Si vale `None` (o vacío), significa literalmente: "no se ha seleccionado ninguna configuración de build tipo `Debug/Release/RelWithDebInfo/MinSizeRel`". En consecuencia, no se aplican los sufijos `_DEBUG`, `_RELEASE`, etc., y se usan únicamente los flags base (`CMAKE_C_FLAGS`, `CMAKE_CXX_FLAGS`) más lo que el proyecto añada.

En el fichero `CMakeCache.txt` se ve que:

```CMake
CMAKE_BUILD_TYPE:STRING=None
CMAKE_CXX_FLAGS:STRING= -g -O2 ... -DNDEBUG ...
CMAKE_C_FLAGS:STRING= -g -O2 ...
```

Eso es muy típico en builds `Debian`; `Debian` no siempre fuerza un `CMAKE_BUILD_TYPE=Release`, porque gestiona optimización, símbolos y hardening a través de `dpkg-buildflags` y el entorno. En tu caso, aunque `CMAKE_BUILD_TYPE=None`, estás compilando "como release" en el sentido práctico de optimización (`-O2`) y `-DNDEBUG`, pero también con símbolos (`-g`). Es una mezcla intencional tipo **release con debug symbols**, controlada por flags de Debian, no por CMake build types.

Si quieres que el soporte de **CUDA** esté disponible en la librería `librealsense2` instalada en la imagen de Docker, o si no quieres que los ejemplos gráficos y las herramientas estén disponibles en la imagen de Docker, o si quieres cambiar cualquier otro flag de compilación, o quieres tener control total sobre el proceso de compilación, entonces debes optar por la opción A.2.2.

#### Opción A.2.2: Compilar e instalar el paquete realsense2-camera y la librería librealsense2 desde el código fuente dentro de la imagen de Docker

Esta opción es adecuada si consideras que la versión de los paquetes `ros-${ROS_DISTRO}-realsense2-camera` y `ros-${ROS_DISTRO}-librealsense2` publicados en el repositorio oficial de **ROS2** no se adapta a tus necesidades y necesitas una versión más reciente de alguno de los paquetes o si quieres tener más control sobre el proceso de compilación de los paquetes.

En esta opción vamos a clonar el código fuente de la librería `librealsense2` y del paquete de **ROS2** `realsense2-camera` de sus respectivos repositorios oficiales y los vamos a compilar dentro de la imagen de Docker. En esta opción, puedes escoger la versión de la librería `librealsense2` y del paquete de **ROS2** `realsense2-camera` que desees, y también puedes elegir los flags de compilación que desees para la librería `librealsense2`.

En el ejemplo que muestro a continuación voy desactivar el soporte para **CUDA** en la librería `librealsense2`, voy a compilar los ejemplos gráficos (`realsense-viewer`, `depth quality tool`, etc.) y las herramientas (`fw-update`, `rs-enumerate-devices`, etc.) y voy a indicar que la librería use los controladores nativos (modificados) del kernel del sistema operativo host, y no el backend **RS-USB**, dado que estamos en la opción A.
Es importante que entiendas que aunque en el sistema operativo host hayas modificado los controladores nativos del kernel, nada te impide compilar la librería `librealsense2` para que use el enfoque **RS-USB** si así lo deseas, simplemente cambiando el flag `FORCE_RSUSB_BACKEND` a `ON` en el comando `cmake` apropiado. Si usas el enfoque **RS-USB**, entonces no importa qué controladores nativos del kernel del sistema operativo host tengas instalados; originales o modificados, porque la librería `librealsense2` usará sus propios controladores **RS-USB** para comunicarse con la cámara RealSense.
Para seguir dándote contexto y que comprendas mejor lo que puedes llegar a hacer; podrías haber modificado los controladores nativos del kernel del sistema operativo host para tener una comunicación óptima con la cámara RealSense, haber instalador la librería `librealsense2` en el sistema operativo host con soporte para ejemplos gráficos, herramientas, sin soporte para **CUDA** y que use los controladores nativos (modificados) del kernel del sistema operativo host, y en la imagen de Docker haber instalado la librería `librealsense2` con soporte para **CUDA**, con ejemplos gráficos, con herramientas y usando el enfoque **RS-USB**. Lo que sí debes tener en cuenta es que, si dentro de la imagen Docker compilas la librería `librealsense2` para que use los controladores nativos del kernel del sistema operativo host, y en el sistema operativo host **NO HAS MODIFICADO LOS CONTROLADORES NATIVOS DEL KERNEL** para que funcionen correctamente con la cámara RealSense, entonces la librería `librealsense2` dentro de la imagen de Docker no podrá comunicarse correctamente con la cámara RealSense.

<a id="install_librealsense2_in_docker_image"></a>

```bash
# Install dependencies for building librealsense from source.
# Since we are installing the graphical examples (-DBUILD_GRAPHICAL_EXAMPLES=ON) we need to install graphical libraries:
# libgtk-3-dev, libglfw3-dev, libgl1-mesa-dev, libglu1-mesa-dev.
sudo apt-get install -y --no-install-recommends git wget cmake build-essential libssl-dev \
  libusb-1.0-0-dev \
  libudev-dev \
  pkg-config \
  libgtk-3-dev \
  libglfw3-dev \
  libgl1-mesa-dev \
  libglu1-mesa-dev

# Get the latest tag name from the GitHub API. You can always use 'master' or any specific tag/branch instead of the latest one.
# As of February 3rd, 2026, the latest published release is v2.57.6, marked as beta.
dst_dir="/tmp/librealsense" && [ -d "${dst_dir}" ] && rm -rf "${dst_dir}"
LATEST_TAG=$(curl -s https://api.github.com/repos/realsenseai/librealsense/releases/latest | grep "tag_name" | cut -d '"' -f 4)
git clone --branch "${LATEST_TAG}" --depth 1 https://github.com/realsenseai/librealsense.git "${dst_dir}"
cd "${dst_dir}" && [ -d build ] && rm -rf build
mkdir build && cd build
cmake .. -DCMAKE_BUILD_TYPE=Release \
  -DBUILD_WITH_CUDA=OFF \
  -DBUILD_EXAMPLES=OFF \
  -DBUILD_GRAPHICAL_EXAMPLES=ON \
  -DBUILD_CV_EXAMPLES=OFF \
  -DBUILD_PCL_EXAMPLES=OFF \
  -DBUILD_TOOLS=ON \
  -DFORCE_RSUSB_BACKEND=OFF

# For faster compilation, leave one CPU core free
sudo make uninstall && make clean && make && sudo make -j$(($(nproc)-1)) install
```

Por último se instalará el paquete `ros-${ROS_DISTRO}-realsense2-camera`, **OMITIENDO** la dependencia `ros-${ROS_DISTRO}-librealsense2`, para que use la librería `librealsense2` compilada en el paso anterior. Uno de los pasos que se darán a continuacón es usar el comando `rosdep install` para instalar las dependencias del paquete `ros-${ROS_DISTRO}-realsense2-camera` antes de compilarlo. Si no se omitiera explícitamente la depedencia `ros-${ROS_DISTRO}-librealsense2`, el comando `rosdep install ...` instalaría esa librería, y habría un conflicto entre la librería `librealsense2` compilada en el paso anterior y la librería instalada por el paquete depedencia `ros-${ROS_DISTRO}-librealsense2`, i.e., ficheros que sobre-escriben a otros ficheros, es posible que incluso diferentes versiones de la librería `librealsense2`, etc.

<a id="install_realsense_ros_camera_in_docker_image"></a>

```bash
workspace_dir="${HOME}/workspace"
[ -d "${workspace_dir}" ] && rm -rf "${workspace_dir}"
mkdir -p "${workspace_dir}/src" && cd "${workspace_dir}"
# Get the latest tag name from the GitHub API. You can always use 'master' or any specific tag/branch instead of the latest one.
# As of February 3rd, 2026, the latest published release is v2.57.6, marked as beta.
LATEST_TAG_URL=$(curl -s https://api.github.com/repos/realsenseai/realsense-ros/releases/latest | grep tag_name | cut -d'"' -f4)
git clone --branch "${LATEST_TAG_URL}" --depth 1 https://github.com/realsenseai/realsense-ros.git "src/realsense-ros"
# Make ros tools available
source "/opt/ros/${ROS_DISTRO}/setup.bash"
rosdep install --from-path src --ignore-src src --rosdistro "${ROS_DISTRO}" --skip-keys=librealsense2 -y
cxx_flags="-Wall -Wextra -Wpedantic -Wnon-virtual-dtor -Woverloaded-virtual -Wnull-dereference -Wunused-parameter"
colcon build --packages-skip-build-finished --packages-select realsense2_camera_msgs realsense2_description realsense2_rgbd_plugin realsense2_ros_mqtt_bridge \
    --symlink-install \
    --merge-install \
    --mixin release \
    --cmake-args -DCMAKE_CXX_FLAGS="${cxx_flags}"

# Note on using ROS2 LifeCycle node:
# Reference: https://github.com/IntelRealSense/realsense-ros?tab=readme-ov-file#ros2-lifecyclenode
# The USE_LIFECYCLE_NODE cmake flag enables ROS2 Lifecycle Node (rclcpp_lifecycle::LifecycleNode) in the Realsense SDK,
# providing better node management and explicit state transitions.
# However, enabling this flag introduces a limitation where Image Transport functionality (image_transport) is disabled
# when USE_LIFECYCLE_NODE=ON.
# This means that compressed image topics (e.g., JPEG, PNG, Theora) will not be available and subscribers must use raw
# image topics, which may increase bandwidth usage.

#  Note: Users who do not depend on image_transport will not be affected by this change and can safely enable Lifecycle
#  Node without any impact on their workflow.

# Why This Limitation?

#At the time Lifecycle Node support was added, image_transport did not support rclcpp_lifecycle::LifecycleNode.
# ROS2 image_transport does not support Lifecycle Node.

# To build the SDK with Lifecycle Node enabled:
# colcon build --cmake-args -DUSE_LIFECYCLE_NODE=ON

# To use standard ROS2 node (default behavior) and retain image_transport functionality:
# colcon build --cmake-args -DUSE_LIFECYCLE_NODE=OFF

colcon build --packages-skip-build-finished --packages-select realsense2_camera \
    --symlink-install \
    --merge-install \
    --mixin release \
    --cmake-args -DCMAKE_CXX_FLAGS="${cxx_flags}" -DUSE_LIFECYCLE_NODE=OFF
```

Si todo hay ido bien, ya tienes la librería `librealsense2` y el paquete `realsense2-camera` instalados en la imagen de Docker. A continuación te muestro un ejemplo de cómo lanzar el nodo `realsense2_camera` para comprobar que todo funciona correctamente.

```bash
# Source the workspace to use the realsense2_camera package
source ${workspace_dir}/install/setup.bash
ros2 launch realsense2_camera rs_launch.py
```

## Opción B: Usar el enfoque RS-USB

Esta opción es sencilla; no necesitas modificar el kernel del sistema operativo host. Además, si no necesitas usar las herramientas (`fw-update`, `rs-enumerate-devices`, etc.), ni los ejemplos gráficos (`realsense-viewer`, `depth quality tool`, etc.) de la librería `librealsense2`, no tienes que hacer nada en el sistema operativo host. En cambio, si quieres usar las herramientas y los ejemplos gráficos de la librería `librealsense2` en el sistema operativo host, entonces instala en éste la librería usando el backend **RS-USB** usando las instrucciones siguientes, idénticas a las de la opción A.2.2 pero con el flag `FORCE_RSUSB_BACKEND` a `ON` en el comando `cmake`. Te las indico aquí, de nuevo, por completitud, aunque también las tienes en la sección A.2.2:

```bash
# Install dependencies for building librealsense from source.
# Since we are installing the graphical examples (-DBUILD_GRAPHICAL_EXAMPLES=ON) we need to install graphical libraries:
# libgtk-3-dev, libglfw3-dev, libgl1-mesa-dev, libglu1-mesa-dev.
sudo apt-get install -y --no-install-recommends git wget cmake build-essential libssl-dev \
  libusb-1.0-0-dev \
  libudev-dev \
  pkg-config \
  libgtk-3-dev \
  libglfw3-dev \
  libgl1-mesa-dev \
  libglu1-mesa-dev

# Get the latest tag name from the GitHub API. You can always use 'master' or any specific tag/branch instead of the latest one.
# As of February 3rd, 2026, the latest published release is v2.57.6, marked as beta.
dst_dir="/tmp/librealsense" && [ -d "${dst_dir}" ] && rm -rf "${dst_dir}"
LATEST_TAG=$(curl -s https://api.github.com/repos/realsenseai/librealsense/releases/latest | grep "tag_name" | cut -d '"' -f 4)
git clone --branch "${LATEST_TAG}" --depth 1 https://github.com/realsenseai/librealsense.git "${dst_dir}"
cd "${dst_dir}" && [ -d build ] && rm -rf build
mkdir build && cd build
cmake .. -DCMAKE_BUILD_TYPE=Release \
  -DBUILD_WITH_CUDA=OFF \
  -DBUILD_EXAMPLES=OFF \
  -DBUILD_GRAPHICAL_EXAMPLES=ON \
  -DBUILD_CV_EXAMPLES=OFF \
  -DBUILD_PCL_EXAMPLES=OFF \
  -DBUILD_TOOLS=ON \
  -DFORCE_RSUSB_BACKEND=ON

# For faster compilation, leave one CPU core free
sudo make uninstall && make clean && make && sudo make -j$(($(nproc)-1)) install
```

Lo que viene a continuación es una réplica exacta de la sección A.2.2, pero con el flag `FORCE_RSUSB_BACKEND` a `ON` en el comando `cmake` para compilar la librería `librealsense2` usando el backend **RS-USB** dentro de la imagen de Docker.

Sigues [estos pasos](#install_librealsense2_in_docker_image) para compilar e instalar la librería `librealsense2` dentro de la imagen de Docker usando el backend **RS-USB** (`-DFORCE_RSUSB_BACKEND=ON`)  y luego sigues [estos pasos](#install_realsense_ros_camera_in_docker_image) para compilar e instalar el paquete `realsense2-camera` dentro de la imagen de Docker, omitiendo la dependencia `ros-${ROS_DISTRO}-librealsense2` para evitar conflictos con la librería `librealsense2` compilada en el paso anterior.

Ya hemos terminado con los pasos!. Sólo quería comentar un par de cosas más. En la URL [https://docs.ros.org/en/jazzy/p/librealsense2/doc/readme.html](https://docs.ros.org/en/jazzy/p/librealsense2/doc/readme.html) encuentras todos los ficheros Markdown que se encuentra en la carpeta [doc del repositorio librealsense2](https://github.com/realsenseai/librealsense/tree/master/doc), pero en forma de documentación HTML, con un formato más amigable y con enlaces entre los diferentes ficheros Markdown. Fíjate que en la URL anterior se indica `jazzy`. Escoge la distribución de **ROS2** que estés usando, por ejemplo `humble`, en lugar de `jazzy` para acceder a la documentación HTML correspondiente. Si quieres profundizar más en la librería `librealsense2`, te recomiendo que leas esa documentación. Si una URL no funciona, y el navegador indica que no existe, fíjate si usa el término `intelrealsense` en alguna parte de la misma. Si es así, sustitúyelo por `realsenseai` y prueba de nuevo. Hace algún tiempo, cuando la marca `RealSense` se separó de `Intel`, se hizo un proceso de rebranding, y en los enlaces se sustituyó `intelrealsense` por `realsenseai`, pero es posible que alguno de los enlaces de la documentación no se hayan actualizado correctamente.<br/>
Por ejemplo:<br/>
URL errónea: [https://dev.intelrealsense.com/docs/build-configuration](https://dev.intelrealsense.com/docs/build-configuration)<br/>
URL correcta: [https://dev.realsenseai.com/docs/build-configuration](https://dev.realsenseai.com/docs/build-configuration)<br/>

Finalmente, indicarte que en la URL [https://support.realsenseai.com/hc/en-us/community/posts/](https://support.realsenseai.com/hc/en-us/community/posts/) puedes encontrar una **FAQ** muy útil, con preguntas y respuestas sobre la librería `librealsense2` y sobre las cámaras RealSense en general.

En el fichero [examples.md](examples.md) tienes condensadas las operaciones que te he ido describiendo más arriba, pero en formato de comandos de terminal, para que puedas copiarlos y pegarlos directamente en tu terminal:

- Instalar reglas udev en el sistema operativo host para comunicarte con las cámaras RealSense.
- Desinstalar las reglas udev en el sistema operativo host para dejar de comunicarte con las cámaras RealSense.
- Parchear los módulos del kernel en el sistema operativo host para mejorar el soporte de las cámaras RealSense.
- Instalar la librería librealsense2 en el sistema operativo host.

Bueno, este es el final de la guía, espero que te haya sido de utilidad. Si tienes cualquier duda o pregunta, no dudes en contactarme.

¡Suerte con tu proyecto!