#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#
#               Virtualizacion de Hardware              #
#                                                       #
#   APL1                                                #
#   Nro ejercicio: 3                                    #
#   Nro entrega: 1                                      #
#   Nombre del script: ejercicio3.ps1                   #
#                                                       #
#   Integrantes:                                        #
#                                                       #
#       Branchesi, Tomas Agustin      43013625          #
#       Martucci, Federico Ariel      44690247          #
#                                                       #
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#


<#
.SYNOPSIS
    Identifica archivos duplicados en un directorio y subdirectorios basándose en el nombre y tamaño.

.DESCRIPTION
    Este script busca archivos duplicados en un directorio dado. Un archivo se considera duplicado si tiene el mismo nombre y tamaño que otro archivo, independientemente de su contenido. 
    El script guarda en un archivo de texto los nombres de los archivos duplicados y las rutas donde fueron encontrados

.PARAMETER Directorio
    Ruta del directorio a analizar. Acepta tanto rutas absolutas como relativas.

.EXAMPLE
    ./ejercicio3.ps1 -directorio "C:\Usuarios\Tomás\Documentos"

.NOTES
    El script acepta rutas con espacios y maneja errores
#>

[CmdletBinding()]
param (
    [Parameter(Mandatory = $true, HelpMessage = "Por favor, especifica la ruta del directorio.")]
    [ValidateNotNullOrEmpty()]
    [string]$Directorio
)

$ERROR_RUTA_INVALIDA = 1

# Obtener la ruta donde se está ejecutando el script
$scriptPath = $PSScriptRoot
$outputFile = Join-Path -Path $scriptPath -ChildPath "duplicados.txt"

# Validar que el directorio exista
if (-not (Test-Path -Path $Directorio -PathType Container)) {
    Write-Error "El directorio especificado no existe o no es válido: $Directorio"
    exit $ERROR_RUTA_INVALIDA
}

try {
    # Si el archivo existe, lo borramos antes de escribir
    if (Test-Path $outputFile) {
        Remove-Item $outputFile
    }

    # Obtener todos los archivos dentro del directorio y subdirectorios
    $archivos = Get-ChildItem -Path $Directorio -Recurse -File

    # Crear un grupo por nombre y tamaño
    $duplicados = $archivos | Group-Object Name, Length | Where-Object { $_.Count -gt 1 }

    if ($duplicados.Count -eq 0) {
        Set-Content -Path $outputFile -Value "No se encontraron archivos duplicados." 
    } else {
        foreach ($grupo in $duplicados) {
            Add-Content -Path $outputFile -Value $($grupo.Group[0].Name)
            foreach ($archivo in $grupo.Group) {
                Add-Content -Path $outputFile -Value "`t $archivo"
            }
            Add-Content -Path $outputFile -Value "`n"
        }
    }
    Write-Output "El resultado ha sido guardado en: $outputFile"
} catch {
    Write-Error "Ocurrió un error al procesar los archivos: $_"
}
