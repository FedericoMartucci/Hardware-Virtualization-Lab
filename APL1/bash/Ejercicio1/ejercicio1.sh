#! /bin/bash

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#
#               Virtualizacion de Hardware              #
#                                                       #
#   APL1                                                #
#   Nro ejercicio: 1                                    #
#   Nro entrega: 1                                      #
#   Nombre del script: ejercicio1.sh                    #
#                                                       #
#   Integrantes:                                        #
#                                                       #
#       Branchesi, Tomas Agustin      43013625          #
#       Martucci, Federico Ariel      44690247          #
#                                                       #
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#

declare directorioEntrada=""
declare rutaArchivoSalida=""
declare numerosGanadores=()
declare mostrarPorPantalla=false

function ayuda() {
    echo "USO: $0 [-d|--directorio <directorio_entrada_archivos_csv>] [-a|--archivo <ruta_archivo_json_salida>] [-p|--pantalla]"
    echo "DESCRIPCIÓN: Este script procesa archivos CSV de notas de finales y genera un archivo JSON con el resumen de las notas de los alumnos."
    echo "OPCIONES:"
    echo "  -d, --directorio   Ruta del directorio que contiene los archivos CSV a procesar."
    echo "  -a, --archivo      Ruta del archivo JSON de salida (incluyendo el nombre del archivo)."
    echo "  -p, --pantalla     Muestra la salida por pantalla en lugar de generar un archivo JSON."
    echo "  -h, --help         Muestra este mensaje de ayuda."
    echo "ACLARACIONES:"
    echo "  - Los parámetros -a o --archivo y -p o --pantalla no se pueden usar juntas."
}

opciones=$(getopt -o d:a:ph --long directorio:,archivo:,pantalla,help -- "$@" 2> /dev/null)

if [ "$?" != "0" ]; then
    echo "Opción/es incorrectas"
    exit 1
fi

eval set -- "$opciones"

while true; do
    case "$1" in
        -d | --directorio)
            directorioEntrada="$2"
            shift 2
            ;;
        -a | --archivo)
            rutaArchivoSalida="$2"
            shift 2
            ;;
        -p | --pantalla)
            mostrarPorPantalla=true
            shift
            ;;
        -h | --help)
            ayuda
            exit 0
            ;;
        --)
            shift
            break
            ;;
        *)
            echo "ERROR: Argumento desconocido: $1"
            exit 1
            ;;
    esac
done

# Verificar que se haya proporcionado el directorio de entrada correctamente
if ! [ -d "$directorioEntrada" ]; then
    echo "ERROR: Se debe especificar un directorio válido que contenga los archivos CSV."
    exit 1
fi

# Verificar que solo se haya proporcionado una opción de archivo
if [ "$mostrarPorPantalla" = true ] && [ -n "$rutaArchivoSalida" ]; then
    echo "ERROR: No se puede especificar la opción de pantalla (-p | --pantalla) junto con la opción de archivo (-a | --archivo)."
    exit 1
fi

# Verificar que se haya proporcionado la ruta de archivo correctamente
if [ "$mostrarPorPantalla" = false ]; then
    if [ -d "$rutaArchivoSalida" ]; then
        echo "ERROR: La ruta del archivo de salida es un directorio."
        exit 1
    fi

    touch "$rutaArchivoSalida" 2>/dev/null
    if [ $? -ne 0 ]; then
        echo "ERROR: Se debe especificar una ruta válida para guardar el archivo JSON."
        ayuda
        exit 1
    fi

    rm -f "$rutaArchivoSalida"

    extension="${rutaArchivoSalida##*.}"
    extension="${extension,,}"

    if [ "$extension" != "json" ]; then
        echo "ERROR: En la ruta del archivo de salida se debe especificar que este tendrá una extensión JSON."
        exit 1
    fi
fi

# Función para eliminar la extensión de los archivos
function eliminarExtensionArchivo() {
    echo "${1##*/}" | sed 's/\.[^.]*$//'
}

function obtenerNumerosGanadores() {
    local archivo="ganadores.csv"

    # Verifica que el archivo 'ganadores.csv' exista
    if [[ ! -f "$archivo" ]]; then
        return 1
    fi

    # Lee el contenido del archivo y guarda los números en una lista sin imprimirlos
    IFS=',' read -r -a numerosGanadores < "$archivo"

    # Retorna la lista
    echo "${numerosGanadores[@]}"
}

