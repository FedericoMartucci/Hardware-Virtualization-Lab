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

function Global:zipear {
    Param(
        [string] $pathArchivoAZipear,
        [string] $rutaRelativaArchivo,
        [string] $nombreZip
    )
    Add-Type -AssemblyName System.IO.Compression.FileSystem

    # Si no existe el archivo zip, lo crea.
    if (!(Test-Path "$nombreZip")) {
        $zip = [System.IO.Compression.ZipFile]::Open("$nombreZip", "create");
        $zip.Dispose();
    }
    
    $compressionLevel = [System.IO.Compression.CompressionLevel]::Fastest
    $zip = [System.IO.Compression.ZipFile]::Open($nombreZip, "update");

    # Verificar si el archivo ya existe en el ZIP para evitar duplicados
    $entryExists = $zip.Entries | Where-Object { $_.FullName -eq $rutaRelativaArchivo }
    if (-not $entryExists) {
        [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip, "$pathArchivoAZipear", "$rutaRelativaArchivo", $compressionLevel);
    }

    # Liberamos el recurso
    $zip.Dispose();
}

function Global:Monitorear {
    param (
        [string]$FullPath,
        [string]$Timestamp
    )

    # Convertir la ruta relativa a absoluta
    $rutaDirectorioAbs = Resolve-Path -Path $Directorio
    $rutaSalidaAbs = Resolve-Path -Path $Salida

    $fechaMonitoreo=Get-Date -Date $Timestamp -Format "yyyyMMdd-HHmmss"
    $logPath = "$rutaSalidaAbs/log-$fechaMonitoreo.txt"

    #Añadimos el reporte al archivo log
    $name = [System.IO.Path]::GetFileName($FullPath)
    $size = (Get-Item $FullPath).length

    # Buscar archivos duplicados por nombre y tamaño
    $duplicates = Get-ChildItem -Path $Dir -Recurse | Where-Object {
        $_.Name -eq $name -and $_.Length -eq $size -and $_.FullName -ne $FullPath
    }
    if ($duplicates.Count -gt 0) {
        # Crear el archivo log si no existe
        if (-not (Test-Path $logPath)) {
            New-Item -ItemType File -Path "$logPath" -Force
        }
        
        # Evitar duplicar mensajes de log
        if (-not (Select-String -Path $logPath -Pattern "INFO | Archivo duplicado encontrado: $name")) {
            Add-Content -Path $logPath -Value "INFO | Archivo duplicado encontrado: $name"
        }

        # Indicamos el nombre del archivo zip
        $zipPath = "$rutaSalidaAbs/$fechaMonitoreo.zip"

        # Zipear todos los duplicados incluyendo el archivo original
        $rutaRelativa = [System.IO.Path]::GetRelativePath($rutaDirectorioAbs, $FullPath)
        zipear -pathArchivoAZipear $FullPath -rutaRelativaArchivo $rutaRelativa -nombreZip $zipPath
        foreach ($item in $duplicates) {
            $rutaRelativaItem = [System.IO.Path]::GetRelativePath($rutaDirectorioAbs, $item.FullName)
            zipear -pathArchivoAZipear $item.FullName -rutaRelativaArchivo $rutaRelativaItem -nombreZip $zipPath
        }
    }

}

