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
# $Script:ERROR_PERMISOS_LECTURA = 6
# $Script:ERROR_PERMISOS_ESCRITURA = 7

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

function Global:Monitorear($FullPath, $accion, $Fecha) {
    $fechaMonitoreo=Get-Date -Date $Fecha -Format "yyyyMMdd-HHmmss"
    $logPath = "$Salida\log-$fechaMonitoreo.txt"
    New-Item -ItemType File -Path "$logPath"
    if($accion -eq "CHANGED"){
        #Añadimos el reporte al archivo log
        $name = [System.IO.Path]::GetFileName($FullPath)
        $size = (Get-Item $FullPath).length

        # Buscar archivos duplicados por nombre y tamaño
        $duplicates = Get-ChildItem -Path $Directorio -Recurse | Where-Object { $_.Name -eq $name -and $_.Length -eq $size }

        if ($duplicates.Count -gt 0) {
            $existingLog = Get-Content $logPath
            if (-not $existingLog) {
                Add-Content -Path $logPath -Value "INFO | Archivo duplicado encontrado: $name"
            }
            
            $zipFile = "$Salida\$fechaMonitoreo.zip" 
            Compress-Archive -Path $duplicates.FullName -DestinationPath $zipFile 
        }
    }
    if($accion -eq "RENAMED"){
        Add-Content "$log" "$Fecha $FullPath ha sido renombrado"
    }
    if($accion -eq "CREATED"){
        Add-Content "$log" "$Fecha $FullPath ha sido creado"
    }

}

function CrearMonitor {
    param (
        [string]$Directorio,
        [string]$Salida
    )

    # Crear el FileSystemWatcher
    $watcher = New-Object System.IO.FileSystemWatcher
    $watcher.Path = $Directorio
    $watcher.Filter = "*.*"  # Monitorea todos los archivos
    $watcher.IncludeSubdirectories = $true
    $watcher.EnableRaisingEvents = $true
    
    # Acción al detectar cambio
    $action = {
        $details = $event.SourceEventArgs
        $Name = $details.Name
        $FullPath = $details.FullPath
        $OldFullPath = $details.OldFullPath
        $OldName = $details.OldName

        # tipo de cambio:
        $ChangeType = $details.ChangeType

        # cuándo ocurrió el cambio:
        $Timestamp = $event.TimeGenerated

        $ev = ""
        switch ($ChangeType)
        {
            "Changed"  { $ev="CHANGED" }
            "Created"  { $ev="CREATED" }
            "Renamed"  { $ev="RENAMED" }
            
            # Cualquier tipo de cambio no controlado:
            default   {}
        }
        $FullPath = $details.FullPath

        Monitorear "$FullPath" $ev $Timestamp
    }


    Register-ObjectEvent -InputObject $watcher -EventName Changed -Action $action -SourceIdentifier "ChangedEvent" 
    Register-ObjectEvent -InputObject $watcher -EventName Created -Action $action -SourceIdentifier "CreatedEvent"
    Register-ObjectEvent -InputObject $watcher -EventName Renamed -Action $action -SourceIdentifier "RenamedEvent"

    # Crear el Job en segundo plano
    Start-Job -ScriptBlock {
        while ($true) {
            Start-Sleep -Seconds 1
        }
    }  
    # $handlers | ForEach-Object {
    #     Unregister-Event -SourceIdentifier $_.Name
    # }

    # # stop monitoring
    # $watcher.EnableRaisingEvents = $false
    
    # # remove the event handlers
    # $handlers | ForEach-Object {
    #     Unregister-Event -SourceIdentifier $_.Name
    # }
    
    # # event handlers are technically implemented as a special kind
    # # of background job, so remove the jobs now:
    # $handlers | Remove-Job
    
    # # properly dispose the FileSystemWatcher:
    # $watcher.Dispose()
    
    # Write-Warning "Event Handler disabled, monitoring ends."
    Write-Host "Monitoreo iniciado en segundo plano."
}

function IniciarDemonio {
    param (
        [string]$Directorio,
        [string]$Salida
    )

    # Definir la ruta del archivo PID
    $pidFile = "$Directorio\monitor-$([System.IO.Path]::GetFileName($Directorio)).pid"

    # Verificar si el archivo PID ya existe
    if (Test-Path $pidFile) {
        # Leer el PID almacenado en el archivo
        $pidDelArchivo = Get-Content $pidFile
        
        # Comprobar si el proceso con ese PID está corriendo
        if (Get-Job -Id $pidDelArchivo -ErrorAction SilentlyContinue) {
            Write-Host "El demonio ya existe para el directorio '$Directorio' con PID $pidDelArchivo." -ForegroundColor Red
            exit $ERROR_DEMONIO_EXISTENTE # Salir con código de error si ya hay un demonio corriendo
        } else {
            # Si el proceso ya no existe, eliminar el archivo PID
            Remove-Item $pidFile
        }
    }

    # Ejecutar el script en segundo plano
    $job = Start-Job -ArgumentList $Directorio, $Salida -ScriptBlock {
        param ($Directorio, $Salida)

        CrearMonitor -Directorio $Directorio -Salida $Salida

        # Mantener el demonio vivo
        while ($true) {
            Start-Sleep -Seconds 1  # Evitar el consumo excesivo de CPU
        }
    }

    # Guardar el PID del trabajo en segundo plano
    $jobPid = $job.Id
    Set-Content -Path $pidFile -Value $jobPid

    Write-Host "El demonio se ha iniciado en segundo plano con PID $jobPid." -ForegroundColor Green
}

function FinalizarDemonio {
    param (
        [string]$Directorio
    )

    # Definir la ruta del archivo PID
    $pidFile = "$Directorio\monitor-$([System.IO.Path]::GetFileName($Directorio)).pid"

    # Verificar si el archivo PID existe
    if (Test-Path $pidFile) {
        # Leer el PID almacenado en el archivo
        $pidDelArchivo = Get-Content $pidFile

        # Detener el proceso del trabajo en segundo plano
        Stop-Job -Id $pidDelArchivo
        Remove-Job -Id $pidDelArchivo
        Remove-Item $pidFile

        Write-Host "El demonio ha sido detenido." -ForegroundColor Yellow
    } else {
        Write-Host "No se encontró ningún demonio activo para el directorio '$Directorio'." -ForegroundColor Red
    }
}

# Procesar parámetros
if ($Kill) {
    FinalizarDemonio -Directorio $Directorio
} else {
    IniciarDemonio -Directorio $Directorio -Salida $Salida
}
exit 0
