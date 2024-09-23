# Parámetros del script
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

# Validar el directorio de salida
if (-not (Test-Path -Path $Directorio -PathType Container)) {
    Write-Error "El directorio especificado no existe o no es válido: $Directorio"
    exit $ERROR_DIRECTORIO_INVALIDO
}

# Validar exclusividad entre -Salida y -Kill
if (-not $Salida -and -not $Kill) {
    Write-Error "Debe ingresar una opción válida: -Salida o -Kill."
    exit $ERROR_PARAMETROS_FALTANTES
}

# Verificar que el directorio esté definido
Write-Host "Directorio recibido: $Directorio"

# Validar que el directorio exista
if (-not (Test-Path -Path $Directorio -PathType Container)) {
    Write-Error "El directorio especificado no existe: $Directorio"
    exit $ERROR_DIRECTORIO_INVALIDO
}

# Generar un hash a partir del nombre del directorio para el archivo de lock
$hashDirectorio = [Math]::Abs(($Directorio).GetHashCode())
Write-Host "Hash del directorio: $hashDirectorio"

if (-not $hashDirectorio) {
    Write-Error "No se pudo calcular el hash del directorio."
    exit $ERROR_DIRECTORIO_INVALIDO
}

$lockFile = Join-Path -Path $env:TEMP -ChildPath "$hashDirectorio-lock.txt"



# Si se especifica el parámetro -Kill, detener el proceso del demonio
if ($Kill) {
    if (Test-Path $lockFile) {
        $demonioPID = Get-Content $lockFile
        try {
            Stop-Job -Id $demonioPID -Force
            Remove-Item $lockFile
            Write-Host "El demonio ha sido detenido."
        } catch {
            Write-Host "Error al detener el proceso con PID $demonioPID. Es posible que ya no esté en ejecución."
        }
    } else {
        Write-Host "No se encontró ningún demonio ejecutándose para este directorio."
    }
    exit
}

# Si ya existe un archivo de lock, no permitir múltiples demonios
if (Test-Path $lockFile) {
    Write-Host "Ya hay un proceso de monitoreo ejecutándose en este directorio."
    exit
}

# Guardar el ID del proceso en el archivo de lock
$job = Start-Job -ScriptBlock {
    param($Directorio, $Salida)

    # Configurar el FileSystemWatcher
    $watcher = New-Object System.IO.FileSystemWatcher
    $watcher.Path = $Directorio
    $watcher.IncludeSubdirectories = $true
    $watcher.EnableRaisingEvents = $true

    # Función para procesar archivos duplicados
    function Procesar-ArchivoDuplicado {
        param ($archivo)

        $nombreArchivo = Split-Path $archivo -Leaf
        $tamanoArchivo = (Get-Item $archivo).length

        $duplicado = Get-ChildItem -Path $Salida -Recurse | Where-Object {
            $_.Name -eq $nombreArchivo -and $_.Length -eq $tamanoArchivo
        }

        if ($duplicado) {
            $backupNombre = (Get-Date).ToString("yyyyMMdd-HHmmss")
            $zipPath = "$Salida\$backupNombre.zip"

            # Log y compresión
            Add-Content -Path "$Salida\log.txt" -Value "[$(Get-Date)] Archivo duplicado: $nombreArchivo. Backup: $zipPath"
            Compress-Archive -Path $archivo,$duplicado.FullName -DestinationPath $zipPath
            Remove-Item $duplicado.FullName
        }
    }

    # Registrar eventos del FileSystemWatcher
    Register-ObjectEvent -InputObject $watcher -EventName Created -Action { Procesar-ArchivoDuplicado $Event.SourceEventArgs.FullPath }
    Register-ObjectEvent -InputObject $watcher -EventName Changed -Action { Procesar-ArchivoDuplicado $Event.SourceEventArgs.FullPath }
    Register-ObjectEvent -InputObject $watcher -EventName Renamed -Action { Procesar-ArchivoDuplicado $Event.SourceEventArgs.FullPath }

    # Mantener el job en ejecución
    while ($true) { Start-Sleep -Seconds 5 }

} -ArgumentList $Directorio, $Salida

# Guardar el ID del job en el archivo de lock
$job.Id | Out-File $lockFile
Write-Host "El demonio ha sido iniciado en segundo plano."
