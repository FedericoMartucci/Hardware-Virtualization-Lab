#! /bin/bash

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#
#               Virtualizacion de Hardware              #
#                                                       #
#   APL1                                                #
#   Nro ejercicio: 3                                    #
#   Nro entrega: Reentrega                              #
#   Nombre del script: ejercicio3.sh                    #
#                                                       #
#   Integrantes:                                        #
#                                                       #
#       Branchesi, Tomas Agustin      43013625          #
#       Martucci, Federico Ariel      44690247          #
#                                                       #
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#

declare ERROR_DIRECTORIO_VACIO=1
declare ERROR_DIRECTORIO_INEXISTENTE=2

function ayuda() {
    echo "USO: $0 [-d|--directorio <directorio_a_analizar_duplicados>]"
    echo "DESCRIPCIÓN: Este script identifica archivos duplicados de forma recursiva. \
          Se considera que un archivo está duplicado si su nombre y tamaño son iguales."
    echo "OPCIONES:"
    echo "  -d, --directorio   Ruta del directorio a analizar."
    echo "  -h, --help         Muestra este mensaje de ayuda."
    exit 0
}
function buscar_duplicados(){
    local directorio=$1
    declare -A files
    declare -A duplicates

    # Buscar todos los archivos recursivamente
    while IFS= read -r -d '' file; do
        size=$(stat -c%s "$file")
        filename=$(basename "$file") 
        key="$filename|$size" 

        if [[ -n "${files[$key]}" ]]; then
            # Si ya existe en el array, lo añadimos a duplicados
            duplicates[$key]+=$'\t'"$file"
        else
            # Si no existe, lo añadimos al array de archivos
            files[$key]=$'\t'"$file"
        fi
    done < <(find "$directorio" -type f -print0)

    # Imprimir los archivos duplicados encontrados
    for key in "${!duplicates[@]}"; do
        echo "${key%%|*}" # Imprimir nombre del archivo
        echo -e "${files[$key]}\n${duplicates[$key]}"
    done
}

directorioEntrada=""

opciones=$(getopt -o d:h --l directorio:,help -- "$@" 2> /dev/null)

if [ "$?" != "0" ]; then
    echo "Opción/es incorrectas"
    exit 0
fi

eval set -- "$opciones"

while true; do
    case "$1" in
        -d|--directorio)
            directorioEntrada=$2
            shift 2
            ;;
        -h|--help)
            ayuda
            ;;
        --)
            shift
            break
            ;;
        *)
            echo "Error: Opción desconocida $1"
            ayuda
            ;;
    esac
done

# Verificar que se haya proporcionado un directorio de entrada no vacío
if [ -z "$directorioEntrada" ]; then
    echo "ERROR: Se debe especificar un directorio válido."
    exit $ERROR_DIRECTORIO_VACIO
fi

# Verificar que se haya proporcionado el directorio de entrada correctamente
if ! [ -d "$directorioEntrada" ]; then
    echo "ERROR: El directorio '$directorioEntrada' no existe."
    exit $ERROR_DIRECTORIO_INEXISTENTE
fi


buscar_duplicados "$directorioEntrada"
