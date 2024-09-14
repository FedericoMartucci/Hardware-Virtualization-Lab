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

function mostrarAyuda() {
    echo "Modo de uso: bash $0 [-d | --directorio] [Directorio de monitoreo] [ -s | --salida ] [Directorio de backup de archivos]\n"
    echo "Monitorear un directorio para ver si hay duplicados en este"
    echo "-d | --directorio    Indica el directorio a monitorear"
    echo "-s | --salida        Directorio de salida."
    echo "-k | --kill          Detener el demonio en ejecución."
    echo "  - Se requiere la instalación del comando inotifywait (sudo apt install inotify-tools).";
}

function validarParametros() {
    if [ ! -d "$1" ]; then
        echo "Error: \"$1\" no es un directorio"
        mostrarAyuda
        exit 1
    fi
    if [ ! -r "$1" ]; then
        echo "Error: sin permisos de lectura en el directorio a monitorear"
        mostrarAyuda
        exit 1
    fi
    if [ ! -d "$3" ]; then
        echo "Error: \"$3\" no es un directorio de salida válido"
        mostrarAyuda
        exit 1
    fi
    if [ ! -w "$3" ]; then
        echo "Error: sin permisos de escritura en el directorio de salida"
        mostrarAyuda
        exit 1
    fi
    return 0
}

function compararArchivos() {
    nombre_archivo=$(basename "$1")
    tamano_archivo=$(stat -c%s "$1")
    
    for archivo in $(find "$2" -type f -name "$nombre_archivo"); do
        if [ "$archivo" != "$1" ] && [ $(stat -c%s "$archivo") -eq "$tamano_archivo" ]; then
            echo "$archivo"
        fi
    done
}

function loop() {
  directorio="$1"
  salida="$2"

  echo "Iniciando demonio para el directorio: $directorio. Backup en: $salida"

    trap 'pkill -TERM -P $$; exit 0' SIGTERM SIGINT


  while true; do
    inotifywait -r -e create,modify "$directorio" | while read path action file; do
      archivo_completo="$path$file"
      nombre_archivo=$(basename "$file")
      tamano_archivo=$(stat -c%s "$archivo_completo")

      # Buscar duplicados en el directorio (por nombre y tamaño)
      duplicado=$(find "$directorio" -type f -not -path "$archivo_completo" -name "$nombre_archivo" -size "$tamano_archivo"c)

      if [[ -n "$duplicado" ]]; then
        timestamp=$(date +%Y%m%d-%H%M%S)
        echo "Archivo duplicado encontrado: $archivo_completo" >> "$salida/log-$timestamp.txt"

        # Crear archivo .tar.gz con fecha y hora
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
    echo "El directorio '$1' no está siendo monitoreado se procede con la ejecución."
    return 0
}

function iniciarDemonio() { 

	if [[ "$1" == "-nohup-" ]];then
		#por aca pasa la primera ejecución, abriendo mi script en segundo plano...
  	 	existeDemonio "$3"
 		if [[ $? -eq 1 ]];then
    	 	echo "el demonio ya existe"
    	  	exit 1;
		fi
        
		#lanzamos el proceso en segundo plano
		nohup bash $0 "$1" "$2" "$3" "$4" "$5"  > /dev/null 2>&1 &
	else
		nombrescript=$(readlink -f "$0")
		dir_base=$(dirname "$nombrescript")

		#por aca debería pasar la segunda ejecución pudiendo almacenar el PID del proceso para luego eliminarlo.
		#Tambien se inicia el loop
   	    pidFile="$dir_base/$$.pid";
		touch "$pidFile"
   	    echo $$ > "$pidFile"
		loop "$2" "$4"
	fi

    return 0
}


function eliminarDemonioUnDirectorio() {
    # Verifica si $dir_base tiene un valor antes de usar find
    if [ -z "$dir_base" ]; then
        echo "Error: 'dir_base' no está definido."
        return 1
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
	#por aqui debería de pasar la primera vez. luego la segunda con el nohup
    TEMP=$(getopt -o d:s:hk --long directorio:,salida:,help,kill -n "$0" -- "$@")
    if [ $? != 0 ]; then
        echo "Error: fallo en la interpretacion de los argumentos" >&2
        exit 1
    fi
    eval set -- "$TEMP"
fi

while true; do
    case "$1" in
        -d|--directorio)
            DIRECTORIO="$2"
            shift 2
            ;;
        -s|--salida)
            SALIDA="$2"
            shift 2
            ;;
        -h|--help)
            mostrarAyuda
            exit 0
            ;;
        -k|--kill)
            KILL="true"
            shift
            ;;
        --)
            shift
            break
            ;;
        *)
            echo "Error: Parámetro no reconocido $1"
            mostrarAyuda
            exit 1
            ;;
    esac
done

# Verificar si hay parámetros adicionales después de procesar getopt
if [[ $# -ne 0 ]]; then
    echo "Error: Parámetros adicionales no reconocidos: $@"
    mostrarAyuda
    exit 1
fi

#por aca solo pasa la primer ejecucion

# Inicializar dir_base
nombreScript=$(readlink -f $0)
dir_base=`dirname "$nombreScript"`
# Verificaciones
if [ "$KILL" == "true" ]; then
    eliminarDemonioUnDirectorio "$DIRECTORIO"
    exit 0
fi

if [ -z "$DIRECTORIO" ] || [ -z "$SALIDA" ]; then
    echo "Error: faltan argumentos obligatorios."
    mostrarAyuda
    exit 1
fi

validarParametros "$DIRECTORIO" "-s" "$SALIDA"
iniciarDemonio "-nohup-" "-d" "$DIRECTORIO" "-s" "$SALIDA"
