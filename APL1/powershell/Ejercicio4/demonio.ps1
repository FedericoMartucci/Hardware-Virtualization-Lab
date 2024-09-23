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
    $var2=Test-Path -Path "$FullPath" -PathType Leaf -ErrorAction Ignore
    if($var2 -eq $true){
        #establecer fecha
        $fechaMonitoreo=Get-Date -Format "yyyyMMdd-HHmmss"
        #crear archivo log
        $log="$Salida\$fechaMonitoreo.txt"
        New-Item -ItemType File -Path "$log"
        if($accion -eq "CHANGED"){
            #Añadimos el reporte al archivo log
            Add-Content "$log" "$Fecha $FullPath ha sido modificado"
           # Buscar archivos duplicados por nombre y tamaño
            $duplicates = Get-ChildItem -Path $using:Directorio -Recurse |
            Where-Object { $_.Name -eq $name -and $_.Length -eq $size -and $_.FullName -ne $file }

            if ($duplicates.Count -gt 0) {
                $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
                $logPath = "$using:Salida\log-$timestamp.txt"
                Add-Content -Path $logPath -Value "INFO | Archivo duplicado encontrado: $file"
                
                $zipFile = "$using:Salida\$timestamp.zip"
                Compress-Archive -Path $file, $duplicates.FullName -DestinationPath $zipFile
            }
        }
        if($accion -eq "RENAMED"){
           Add-Content "$log" "$Fecha $FullPath ha sido renombrado"
        }
        if($accion -eq "CREATED"){
           Add-Content "$log" "$Fecha $FullPath ha sido creado"
        }
    }
}

function CrearMonitor {
    param (
        [string]$Directorio,
        [string]$Salida
    )

    # Crear el FileSystemWatcher
    $watcher = New-Object -TypeName System.IO.FileSystemWatcher -Property @{
        Path = $Directorio
        Filter =  "*.*"
        IncludeSubdirectories =  $true
        EnableRaisingEvents = $true
      }
    
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

        $global:all = $details
        $ev = ""
        switch ($ChangeType)
        {
            "Changed"  { $ev="CHANGED" }
            "Created"  { $ev="CREATED" }
            "Renamed"  { $ev="RENAMED" }  
            # cualquier superficie de tipo de cambio no controlada aquí:
            default   { Write-Host "HOLA"}
        }
        $FullPath = $all.FullPath
        $Timestamp = $event.TimeGenerated
        Write-Host $FullPath
        # Write-Host $ev
        # Write-Host $Timestamp
        Monitorear "$FullPath" $ev $Timestamp
    }

    Register-ObjectEvent -InputObject $watcher -EventName Changed -Action $action 
    Register-ObjectEvent -InputObject $watcher -EventName Created -Action $action
    Register-ObjectEvent -InputObject $watcher -EventName Renamed -Action $action 

    while ($true) {
        Write-Host $Directorio
        Start-Sleep -Seconds 1
    }
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
        if (Get-Process -Id $pidDelArchivo -ErrorAction SilentlyContinue) {
            Write-Host "El demonio ya existe para el directorio '$Directorio' con PID $pidDelArchivo." -ForegroundColor Red
            exit $ERROR_DEMONIO_EXISTENTE
        } else {
            # Si el proceso ya no existe, eliminar el archivo PID
            Remove-Item $pidFile
        }
    }

    # Ejecutar el script en segundo plano
    # $job = Start-Job -ArgumentList $Directorio, $Salida -ScriptBlock {
        CrearMonitor -Directorio $Directorio -Salida $Salida
    # }

    # Guardar el PID del trabajo en segundo plano
    # $jobPid = (Get-Process -Id $job.Id).Id
    # Set-Content -Path $pidFile -Value $jobPid

    Write-Host "El demonio se ha iniciado en segundo plano con PID $jobPid." -ForegroundColor Green
}

function EliminarDemonio {
    param (
        [string]$Directorio
    )

    $directorioAEliminar=split-path -leaf "$directorio"
    $cadena=$directorioAEliminar.Replace('\','')
    noExiste -Nom $cadena
    Get-EventSubscriber -ErrorAction SilentlyContinue | Where-Object { $_.SourceIdentifier -match "$directorioAEliminar" } | ForEach-Object { Unregister-Event -SourceIdentifier $_.SourceIdentifier }
    Get-Job -erroraction 'silentlycontinue' | Select-Object Name | Where-Object { $_.Name -match "$directorioAEliminar" } | ForEach-Object { remove-job -force -Name $_.Name }
    if (Test-Path -Path "./$directorioAEliminar.txt" -PathType Leaf) {
        get-content -path "./$directorioAEliminar.txt"
        Remove-Item -Path "./$directorioAEliminar.txt"
    }
    else {
        write-host "El Directorio $directorioAEliminar no ha sufrido cambios."
    }
    Write-Host "El proceso ha sido finalizado."
    exit 1;



    # Buscar el archivo PID
    $pidFile = "$Directorio\monitor-$($Directorio -replace '[\\:\/]', '_').pid"
    if (Test-Path $pidFile) {
        $pidDelArchivo = Get-Content $pidFile
        try {
            Stop-Process -Id $pidDelArchivo -Force
            Write-Host "El demonio para el directorio '$Directorio' ha sido detenido."
            Remove-Item $pidFile
        }
        catch {
            Write-Host "No se pudo detener el proceso con PID $pidDelArchivo. Es posible que ya haya terminado."
            Remove-Item $pidFile
        }
    }
    else {
        Write-Warning "No se encontró un demonio en ejecución para el directorio '$Directorio'."
    }
}

# Procesar parámetros
if ($Kill) {
    EliminarDemonio -Directorio $Directorio
} else {
    IniciarDemonio -Directorio $Directorio -Salida $Salida
}
exit 0