function CrearMonitor {
    param (
        [string]$Directorio,
        [string]$Salida,
        [string]$HashEventos
    )

    # Crear el FileSystemWatcher
    $global:watcher = New-Object System.IO.FileSystemWatcher
    $watcher.Path = Resolve-Path -Path $Directorio
    $watcher.Filter = "*.*"  # Monitorea todos los archivos
    $watcher.IncludeSubdirectories = $true
    $watcher.EnableRaisingEvents = $true
    
    # Acción al detectar cambio
    $action = {
        $details = $event.SourceEventArgs
        $FullPath = $details.FullPath
        $Timestamp = $event.TimeGenerated

        Monitorear -FullPath $FullPath -Timestamp $Timestamp
    }

    $global:handlers = . {
        Register-ObjectEvent $watcher -EventName Changed -Action $action -SourceIdentifier "ChangedEvent-$HashEventos" 
        Register-ObjectEvent $watcher -EventName Created -Action $action -SourceIdentifier "CreatedEvent-$HashEventos"
        Register-ObjectEvent $watcher -EventName Renamed -Action $action -SourceIdentifier "RenamedEvent-$HashEventos"
    }
    
    # Crear el Job en segundo plano
    $job = Start-Job -ScriptBlock {
       param ($Directorio, $Salida)
        while ($true) {
            Start-Sleep -Seconds 1  # Evitar el consumo excesivo de CPU
        }
    } -ArgumentList $Directorio, $Salida
    
    $jobId = $job.Id

    Set-Content -Path $pidFile -Value $jobId

    Write-Host "El demonio se ha iniciado en segundo plano con ID $jobId." -ForegroundColor Green
}

function IniciarDemonio {
    param (
        [string]$Directorio,
        [string]$Salida
    )

    # Generar el hash MD5 del directorio y crear el nombre del archivo PID
    $rutaDirectorioAbs = Resolve-Path -Path $Directorio
    $hash = (Get-FileHash -Algorithm MD5 -InputStream ([System.IO.MemoryStream]::new([System.Text.Encoding]::UTF8.GetBytes($rutaDirectorioAbs)))).Hash
    $pidFile = "/tmp/monitor_$hash.pid"

    # Verificar si el archivo PID ya existe
    if (Test-Path $pidFile) {
        # Leer el PID almacenado en el archivo
        $pidDelArchivo = Get-Content $pidFile
        
        # Comprobar si el proceso con ese PID está corriendo
        if (Get-Job -Id $pidDelArchivo -ErrorAction SilentlyContinue) {
            Write-Host "El demonio ya existe para el directorio '$Directorio' con ID $pidDelArchivo." -ForegroundColor Red
            exit $ERROR_DEMONIO_EXISTENTE # Salir con código de error si ya hay un demonio corriendo
        } else {
            # Si el proceso ya no existe, eliminar el archivo PID
            Remove-Item $pidFile
        }
    }

    # Ejecutar el script en segundo plano
    CrearMonitor -Directorio $Directorio -Salida $Salida -HashEventos $hash
}

function FinalizarDemonio {
    param (
        [string]$Directorio
    )

    # Generar el hash MD5 del directorio y crear el nombre del archivo PID
    $rutaDirectorioAbs = Resolve-Path -Path $Directorio
    $hash = (Get-FileHash -Algorithm MD5 -InputStream ([System.IO.MemoryStream]::new([System.Text.Encoding]::UTF8.GetBytes($rutaDirectorioAbs)))).Hash
    $pidFile = "/tmp/monitor_$hash.pid"

    # Verificar si el archivo PID existe
    if (Test-Path $pidFile) {
        # Leer el PID almacenado en el archivo
        $pidDelArchivo = Get-Content $pidFile

        # Detener el proceso del trabajo en segundo plano
        Stop-Job -Id $pidDelArchivo
        $handlers | ForEach-Object {
            Unregister-Event -SourceIdentifier $_.Name
        }
        Remove-Job -Id $pidDelArchivo
        Remove-Item $pidFile
        
        # Los event handlers son tecnicamente implementados como un tipo de
        # job en segundo plano, con lo cual lo eliminamos:
        $handlers | Remove-Job
        
        # Liberamos el recurso del FileSystemWatcher:
        $watcher.Dispose()
        
        Write-Host "El demonio ha sido detenido." -ForegroundColor Yellow
    } else {
        Write-Host "No se encontró ningún demonio activo para el directorio '$Directorio'." -ForegroundColor Red
    }
}

$global:Directorio = $Directorio
$global:Salida = $Salida

# Procesar parámetros
if ($Kill) {
    FinalizarDemonio -Directorio $Directorio
} else {
    IniciarDemonio -Directorio $Directorio -Salida $Salida
}