function contarAciertos() {
    local numerosGanadores=("$@") # Captura todos los argumentos como un array
    local aciertos=0

    # Convertimos los números ganadores en un string para la búsqueda
    local ganadoresStr="${numerosGanadores[*]}"

    # Iteramos sobre cada número jugado
    for numero in "${numerosJugados[@]}"; do
        if [[ " $ganadoresStr " == *" $numero "* ]]; then
            aciertos=$((aciertos + 1))
        fi
    done

    echo $aciertos
}

jsonData_5_aciertos=()
jsonData_4_aciertos=()
jsonData_3_aciertos=()

function procesarArchivos() {
    # Obtener los números ganadores y validar si se pudo leer correctamente
    numerosGanadores=($(obtenerNumerosGanadores))
    if [ $? -ne 0 ]; then
        echo "ERROR: El archivo ganadores.csv no existe en el directorio del script."
        exit 1  # Salir si no se puede obtener los números ganadores
    fi

    # Asegúrate de que haya archivos CSV en el directorio
    shopt -s nullglob
    local archivosCSV=("$directorioEntrada"/*.csv)

    for archivoCSV in "${archivosCSV[@]}"; do
        local agencia=$(eliminarExtensionArchivo "$archivoCSV")

        # Leer cada línea del archivo
        while IFS= read -r linea || [[ -n $linea ]]; do
            # Dividir la línea en jugada y números
            IFS=',' read -r jugada numeros <<< "$linea"

            # Asegurar que se procese cada línea adecuadamente
            if [[ -z "$jugada" || -z "$numeros" ]]; then
                continue
            fi

            IFS=',' read -ra numerosArray <<< "$numeros"

            # Cambia el nombre de la variable a 'numerosJugados' para evitar confusiones
            numerosJugados=("${numerosArray[@]}")
            local aciertos=$(contarAciertos "${numerosGanadores[@]}")

            if (( aciertos >= 3 )); then
                # Añadir la información al array correspondiente
                if (( aciertos == 5 )); then
                    jsonData_5_aciertos+=("    {\n      \"agencia\": \"$agencia\",\n      \"jugada\": \"$jugada\"\n    }")
                elif (( aciertos == 4 )); then
                    jsonData_4_aciertos+=("    {\n      \"agencia\": \"$agencia\",\n      \"jugada\": \"$jugada\"\n    }")
                elif (( aciertos == 3 )); then
                    jsonData_3_aciertos+=("    {\n      \"agencia\": \"$agencia\",\n      \"jugada\": \"$jugada\"\n    }")
                fi
            fi
        done < "$archivoCSV"
    done
}

function generarJson() {
    local json_output="{\n"

    json_output+="  \"5_aciertos\": [\n"
    for (( i=0; i<${#jsonData_5_aciertos[@]}; i++ )); do
        json_output+="${jsonData_5_aciertos[i]}"
        # Añadir coma si no es el último elemento
        if (( i < ${#jsonData_5_aciertos[@]} - 1 )); then
            json_output+=",\n"
        else
            json_output+="\n"
        fi
    done
    json_output+="  ],\n"

    json_output+="  \"4_aciertos\": [\n"
    for (( i=0; i<${#jsonData_4_aciertos[@]}; i++ )); do
        json_output+="${jsonData_4_aciertos[i]}"
        # Añadir coma si no es el último elemento
        if (( i < ${#jsonData_4_aciertos[@]} - 1 )); then
            json_output+=",\n"
        else
            json_output+="\n"
        fi
    done
    json_output+="  ],\n"

    json_output+="  \"3_aciertos\": [\n"
    for (( i=0; i<${#jsonData_3_aciertos[@]}; i++ )); do
        json_output+="${jsonData_3_aciertos[i]}"
        # Añadir coma si no es el último elemento
        if (( i < ${#jsonData_3_aciertos[@]} - 1 )); then
            json_output+=",\n"
        else
            json_output+="\n"
        fi
    done
    json_output+="  ]\n"
    json_output+="}"

    # Si el usuario eligió mostrar por pantalla
    if [ "$mostrarPorPantalla" = true ]; then
        echo -e "$json_output"
    else
        echo -e "$json_output" > "$rutaArchivoSalida"
        echo "El archivo fue generado exitosamente en la ruta $rutaArchivoSalida"
    fi

    
}

# Ejecutar la función principal para procesar los archivos
procesarArchivos

# Generar el JSON con los resultados
generarJson
