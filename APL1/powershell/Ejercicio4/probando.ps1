
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
    $OldFullPath = $details.OldFullPath
    $OldName = $details.OldName

    $timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")

    $logEntry = "$($details.ChangeType) - $($details.FullPath) at $timestamp"
    Add-Content -Path "\home\federico\Hardware-Virtualization-Lab\APL1\powershell\Ejercicio4\log" -Value $logEntry
    Write-Host $logEntry
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
