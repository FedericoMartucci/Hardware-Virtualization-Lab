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
declare mostrarPorPantalla=false;

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
    echo "  -a, --archivo      Ruta del archivo JSON de salida (no es un directorio, es la ruta completa incluyendo el nombre del archivo).";
    echo "  -p, --pantalla     Muestra la salida por pantalla, no genera el archivo JSON.";
    echo "  -h, --help         Muestra este mensaje de ayuda.";
    echo "ACLARACIONES:"
    echo "  - Para este ejercicio se utiliza el comando jq, por lo tanto, es necesaria su instalacion (sudo apt install jq)";
    echo "  - Los parámetros -a o --archivo y -p o --pantalla no se pueden usar a la vez."
}

# eliminarExtensionArchivo: Los utilizo para los archivos a procesar ya que sus nombre 
# tienen el nombre de la agencia.

function eliminarExtensionArchivo() {
    echo "$(basename "${1%.*}")";
}


# mostrarOGuardarArchivoJson: Determina segun los parametros de entrada, si se muestra
# por pantalla o si se almacena en un archivo JSON

function mostrarOGuardarArchivoJson() {
    if [ "$mostrarPorPantalla" = true ]; then
        echo "$jsonData";
    else
        echo "$jsonData" > "$rutaArchivoSalida";
        echo "El archivo JSON fue generado exitosamente en la ruta indicada $rutaArchivoSalida";
    fi
}


function main() {

    if ! ls "$directorioEntrada"/*.csv &>/dev/null; then
        echo "ERROR: No se encontraron archivos CSV en el directorio especificado.";
        exit $ERROR_DIRECTORIO_SIN_ARCHIVOS;
    fi

    numerosGanadores=$(awk -F"," '
        {
            for (i = 1; i <= NF; i++)
                numerosGanadores[$i]++
        }
        END {
            for (num in numerosGanadores)
                printf "%s ", num
        }
        ' ganadores.csv)

    for archivoCSV in "$directorioEntrada"/*.csv; do
        agencia=$(eliminarExtensionArchivo "$archivoCSV")
        awk -F"," -v agencia="$agencia" -v numerosGanadores="$numerosGanadores" -v error_num_campos="$ERROR_NUMERO_DE_CAMPOS_INCORRECTOS" -v error_num_jugado="$ERROR_NUMERO_JUGADO_INVALIDO" 'BEGIN {
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
                print "Jugada:", $1, "Agencia:", agencia, "Aciertos:", aciertos
                # TODO: acumular en un archivo o estructura JSON
            }
        }
        ' "$archivoCSV"
    done

# mostrarOGuardarArchivoJson;
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

    # Verifico que la ruta del archivo de salida exista creando un archivo temporal
    touch "$rutaArchivoSalida" 2>/dev/null;
    
    if ! touch "$rutaArchivoSalida" 2>/dev/null; then
        echo "ERROR: Se debe especificar una ruta válida para guardar el archivo JSON.";                
        exit $ERROR_RUTA_INVALIDA;     
    fi

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