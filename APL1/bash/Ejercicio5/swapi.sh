#!/bin/bash


#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#
#               Virtualizacion de Hardware              #
#                                                       #
#   APL1                                                #
#   Nro ejercicio: 5                                    #
#   Nro entrega: 1                                      #
#   Nombre del script: ejercicio5.sh                    #
#                                                       #
#   Integrantes:                                        #
#                                                       #
#       Branchesi, Tomas Agustin      43013625          #
#       Martucci, Federico Ariel      44690247          #
#                                                       #
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#

# Función para mostrar un mensaje de uso
function ayuda() {
    echo "Como usar este script: $0 "
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

    
    if [[ -f "$cache_file" ]]; then
        cat "$cache_file"
    else
        response=$(curl -s "$api_url")

        #tener siempre en cuenta, que los json pueden venir con data
        #que el jq no puede procesar como headers y demas cosas,
        #sin esta linea, no funca nada jeee
        clean_response=$(echo "$response" | tr -cd '\11\12\15\40-\176')

        # Verificar si la respuesta es JSON válido
        if echo "$clean_response" | jq . > /dev/null 2>&1; then
            echo "$clean_response" | jq . > "$cache_file"
            cat "$cache_file"
        else
            echo "Error: Invalid response for $type ID: $id"
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
        #echo "aqui esta la data!"
        echo "$data"

        mensaje=$(echo "$data" | jq -r .message)
        
        if [[ "$mensaje" == "not found" ]]; then
            echo "El id proporcionado es un id invalido, pruebe con otro!"
            exit $ID_INEXISTENTE;
        fi    

        if [[ "$type" == "people" ]]; then
            echo "$data" | jq -r '.result.properties | "\nName: \(.name)\nGender: \(.gender)\nHeight: \(.height)\nMass: \(.mass)\nBirth Year: \(.birth_year)"'
        elif [[ "$type" == "films" ]]; then
            echo "$data" | jq -r '.result.properties | "\nTitle: \(.title)\nEpisode id: \(.episode_id)\nRelease date: \(.release_date)\nOpening crawl: \(.opening_crawl)"'
        fi
    done
}

people_ids=""
film_ids=""

# Leer argumentos
while [[ $# -gt 0 ]]; do
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
    echo ""
    echo "Películas:"
    procesar_ids "films" "$film_ids"
fi
