function Global:moverAzip {
    Param(
        [string] $archivoAmover,
        [string] $archivoZip
    )
    Add-Type -AssemblyName System.IO.Compression.FileSystem

    $archivoMoverNombre = [System.IO.Path]::GetFileName($archivoAmover)
    $archivoMoverRutaAbs = $(Resolve-Path "$archivoAmover")

    # Si no existe el archivo zip, lo crea.
    if (!(Test-Path "$archivoZip")) {
        $zip = [System.IO.Compression.ZipFile]::Open("$archivoZip", "create");
        $zip.Dispose();
    }
    
    $compressionLevel = [System.IO.Compression.CompressionLevel]::Fastest
    $zip = [System.IO.Compression.ZipFile]::Open("$archivoZip", "update");
    [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip, "$archivoMoverRutaAbs", "$archivoMoverNombre", $compressionLevel);
    $zip.Dispose();
}

function Global:Monitorear($FullPath, $Fecha) {
    $fechaMonitoreo = Get-Date -Date $Fecha -Format "yyyyMMdd-HHmmss"
    $logPath = "./log/log-$fechaMonitoreo.txt"
    New-Item -ItemType File -Path "$logPath" -Force

    # Añadimos el reporte al archivo log
    $name = [System.IO.Path]::GetFileName($FullPath)
    $size = (Get-Item $FullPath).length

    # Buscar archivos duplicados por nombre y tamaño
    $duplicates = Get-ChildItem -Path "./prueba" -Recurse | Where-Object { $_.Name -eq $name -and $_.Length -eq $size }

    if ($duplicates.Count -gt 1) {
        $existingLog = Get-Content $logPath
        if (-not $existingLog) {
            Add-Content -Path $logPath -Value "INFO | Archivo duplicado encontrado: $name"
        }
        
        $zipFile = "./log/$fechaMonitoreo.zip"
        
        ForEach ($item in $duplicates) {
            moverAzip $item.FullName $zipFile
        }
    }
}

# Definir el directorio a monitorear
$directoryToWatch = "./prueba"

# Crear el FileSystemWatcher
$watcher = New-Object System.IO.FileSystemWatcher
$watcher.Path = $directoryToWatch
$watcher.Filter = "*.*"  # Monitorea todos los archivos
$watcher.IncludeSubdirectories = $true
$watcher.EnableRaisingEvents = $true

# Acción a ejecutar cuando se detecte un cambio
$action = {
    $details = $event.SourceEventArgs
    $Name = $details.Name
    $FullPath = $details.FullPath
    $timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")

    Monitorear "$FullPath" $timestamp
}

# Eventos a monitorear
Register-ObjectEvent $watcher -EventName Created -Action $action
Register-ObjectEvent $watcher -EventName Changed -Action $action
Register-ObjectEvent $watcher -EventName Deleted -Action $action

# Crear el Job en segundo plano
Start-Job -ScriptBlock {
    while ($true) {
        Start-Sleep -Seconds 1
    }
}

Write-Host "Monitoreo iniciado en segundo plano."
