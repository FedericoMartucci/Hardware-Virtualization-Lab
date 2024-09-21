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
    El script muestra un listado con los nombres de los archivos duplicados y las rutas donde fueron encontrados.

.PARAMETER Directorio
    Ruta del directorio a analizar. Acepta tanto rutas absolutas como relativas.

.EXAMPLE
    ./ejercicio3.ps1 -directorio "C:\Ruta\Del\Directorio"

.NOTES
    El script acepta rutas con espacios y maneja errores de manera amigable.
#>



[CmdletBinding()]
param (
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$Directorio
)

# Exit codes
$Script:ERROR_DIRECTORIO_INVALIDO=1
$Script:ERROR_PERMISO_DENEGADO = 2
$Script:ERROR_PROCESO_ARCHIVO = 3

# Validar que el directorio exista
if (-not (Test-Path -Path $Directorio -PathType Container)) {
    Write-Error "El directorio especificado no existe o no es válido: $Directorio"
    exit $ERROR_DIRECTORIO_INVALIDO
}

try {
    $archivos = Get-ChildItem -Path $Directorio -Recurse -File -ErrorAction Stop

    #Se crea un grupo por nombre y tamaño
    $duplicados = $archivos | Group-Object Name, Length | Where-Object { $_.Count -gt 1 }

    if ($duplicados.Count -eq 0) {
        Write-Output "No se encontraron archivos duplicados."
    } else {
        foreach ($grupo in $duplicados) {
            Write-Output $grupo.Group[0].Name
            foreach ($archivo in $grupo.Group) {
                Write-Output "`t$archivo"
            }
        }
    }
} catch [System.UnauthorizedAccessException] {
    # Error de permisos
    Write-Error "Permiso denegado al intentar acceder a uno de los directorios o archivos: $($_.Exception.Message)"
    exit $ERROR_PERMISO_DENEGADO
} catch [System.Exception] {
    # Error general al procesar archivos
    Write-Error "Ocurrió un error al procesar los archivos: $($_.Exception.Message)"
    exit $ERROR_PROCESO_ARCHIVO
}

# Salir con código de éxito 0
exit 0