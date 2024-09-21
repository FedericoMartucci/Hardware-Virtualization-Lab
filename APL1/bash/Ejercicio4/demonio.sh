#!/bin/bash

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#
#               Virtualizacion de Hardware              #
#                                                       #
#   APL1                                                #
#   Nro ejercicio: 4                                    #
#   Nro entrega: 1                                      #
#   Nombre del script: ejercicio4.sh                    #
#                                                       #
#   Integrantes:                                        #
#                                                       #
#       Branchesi, Tomas Agustin      43013625          #
#       Martucci, Federico Ariel      44690247          #
#                                                       #
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#

declare ERROR_PARAMETROS_INVALIDOS=1;
declare ERROR_ARGUMENTO_DESCONOCIDO=2;
declare ERROR_DIRECTORIO=3;
declare ERROR_ARGUMENTOS_FALTANTES=4;
declare ERROR_DEMONIO_EXISTENTE=5;

function mostrarAyuda() {
    echo "Modo de uso: bash $0 [opciones]"
    echo ""
    echo "Este script monitorea un directorio y detecta si se están creando archivos duplicados."
    echo "Cuando se detecta un duplicado (basado en nombre y tamaño), se genera un log y"
    echo "se crea un archivo comprimido con los archivos duplicados encontrados."
    echo ""
    echo "Opciones:"
    echo "  -d, --directorio    Especifica el directorio a monitorear. El monitoreo incluye subdirectorios."
    echo "  -s, --salida        Especifica el directorio donde se guardarán los logs y los archivos comprimidos."
    echo "  -k, --kill          Detiene el proceso demonio que está monitoreando el directorio."
    echo "  -h, --help          Muestra esta ayuda y termina la ejecución."
    echo ""
    echo "Ejemplos:"
    echo "  Ejecutar el monitoreo de un directorio y guardar los logs y backups:"
    echo "    bash $0 -d /ruta/al/directorio -s /ruta/al/directorio_de_salida"
    echo ""
    echo "  Detener el monitoreo de un directorio:"
    echo "    bash $0 -d /ruta/al/directorio --kill"
    echo ""
    echo "Consideraciones:"
    echo "  - Solo se permite un proceso demonio por directorio a la vez. Si ya existe un proceso"
    echo "    monitoreando el directorio especificado, no se permitirá iniciar otro."
    echo "  - El demonio queda corriendo en segundo plano automáticamente, sin necesidad de comandos adicionales."
    echo "  - Los archivos comprimidos generados tendrán el formato 'yyyyMMdd-HHmmss.tar.gz'."
    echo ""
    echo "Requisitos:"
    echo "  - inotify-tools debe estar instalado para monitorear cambios en el sistema de archivos."
    echo ""
}

function validarParametros() {
    # Se valida que el parametro --directorio sea un directorio valido.
    if [ ! -d "$1" ]; then
        echo "Error: \"$1\" no es un directorio"
        mostrarAyuda
        exit 1
    fi

    # Se valida que el parametro --directorio tenga permisos de lectura.
    if [ ! -r "$1" ]; then
        echo "Error: sin permisos de lectura en el directorio a monitorear"
        mostrarAyuda
        exit 1
    fi

    # Se valida que el parametro --salida sea un directorio valido.
    if [ ! -d "$2" ]; then
        echo "Error: \"$2\" no es un directorio de salida válido"
        mostrarAyuda
        exit 1
    fi

    #Se valida que el parametro --salida tenga permisos de escritura
    if [ ! -w "$2" ]; then
        echo "Error: sin permisos de escritura en el directorio de salida"
        mostrarAyuda
        exit 1
    fi

    return 0
}

function main() {
    directorio="$1"
    salida="$2"

    echo "Creando monitor para el directorio: $directorio. Backup en: $salida"
    
    # En caso de matar el proceso padre, debemos asegurarnos de finalizar
    # el proceso hijo, en este caso seria el proceso de inotifywait
    trap 'pkill -TERM -P $$; exit 0' SIGTERM SIGINT

    while true; do
        # Se evalua recursivamente los eventos de creacion y modificacion de archivos contenidos
        # en el directorio enviado por el parametro --directorio.
        inotifywait --recursive --event create --event modify "$directorio" | while read path action file; do
            archivo_completo="$path$file"
            nombre_archivo=$(basename "$file")
            tamano_archivo=$(stat -c%s "$archivo_completo")

            # Se busca duplicados en el directorio (por nombre y tamaño)
            duplicado=$(find "$directorio" -type f -not -path "$archivo_completo" -name "$nombre_archivo" -size "$tamano_archivo"c)

            if [[ -n "$duplicado" ]]; then
                timestamp=$(date +%Y%m%d-%H%M%S)
                
                # Se emite un log en el archivo de logs correspondiente con fecha y hora
                echo "INFO | Archivo duplicado encontrado: $archivo_completo" >> "$salida/log-$timestamp.txt"

                # Se crea archivo .tar.gz con fecha y hora
                tar -czf "$salida/$timestamp.tar.gz" "$archivo_completo" "$duplicado"
            fi
        done
    done
}

