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

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ Variables ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

# Variables en donde se van a almacenar los parametros de entrada
declare directorioEntrada="";
declare rutaArchivoSalida="";
declare numerosGanadores="";
declare mostrarPorPantalla=false;

# Vector asociativo en donde se van a guardar la cantidad aciertos de cada jugada por agencia
declare -A vectorAciertos;

# Variable en formato JSON para guardar en el archivo de salida o mostrarlo por pantalla
declare jsonData=$(jq -n '{ "5_aciertos": [], "4_aciertos": [], "3_aciertos": [] }');

# Variables para retorno de errores (exit)
declare ERROR_PARAMETROS_INVALIDOS=1;
declare ERROR_ARGUMENTO_DESCONOCIDO=2;
declare ERROR_DIRECTORIO=3;
declare ERROR_ARCHIVO_SALIDA_Y_PANTALLA=4;
declare ERROR_DIRECTORIO_SIN_ARCHIVOS=5;
declare ERROR_EXTENSION=6;
declare ERROR_RUTA_INVALIDA=7;
declare ERROR_NUMERO_DE_CAMPOS_INCORRECTOS=8;
declare ERROR_NUMERO_JUGADO_INVALIDO=9;

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ Funciones ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

function ayuda() {
    echo "USO: $0 [-d|--directorio <directorio_entrada_archivos_csv>] [-s|--salida <ruta_archivo_json_salida>] [-p|--pantalla]";
    echo "DESCRIPCIÓN: Este script procesa archivos CSV de notas de finales y genera un archivo JSON con el resumen de las notas de los alumnos.";
    echo "OPCIONES:";
    echo "  -d, --directorio   Ruta del directorio que contiene los archivos CSV a procesar.";
    echo "  -a, --archivo      Ruta del archivo JSON de salida (incluyendo el nombre del archivo).";
    echo "  -p, --pantalla     Muestra la salida por pantalla en lugar de generar un archivo JSON.";
    echo "  -h, --help         Muestra este mensaje de ayuda.";
    echo "ACLARACIONES:"
    echo "  - Se requiere la instalación del comando jq (sudo apt install jq).";
    echo "  - Los parámetros -a o --archivo y -p o --pantalla no se pueden usar juntas."
}

# eliminarExtensionArchivo: Los utilizo para los archivos a procesar ya que sus nombre 
# tienen el nombre de la agencia.

function eliminarExtensionArchivo() {
    echo "$(basename "${1%.*}")";
}

# imprimirArchivoJson: determina segun los parametros de entrada, si se muestra
# por pantalla o si se almacena en un archivo JSON

function imprimirArchivoJson() {
    if [ "$mostrarPorPantalla" = true ]; then
        echo "$jsonData";
    else
        echo "$jsonData" > "$rutaArchivoSalida";
        echo "El archivo JSON fue generado exitosamente en la ruta indicada $rutaArchivoSalida";
    fi
}

# generarJson: toma cada clave del array vectorAciertos,
# extrae los valores de agencia, jugada y el número de aciertos.
# Actualiza el objeto JSON jsonData agregando los datos a la sección
# correspondiente basada en el número de aciertos.

function generarJson() {
    for clave in "${!vectorAciertos[@]}"; do
        agencia=$(echo "$clave" | cut -d '-' -f1);
        jugada=$(echo "$clave" | cut -d '-' -f2);
        aciertos=${vectorAciertos["$clave"]};

        # Al procesar el archivo se filtra por aquellas jugadas que tuvieron entre 3 y 5 aciertos,
        # con lo cual no es necesario hacer un case para cada caso en particular,
        # de esta forma trabajamos con un JSON de forma dinamica.
        jsonData=$(
            echo "$jsonData" |              \
            jq --arg aciertos "$aciertos"   \
            --arg agencia "$agencia"        \
            --arg jugada "$jugada"          \
            '.["\($aciertos)_aciertos"] += [{ agencia: $agencia, jugada: $jugada }]'
        );
    done
}

# obtenerNumerosGanadores: lee el archivo de los numeros ganadores,
# cuenta las frecuencias de cada número en el archivo y guarda la lista
# de números únicos encontrados en la variable numerosGanadores.
function obtenerNumerosGanadores() {
    numerosGanadores=$(awk -F"," '
        {
            for (i = 1; i <= NF; i++)
                numerosGanadores[$i]++
        }
        END {
            for (num in numerosGanadores)
                printf "%s ", num
        }
        ' ganadores.csv
    )
}

# procesarArchivos: procesa archivos CSV en un directorio,
# valida y cuenta aciertos según reglas especificadas,
# y guarda los resultados en un archivo temporal.

