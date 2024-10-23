#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#
#               Virtualizacion de Hardware              #
#                                                       #
#   APL1                                                #
#   Nro ejercicio: 5                                    #
#   Nro entrega: Reentrega                              #
#   Nombre del script: swapi.ps1                        #
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
    Write-Error "Error: Debe ingresar al menos un ID para 'people' o 'film'."
    exit $ERROR_PARAMETROS_FALTANTES
}

function Save-ToCache {
    param ($id, $type, $data)
    
    $cachePath = "/tmp/swapi_cache/$type-$id.json"

    if (-not (Test-Path "/tmp/swapi_cache")) {
        New-Item -Path "/tmp/swapi_cache" -ItemType Directory | Out-Null
    }
    $data | Out-File -FilePath $cachePath
}

function Get-FromCache {
    param ($id, $type)

    $cachePath = "/tmp/swapi_cache/$type-$id.json"

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
            Write-Output "No se encontró información para $type con ID $id."
            return $null
        } else {
            Save-ToCache $id $type ($response.result | ConvertTo-Json)
            return $response.result
        }
    } catch {
        Write-Host "Error al consultar la API para $type con ID ${id}: $($_.Exception.Message)" -ForegroundColor Red
        return $null
    }
}

# Función para mostrar la información de los personajes
function Show-People {
    param ($peopleIds)
    foreach ($id in $peopleIds) {
        $data = Get-FromAPI $id 'people'
        if ($data) {
            Write-Output "Id: $($data.uid)"
            Write-Output "Name: $($data.properties.name)"
            Write-Output "Gender: $($data.properties.gender)"
            Write-Output "Height: $($data.properties.height)"
            Write-Output "Mass: $($data.properties.mass)"
            Write-Output "Birth Year: $($data.properties.birth_year)"
            Write-Output ""
        }
    }
}

# Función para mostrar la información de las películas
function Show-Films {
    param ($filmIds)
    foreach ($id in $filmIds) {
        $data = Get-FromAPI $id 'films'
        if ($data) {
            Write-Output "Title: $($data.properties.title)"
            Write-Output "Episode id: $($data.properties.episode_id)"
            Write-Output "Release date: $($data.properties.release_date)"
            Write-Output "Opening crawl: $($data.properties.opening_crawl)"
            Write-Output ""
        }
    }
}

# Procesar parámetros
if ($people) {
    Write-Output "Personajes:"
    Show-People $people
}

if ($film) {
    Write-Output "Peliculas:"
    Show-Films $film
}
