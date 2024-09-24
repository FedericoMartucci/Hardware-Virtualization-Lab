#!/bin/bash


#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#
#               Virtualizacion de Hardware              #
#                                                       #
#   APL1                                                #
#   Nro ejercicio: 5                                    #
#   Nro entrega: 1                                      #
#   Nombre del script: swapi.sh                         #
#                                                       #
#   Integrantes:                                        #
#                                                       #
#       Branchesi, Tomas Agustin      43013625          #
#       Martucci, Federico Ariel      44690247          #
#                                                       #
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#

declare ID_INEXISTENTE=1;

# Función para mostrar un mensaje de uso
function ayuda() {
    echo "USO: $0 [-p|--people <ids_separados_por_comas>] [-f|--film <ids_separados_por_comas>]"
    echo "       $0 --help"
    echo
    echo "DESCRIPCIÓN:"
    echo "    Este script permite buscar información de personajes y películas del universo de Star Wars utilizando la API swapi.tech."
    echo "    Los resultados se muestran por pantalla y se guardan en un archivo de caché para evitar consultas repetidas."
    echo
    echo "OPCIONES:"
    echo "  -p, --people <ids_separados_por_comas>    IDs de los personajes a buscar. Puedes especificar uno o más IDs separados por comas."
    echo "  -f, --film <ids_separados_por_comas>      IDs de las películas a buscar. Puedes especificar uno o más IDs separados por comas."
    echo "  -h, --help                                Muestra este mensaje de ayuda."
    echo
    echo "ACLARACIONES:"
    echo "  - Se requiere tener instalado el comando jq (sudo apt install jq)."
    echo "  - Los parámetros --people y --film pueden usarse juntos para buscar múltiples personajes y películas en una sola ejecución."
    echo "  - Si se ingresa un ID inválido o la API retorna un error, se mostrará un mensaje acorde."
    exit 0;
}

# Función para consultar la API y manejar la caché
function buscar_data() {
    local type=$1
    local id=$2
    local cache_dir="./cache"

    mkdir -p "$cache_dir"

    local cache_file="$cache_dir/"$type$id".json"
    local api_url="https://www.swapi.tech/api/$type/$id"

    
    if [[ -s "$cache_file" ]]; then
        cat "$cache_file"
    else
        response=$(curl -s "$api_url")
        
        clean_response=$(echo "$response" | tr -cd '\11\12\15\40-\176')

        # Verificar si la respuesta es JSON válido
        if echo "$clean_response" | jq . > /dev/null 2>&1; then
            echo "$clean_response" | jq . > "$cache_file"
            cat "$cache_file"
        else
            echo "ERROR: Respuesta invalida para el tipo $type con ID: $id"
            echo "$clean_response"  # Imprimir la respuesta cruda para depuración
            return 1
        fi
    fi
}

function procesar_ids() {
    local type=$1
    local ids=$2
    local mensaje=""

    # Separar los IDs en un array utilizando la coma como separador
    IFS=',' read -r -a id_array <<< "$ids"

    # Iterar sobre cada ID y obtener los datos correspondientes
    for id in "${id_array[@]}"; do
        # Llamar a la función fetch_data para obtener datos de la API o caché
        data=$(buscar_data "$type" "$id")

        mensaje=$(echo "$data" | jq -r .message)
        
        if [[ "$mensaje" =~ "not found" ]]; then
            echo "El id $id de tipo $type proporcionado es un id invalido, pruebe con otro!"
        elif [[ "$type" == "people" ]]; then
            echo "$data" | jq --arg id "$id" -r '.result.properties | "\nId: \($id)\nName: \(.name)\nGender: \(.gender)\nHeight: \(.height)\nMass: \(.mass)\nBirth Year: \(.birth_year)"'
        elif [[ "$type" == "films" ]]; then
            echo "$data" | jq -r '.result.properties | "\nTitle: \(.title)\nEpisode id: \(.episode_id)\nRelease date: \(.release_date)\nOpening crawl: \(.opening_crawl)"'
        fi
    done
}

people_ids=""
film_ids=""

opciones=$(getopt -o p:f:h --long people:,film:,help -- "$@" 2> /dev/null)

if [ "$?" != "0" ]; then
    echo "Opcion/es incorrectas"
    ayuda;
    exit 0;
fi

eval set -- "$opciones"

# Leer argumentos
while true; do
    case $1 in
        --people|-p)
            shift
            people_ids=$1
            ;;
        --film|-f)
            shift
            film_ids=$1
            ;;
        --help|-h)
            ayuda
            ;;
        --)
            shift
            break
            ;;    
        *)
            echo "Error: Opción desconocida $1"
            ayuda; 
            ;;
    esac
    shift
done


if [[ -z "$people_ids" && -z "$film_ids" ]]; then
    echo "No se proporcionaron el/los datos requeridos"
    ayuda
fi

if [[ -n "$people_ids" ]]; then
    echo "Personajes:"
    procesar_ids "people" "$people_ids"
fi

if [[ -n "$film_ids" ]]; then
    echo -e "\nPelículas:"
    procesar_ids "films" "$film_ids"
fi
