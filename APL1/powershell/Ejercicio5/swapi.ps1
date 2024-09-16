#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#
#               Virtualizacion de Hardware              #
#                                                       #
#   APL1                                                #
#   Nro ejercicio: 2                                    #
#   Nro entrega: 1                                      #
#   Nombre del script: ejercicio2.ps1                   #
#                                                       #
#   Integrantes:                                        #
#                                                       #
#       Branchesi, Tomas Agustin      43013625          #
#       Martucci, Federico Ariel      44690247          #
#                                                       #
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#

<#
.SYNOPSIS
Script para consultar información de personajes y películas de Star Wars desde la API swapi.tech.

.DESCRIPTION
El script permite realizar consultas de personajes y películas por su ID, mostrando la información básica.
Permite manejar múltiples IDs tanto de personajes como de películas.


.PARAMETER people
IDs de personajes a consultar.

.PARAMETER film
IDs de películas a consultar.

.EXAMPLE
./swapi.ps1 -people 1,2 -film 1,2

.NOTES
Utiliza caché para evitar consultas repetidas a la API. Muestra mensajes adecuados en caso de error.
#>

param (
    [Parameter(Mandatory = $false)]
    [int[]]$people,

    [Parameter(Mandatory = $false)]
    [int[]]$film
)

$Script:ERROR_PARAMETROS_FALTANTES=1


# Validar que al menos un parámetro fue proporcionado
if (-not $people -and -not $film) {
    Write-Host "Error: Debe ingresar al menos un ID para 'people' o 'film'."
    exit $ERROR_PARAMETROS_FALTANTES
}


function Save-ToCache {
    param ($id, $type, $data)
    $cachePath = "$PSScriptRoot/cache/$type-$id.json"
    if (-not (Test-Path "$PSScriptRoot/cache")) {
        New-Item -Path "$PSScriptRoot/cache" -ItemType Directory | Out-Null
    }
    $data | Out-File -FilePath $cachePath
}

function Get-FromCache {
    param ($id, $type)
    $cachePath = "$PSScriptRoot/cache/$type-$id.json"
    if (Test-Path $cachePath) {
        return Get-Content $cachePath -Raw | ConvertFrom-Json
    } else {
        return $null
    }
}


function Get-FromAPI {
    param ($id, $type)

    $cacheData = Get-FromCache $id $type
    if ($cacheData) {
        return $cacheData
    }

    $api_url = "https://www.swapi.tech/api/$type/$id"
    try {
        #Aqui se realiza el llamado a la API
        $response = Invoke-RestMethod -Uri $api_url  -Method Get
        if ($response.message -contains "not found") {
            Write-Host "No se encontró información para $type con ID $id"
            return $null
        } else {
            Save-ToCache $id $type ($response.result | ConvertTo-Json)
            return $response.result
        }
    } catch {
        Write-Host "Error al consultar la API para $type con ID ${id} `n"
        return $null
    }
}

# Función para mostrar la información de los personajes
function Show-People {
    param ($peopleIds)
    foreach ($id in $peopleIds) {
        $data = Get-FromAPI $id 'people'
        if ($data) {
            Write-Host "Id: $($data.uid)"
            Write-Host "Name: $($data.properties.name)"
            Write-Host "Gender: $($data.properties.gender)"
            Write-Host "Height: $($data.properties.height)"
            Write-Host "Mass: $($data.properties.mass)"
            Write-Host "Birth Year: $($data.properties.birth_year)"
            Write-Host ""
        }
    }
}

# Función para mostrar la información de las películas
function Show-Films {
    param ($filmIds)
    foreach ($id in $filmIds) {
        $data = Get-FromAPI $id 'films'
        if ($data) {
            Write-Host "Title: $($data.properties.title)"
            Write-Host "Episode id: $($data.properties.episode_id)"
            Write-Host "Release date: $($data.properties.release_date)"
            Write-Host "Opening crawl: $($data.properties.opening_crawl)"
            Write-Host ""
        }
    }
}

# Procesar parámetros
if ($people) {
    Write-Host "Personajes:"
    Show-People $people
}

if ($film) {
    Write-Host "Peliculas:"
    Show-Films $film
}
