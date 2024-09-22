#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#
#               Virtualizacion de Hardware              #
#                                                       #
#   APL1                                                #
#   Nro ejercicio: 5                                    # 
#   Nro entrega: 1                                      #
#   Nombre del script: demonio.ps1                      # 
#                                                       #
#   Integrantes:                                        #
#                                                       #
#       Branchesi, Tomas Agustin      43013625          #
#       Martucci, Federico Ariel      44690247          #
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#

<#
.SYNOPSIS
Script para monitorear un directorio en busca de archivos duplicados y comprimirlos.

.DESCRIPTION
Este script monitorea un directorio especificado y detecta si se crean archivos duplicados. 
Cuando se detectan archivos duplicados (basados en el nombre y el tamaño), se registra la información en un archivo de log y se genera un archivo comprimido en formato ZIP con los archivos duplicados.

El script se ejecuta en segundo plano como un proceso "demonio".
Es posible detener este proceso si ya se está ejecutando, utilizando la opción -Kill.

.PARAMETER Directorio
Especifica el directorio a monitorear. El monitoreo incluye los subdirectorios de forma recursiva.

.PARAMETER Salida
Especifica el directorio donde se guardarán los archivos comprimidos y los logs generados por el script.

.PARAMETER Kill
Detiene el proceso "demonio" que está monitoreando el directorio especificado.

.EXAMPLE
.\script.ps1 -Directorio "C:\ruta\al\directorio" -Salida "C:\ruta\de\salida"

Este ejemplo inicia el monitoreo del directorio especificado y guarda los logs y archivos comprimidos en el directorio de salida.

.EXAMPLE
.\script.ps1 -Directorio "C:\ruta\al\directorio" -Salida "C:\ruta\de\salida" -Kill

Este ejemplo detiene el proceso "demonio" que está monitoreando el directorio especificado, si es que está en ejecución.

.NOTES
Consideraciones:
• Solo se consideran duplicados aquellos archivos que coinciden tanto en nombre como en tamaño.
• El archivo comprimido contiene el archivo original y todos los duplicados encontrados.
• El script utiliza un archivo PID para gestionar el estado del proceso en segundo plano.
• La compresión se realiza en formato ZIP.
#>

# Parámetros de entrada
[CmdletBinding()]
param (
    [Parameter(Mandatory = $true)]   
    [ValidateNotNullOrEmpty()] 
    [string]$Directorio,
    [Parameter(Mandatory = $false)]   
    [string]$Salida,
    [Parameter(Mandatory = $false)]
    [switch]$Kill
)

# Códigos de error
$Script:ERROR_PARAMETROS_INVALIDOS = 1
$Script:ERROR_ARGUMENTO_DESCONOCIDO = 2
$Script:ERROR_DIRECTORIO_INVALIDO = 3
$Script:ERROR_PARAMETROS_FALTANTES = 4
$Script:ERROR_DEMONIO_EXISTENTE = 5

# Validar que el directorio exista
if (-not (Test-Path -Path $Directorio -PathType Container)) {
    Write-Error "El directorio especificado no existe o no es válido: $Directorio"
    exit $ERROR_DIRECTORIO_INVALIDO
}

# Validar que al menos uno de los parámetros -Salida o -Kill esté presente
if (-not $Salida -and -not $Kill) {
    Write-Error "Debe ingresar una opción válida: -Salida o -Kill."
    exit $ERROR_PARAMETROS_FALTANTES
}

# Validar exclusividad mutua: no se puede usar -Salida y -Kill al mismo tiempo
if ($Salida -and $Kill) {
    Write-Error "Los parámetros -Salida y -Kill no pueden ser usados simultáneamente."
    exit $ERROR_PARAMETROS_INVALIDOS
}

# Validar que el directorio de salida exista cuando se usa -Salida
if ($Salida -and (-not (Test-Path -Path $Salida -PathType Container))) {
    Write-Error "El directorio de salida especificado no existe o no es válido: $Salida"
    exit $ERROR_DIRECTORIO_INVALIDO
}