function procesarArchivos() {
    # Creo archivo temporal para guardar los resultados post-procesamiento
    archivo_temporal=$(mktemp)

    for archivoCSV in "$directorioEntrada"/*.csv; do
        agencia=$(eliminarExtensionArchivo "$archivoCSV")
        awk -F"," \
        -v agencia="$agencia" \
        -v numerosGanadores="$numerosGanadores" \
        -v error_num_campos="$ERROR_NUMERO_DE_CAMPOS_INCORRECTOS" \
        -v error_num_jugado="$ERROR_NUMERO_JUGADO_INVALIDO" 'BEGIN {
            # Dividir la variable numerosGanadores en un array asociativo usando espacios como separador
            split(numerosGanadores, ganadoresArray, " ")
            
            # Guardar los números ganadores en el array asociativo "ganadores"
            for (i in ganadoresArray) {
                ganadores[ganadoresArray[i]] = 1
            }
        }
        {
            # Validar que los registros no tengan NF != 6
            if (NF != 6) {
                print "Error: El archivo", FILENAME, "tiene un número incorrecto de campos en la línea", NR
                exit error_num_campos
            }

            # Validar que los números jugados estén entre 0 y 99 + logica de aciertos
            aciertos = 0
            for (i = 2; i <= NF; i++) {
                # Elimino el \r generado por un salto de linea en Windows (\r\n) ya que Linux no lo detecta y causa comportamientos inesperados.
                gsub(/\r/, "", $i)

                if ($i < 0 || $i > 99) {
                    print "Error: El archivo", FILENAME, "tiene números fuera del rango permitido en la línea", NR
                    exit error_num_jugado
                }

                if (ganadores[$i]) {
                    aciertos++
                }
            }

            # Generar el registro si hay 3, 4 o 5 aciertos
            if (aciertos >= 3) {
                print agencia "-" NR, aciertos;
            }
        }
       ' "$archivoCSV" >> "$archivo_temporal"
    done
}

# llenarArrayDesdeArchivoTemporal: carga los datos del archivo temporal
# en el array vectorAciertos y luego elimina el archivo temporal.

function llenarArrayDesdeArchivoTemporal() {
    while read -r clave aciertos; do
        vectorAciertos["$clave"]=$aciertos
    done < "$archivo_temporal"

    # Limpiar archivo temporal
    rm "$archivo_temporal"
}

function main() {
    if ! ls "$directorioEntrada"/*.csv &>/dev/null; then
        echo "ERROR: No se encontraron archivos CSV en el directorio especificado.";
        exit $ERROR_DIRECTORIO_SIN_ARCHIVOS;
    fi

    obtenerNumerosGanadores;
    procesarArchivos;
    llenarArrayDesdeArchivoTemporal;
    generarJson;
    imprimirArchivoJson;
}

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ Manejo de las opciones ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

opciones=$(getopt -o d:a:ph --l directorio:,archivo:,pantalla,help -- "$@" 2> /dev/null);

if [ "$?" != "0" ]; then
    echo "Opcion/es incorrectas";
    exit $ERROR_PARAMETROS_INVALIDOS;
fi

eval set -- "$opciones";

while true; do
    case "$1" in
        -d | --directorio)
            directorioEntrada="$2";
            shift 2;
            ;;
        -a | --archivo)
            rutaArchivoSalida="$2";
            shift 2;
            ;;
        -p | --pantalla)
            mostrarPorPantalla=true;
            shift;
            ;;
        --)
            shift;
            break;
            ;;
        -h | --help)
            ayuda;
            exit 0;
            ;;
        *)
            echo "ERROR: Argumento desconocido: $1";
            exit $ERROR_ARGUMENTO_DESCONOCIDO;
            ;;
    esac
done

# Verificar que se haya proporcionado el directorio de entrada correctamente
if ! [ -d "$directorioEntrada" ]; then
    echo "ERROR: Se debe especificar un directorio válido que contenga los archivos CSV.";
    exit $ERROR_DIRECTORIO;
fi

# Verificar que solo se haya proporcionado una opción de archivo
if [ "$mostrarPorPantalla" = true ] && [ -n "$rutaArchivoSalida" ]; then
    echo "ERROR: No se puede especificar la opción de pantalla (-p | --pantalla) junto con la opción de archivo (-a | --archivo).";
    exit $ERROR_ARCHIVO_SALIDA_Y_PANTALLA;
fi

# Verificar que se haya proporcionado la ruta de archivo correctamente
if [ "$mostrarPorPantalla" = false ]; then
    
    # Verifico que la ruta del archivo de salida no sea un directorio
    if [ -d "$rutaArchivoSalida" ]; then
        echo "ERROR: La ruta del archivo de salida es un directorio.";
        exit $ERROR_DIRECTORIO;
    fi

    # Verifico que la ruta de salida exista creando un archivo temporal
    touch "$rutaArchivoSalida" 2>/dev/null;
    
    if [ $? -ne 0 ]; then
        echo "ERROR: Se debe especificar una ruta válida para guardar el archivo JSON.";         
        ayuda;        
        exit $ERROR_RUTA_INVALIDA;     
    fi
    
    # Eliminar el archivo temporal si se creó
    rm -f "$rutaArchivoSalida";

    # Verifico que el archivo indicado en la ruta de salida tenga como extension JSON
    extension="${rutaArchivoSalida##*.}";

    extension="${extension,,}";

    if [ "$extension" != "json" ]; then
        echo "ERROR: En la ruta del archivo de salida se debe especificar que este tendra una extensión JSON.";
        exit $ERROR_EXTENSION;
    fi

fi

# ================================= Ejecución =================================

main;