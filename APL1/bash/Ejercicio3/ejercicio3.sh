#! /bin/bash

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#
#               Virtualizacion de Hardware              #
#                                                       #
#   APL1                                                #
#   Nro ejercicio: 3                                    #
#   Nro entrega: 1                                      #
#   Nombre del script: ejercicio3.sh                    #
#                                                       #
#   Integrantes:                                        #
#                                                       #
#       Branchesi, Tomas Agustin      43013625          #
#       Martucci, Federico Ariel      44690247          #
#                                                       #
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#

declare ERROR_DIRECTORIO_VACIO=1;
declare ERROR_DIRECTORIO_INEXISTENTE=2;

function ayuda(){
    echo "USO: $0 [-d|--directorio <directorio_a_analizar_duplicados>]";
    echo "DESCRIPCIÓN: Este script identifica archivos duplicados de forma recursiva. \
          Se considera que un archivo está duplicado si su nombre y tamaño son iguales.";
    echo "OPCIONES:";
    echo "  -d, --directorio   Ruta del directorio a analizar.";
    echo "  -h, --help         Muestra este mensaje de ayuda.";
    exit 0
}

function buscar_duplicados(){
    # Ejecuto `ls -ltR` y se lo paso a un AWK con arrays asociativos para guardar info de los archivos:
    #   - Key: <nombre_archivo>-<tamaño_archivo>
    #   - Value: [<path_1>, <path_2>, <path_3>]
    
    local directorio=$1

    find $directorio -type f -exec ls -l {} + | awk '
    {
        # Obtenemos el tamaño del archivo (campo 5) y su nombre completo con ruta (campo 9)
        size = $5
        filename = $9

        gsub(".*/", "", filename)
        
        # Guardamos en un array asociativo, donde la clave es "nombre|tamaño"
        key = filename "|" size
        
        # Si la clave ya existe, significa que el archivo es duplicado

        if (files[key] != "") {
            if(duplicates[key] != "") {
                duplicates[key] = duplicates[key] "\n\t" $9
            }
            else {
                duplicates[key] = files[key] "\n\t" $9
            }
        } else {
            files[key] = "\t" $9
        }
    }

    END {
        # Imprimir los archivos duplicados
        
        for (key in duplicates) {
            split(key, arr, "|")  # Separa el nombre y el tamaño
            print arr[1]  # Imprime el nombre del archivo
            
            # Imprime todas las rutas en las que se encontró el duplicado
            print duplicates[key]
        }
    }
    '
}

directorioEntrada=""

opciones=$(getopt -o d:h --l directorio:,help -- "$@" 2> /dev/null);

if [ "$?" != "0" ]; then
    echo "Opcion/es incorrectas";
    exit 0;
fi

eval set -- "$opciones";

while true; do
    case "$1" in
        -d|--directorio)
            directorioEntrada=$2
            shift 2;
            ;;
        -h|--help)
            ayuda 
            ;;
        --)
            shift;
            break;
            ;;
        *)echo "Error: Opción desconocida $1"
            ayuda
            ;; 
    esac
done

# Verificar que se haya proporcionado un directorio de entrada no vacio
if [ -z "$directorioEntrada" ]; then
    echo "ERROR: Se debe especificar un directorio válido.";
    exit $ERROR_DIRECTORIO_VACIO;
fi

# Verificar que se haya proporcionado el directorio de entrada correctamente
if ! [ -d "$directorioEntrada" ]; then
    echo "ERROR: El directorio '$directorioEntrada' no existe.";
    exit $ERROR_DIRECTORIO_INEXISTENTE;
fi

buscar_duplicados "$directorioEntrada"
