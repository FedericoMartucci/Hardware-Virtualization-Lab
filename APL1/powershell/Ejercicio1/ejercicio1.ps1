#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#
#               Virtualizacion de Hardware              #
#                                                       #
#   APL1                                                #
#   Nro ejercicio: 1                                    #
#   Nro entrega: 1                                      #
#   Nombre del script: ejercicio1.ps1                   #
#                                                       #
#   Integrantes:                                        #
#                                                       #
#       Branchesi, Tomas Agustin      43013625          #
#       Martucci, Federico Ariel      44690247          #
#                                                       #
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#

<#
.SYNOPSIS
Script para resumir la información de aciertos de los archivos CSV en un único archivo JSON.

.DESCRIPTION
Este script procesa los resultados de aciertos de varios archivos CSV y genera un resumen con la cantidad de aciertos de cada jugada. Los archivos CSV contienen números jugados por cada agencia, y el script compara esos números con los números ganadores para determinar los aciertos.
• Se consideran aciertos si los números jugados coinciden con los números ganadores.
• La cantidad de aciertos mínima considerada es 3.
• La salida puede ser en formato JSON o mostrarse por pantalla.

.PARAMETER directorio
Ruta del directorio que contiene los archivos CSV a procesar.

.PARAMETER archivo
Ruta del archivo JSON de salida.

.PARAMETER pantalla
Muestra la salida por pantalla, no genera el archivo JSON.

.EXAMPLE
.\ejercicio1.ps1 -directorio "C:\ruta\del\directorio" -archivo "C:\ruta\del\archivo.json"

.NOTES
Consideraciones:
• Solo se consideran archivos con extensión .csv.
• Los números jugados deben estar separados por comas en los archivos.
• La salida contiene los aciertos de cada agencia y jugada.
#>

param(
    [Parameter(Mandatory=$true)] [ValidateNotNullOrEmpty()]
    [string]$directorio,

    [Parameter(Mandatory=$false)] [ValidateNotNullOrEmpty()]
    [string]$archivo,

    [Parameter(Mandatory=$false)]
    [switch]$pantalla
)

# Verificar que solo se haya proporcionado una opción de salida o ninguna
if (($PSBoundParameters.ContainsKey('archivo') -and $pantalla) -or (-not $PSBoundParameters.ContainsKey('pantalla') -and -not $archivo)) {
    Write-Host "ERROR: Debe especificar la opción de pantalla (-pantalla) o la opción de archivo (-archivo), pero no ambas y no ninguna."
    exit 1
}

# Variables globales
$jsonData = [ordered]@{
    "5_aciertos" = @()
    "4_aciertos" = @()
    "3_aciertos" = @()
}

# Función para eliminar la extensión de los archivos
function eliminarExtensionArchivo($filePath) {
    return [System.IO.Path]::GetFileNameWithoutExtension($filePath)
}

# Función para obtener los números ganadores desde un archivo CSV
function obtenerNumerosGanadores {
    $numerosGanadores = @()

    # Usar $PSScriptRoot para obtener el directorio del script
    $rutaArchivo = Join-Path -Path $PSScriptRoot -ChildPath "ganadores.csv"

    # Verificar si el archivo de ganadores existe
    if (-not (Test-Path $rutaArchivo)) {
        Write-Host "ERROR: El archivo 'ganadores.csv' no existe en el directorio del script."
        exit 1
    }

    # Leer el archivo CSV y obtener los números ganadores
    Get-Content -Path $rutaArchivo | ForEach-Object {
        $numeros = $_ -split ','
        $numerosGanadores += $numeros
    }
    
    # Devolver los números únicos
    return $numerosGanadores | Select-Object -Unique
}

# Función para validar el número de campos
function validarNumeroCampos($datos) {
    if ($datos.Count -ne 6) {
        Write-Host "Error: Número incorrecto de campos en la línea $datos"
        return $false
    }
    return $true
}

# Función para contar los aciertos
function contarAciertos($numeros, $numerosGanadores) {
    $aciertos = 0
    foreach ($numero in $numeros) {
        if ($numero -in $numerosGanadores) {
            $aciertos++
        }
    }
    return $aciertos
}

# Función para procesar los archivos CSV y calcular los aciertos
function procesarArchivos {
    $numerosGanadores = obtenerNumerosGanadores

    Get-ChildItem -Path $directorio -Filter *.csv | ForEach-Object {
        $agencia = eliminarExtensionArchivo $_.FullName

        Get-Content $_.FullName | ForEach-Object {
            $datos = $_ -split ','
            $jugada = $datos[0] # Número de jugada
            $numeros = $datos[1..($datos.Count - 1)]

            if (-not (validarNumeroCampos $datos)) {
                exit 1
            }

            $aciertos = contarAciertos $numeros $numerosGanadores

            if ($aciertos -ge 3) {
                $jsonData["$aciertos`_aciertos"] += [ordered]@{
                    agencia = $agencia
                    jugada = $jugada
                }
            }
        }
    }
}

# Función para generar el archivo JSON a partir de los aciertos
function generarJson {
    $json_output = $jsonData | ConvertTo-Json
    
    if ($pantalla) {
        Write-Output $json_output
    } else {
        $json_output | Out-File -FilePath $archivo -Encoding utf8
        Write-Host "El archivo fue generado exitosamente en la ruta $archivo"
    }
}

# Ejecución principal
function main {
    if (-not (Test-Path $directorio)) {
        Write-Host "ERROR: El directorio especificado no existe."
        exit 1
    }

    procesarArchivos
    generarJson
}

main