function existeDemonio() {
	nombrescript=$(readlink -f $0)
	dir_base=`dirname "$nombrescript"`
    pid_files=($(find "$dir_base" -name "*.pid" -type f))
    local pid directorio procesos rutaabs1 rutaabs2
    rutaabs1=$(readlink -e "$1")
    if [[ -z "$rutaabs1" ]]; then
        echo "El directorio proporcionado no existe."
        return 2
    fi
    for pid_file in "${pid_files[@]}"; do
        pid=$(cat "$pid_file")
        procesos=$(ps -p "$pid" -o args=)
        if [[ "$procesos" =~ -d\ ([^\ ]*) ]]; then
            directorio="${BASH_REMATCH[1]}"
            rutaabs2=$(readlink -e "$directorio")
            if [[ "$rutaabs1" == "$rutaabs2" ]]; then
                echo "El directorio '$1' está siendo monitoreado por el proceso con PID $pid."
                return 1
            fi
        fi
    done
    echo "El directorio '$1' no se encuentra monitoreado. Se procede a monitorearlo."
    return 0
}

function iniciarDemonio() {
    
    directorio=$2

    # Esta validación permite al script manejar de distinta
    # manera la ejecución en primer y segundo plano
	if [[ "$1" == "-nohup-" ]]; then
        salida=$3
        
  	 	existeDemonio "$directorio"
 		if [[ $? == 1 ]]; then
    	 	echo "ERROR: el demonio ya existe para el directorio indicado."
    	  	exit $ERROR_DEMONIO_EXISTENTE;
		fi
        
		# Lanzamos el proceso en segundo plano
		nohup bash $0 "$1" "-d" "$directorio" "-s" "$salida"  > /dev/null 2>&1 &
	else
        salida=$4
		nombrescript=$(readlink -f "$0")
		dir_base=$(dirname "$nombrescript")

		#Almacenamos el PID del proceso para luego eliminarlo e iniciamos el main
   	    pidFile="$dir_base/$$.pid";
		touch "$pidFile"
   	    echo $$ > "$pidFile"
		main "$directorio" "$salida"
	fi
}


function eliminarDemonioUnDirectorio() {
    nombreScript=$(readlink -f $0)
    dir_base=`dirname "$nombreScript"`

    # Verifica si $dir_base tiene un valor antes de usar find
    if [ -z "$dir_base" ]; then
        echo "ERROR: el directorio del script no está definido."
        exit $ERROR_DIRECTORIO;
    fi

    # Buscar archivos PID del demonio
    pid_files=($(find "$dir_base" -name "*.pid" -type f 2>/dev/null))
    for pid_file in "${pid_files[@]}"; do
        pid=$(cat "$pid_file")
        procesos=$(ps -p "$pid" -o args=)

        # Si el proceso monitorea el directorio correcto, lo matamos
        if [[ "$procesos" =~ "$1" ]]; then
            echo "Eliminando el demonio para el directorio '$1'..."
            
            # Mata todos los procesos hijos primero
            pkill -TERM -P "$pid" 
            kill "$pid"
            rm "$pid_file"

            exit 0
        fi
    done
    echo "No se encontró un demonio para el directorio '$1'."
}



# Procesamiento de argumentos con getopt
if [[ "$1" == "-nohup-" ]]; then
    shift # Elimina el -nohup- de los argumentos
	iniciarDemonio "$1" "$2" "$3" "$4"
else
    TEMP=$(getopt -o d:s:hk --long directorio:,salida:,help,kill -- "$@" 2> /dev/null)
    if [ "$?" != "0" ]; then
        echo "Opcion/es incorrectas";
        exit $ERROR_PARAMETROS_INVALIDOS;
    fi
    eval set -- "$TEMP"
fi

while true; do
    case "$1" in
        -d | --directorio)
            DIRECTORIO="$2"
            shift 2
            ;;
        -s | --salida)
            SALIDA="$2"
            shift 2
            ;;
        -h | --help)
            mostrarAyuda
            exit 0
            ;;
        -k | --kill)
            KILL="true"
            shift
            ;;
        --)
            shift
            break
            ;;
        *)
            echo "ERROR: Argumento desconocido: $1";
            exit $ERROR_ARGUMENTO_DESCONOCIDO;
            ;;
    esac
done

# Verificaciones
if [ "$KILL" == "true" ]; then
    eliminarDemonioUnDirectorio "$DIRECTORIO"
    exit 0
fi

if [ -z "$DIRECTORIO" ] || [ -z "$SALIDA" ]; then
    echo "ERROR: faltan argumentos obligatorios."
    exit $ERROR_ARGUMENTOS_FALTANTES
fi

validarParametros "$DIRECTORIO" "$SALIDA"
iniciarDemonio "-nohup-" "$DIRECTORIO" "$SALIDA"