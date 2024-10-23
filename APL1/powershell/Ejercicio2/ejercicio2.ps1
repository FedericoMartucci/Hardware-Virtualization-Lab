#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#
#               Virtualizacion de Hardware              #
#                                                       #
#   APL1                                                #
#   Nro ejercicio: 2                                    #
#   Nro entrega: Reentrega                              #
#   Nombre del script: ejercicio2.ps1                   #
#                                                       #
#   Integrantes:                                        #
#                                                       #
#       Branchesi, Tomas Agustin      43013625          #
#       Martucci, Federico Ariel      44690247          #
#                                                       #
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#

<#
.SYNOPSIS
Este script realiza el producto escalar o la trasposición de una matriz leída desde un archivo de texto plano.

.DESCRIPTION
El script toma como entrada un archivo de matriz con números separados por un carácter específico, valida el archivo y realiza la operación solicitada: producto escalar o trasposición. La salida se guarda en el mismo directorio con el nombre "salida.nombreArchivoEntrada".

.PARAMETER matriz
Ruta del archivo que contiene la matriz a procesar. Este parámetro es obligatorio.

.PARAMETER producto
Valor entero para realizar el producto escalar con la matriz. No puede usarse junto con el parámetro -trasponer.

.PARAMETER trasponer
Indica que se debe realizar la trasposición de la matriz. No puede usarse junto a -producto.

.PARAMETER separador
Carácter separador de columnas en el archivo de la matriz. Es obligatorio.

.EXAMPLE
.\ejercicio2.ps1 -matriz "C:\ruta\matriz.txt" -producto 2 -separador "|"

.EXAMPLE
.\ejercicio2.ps1 -matriz "C:\ruta\matriz.txt" -trasponer -separador ","

.NOTES
El script valida la matriz asegurando que todas las filas tienen el mismo número de columnas, que los valores son numéricos, y que el archivo no esté vacío.
#>

param (
    [Parameter(Mandatory = $true, ParameterSetName = "ProductoEscalar")]
    [int]$producto,

    [Parameter(Mandatory = $true, ParameterSetName = "Transponer")]
    [switch]$trasponer,

    [Parameter(Mandatory = $true)]
    [string]$matriz,

    [Parameter(Mandatory = $true)]
    [string]$separador
)

# Constantes para manejar errores
$Script:ERROR_ARCHIVO_NO_ENCONTRADO = 2
$Script:ERROR_ARCHIVO_NO_VALIDO = 3
$Script:ERROR_MATRIZ_INVALIDA = 4
$Script:ERROR_SEPARADOR_INVALIDO = 5

# Verificar que la matriz exista
if (-not (Test-Path $matriz)) {
    Write-Error "El archivo de matriz no existe."
    exit $ERROR_ARCHIVO_NO_ENCONTRADO
}

# Verificar que el path sea un archivo y no un directorio
if ((Test-Path $matriz -PathType Leaf) -eq $false) {
    Write-Error "El parámetro 'matriz' debe ser un archivo y no un directorio."
    exit $ERROR_ARCHIVO_NO_VALIDO
}

# Leer el archivo de matriz
$contenido = Get-Content $matriz
if (-not $contenido) {
    Write-Error "El archivo de matriz está vacío."
    exit $ERROR_MATRIZ_INVALIDA
}

# Validar el separador
if ($separador -match '[\d\-]') {
    Write-Error "El separador no puede ser un número ni el símbolo '-'."
    exit $ERROR_SEPARADOR_INVALIDO
}

# Convertir el contenido en una matriz
$matrizArray = @()
foreach ($linea in $contenido) {
    $valores = $linea -split [regex]::Escape($separador)

    # Validar que todos los elementos son numéricos
    foreach ($valor in $valores) {
        if (-not ($valor -match '^-?\d+(\.\d+)?$')) {
            Write-Error "La matriz contiene valores no numéricos."
            exit $ERROR_MATRIZ_INVALIDA
        }
    }

    # Agregar la fila a la matriz
    $matrizArray += ,@($valores)

    # Validar que todas las filas tengan la misma cantidad de columnas
    if ($matrizArray[0].Length -ne $valores.Length) {
        Write-Error "La matriz tiene filas con cantidades de columnas diferentes."
        exit $ERROR_MATRIZ_INVALIDA
    }
}

function Transponer-Matriz {
    param ($matriz)
    $matrizTranspuesta = @()
    for ($i = 0; $i -lt $matriz[0].Length; $i++) {
        $filaTranspuesta = @()
        for ($j = 0; $j -lt $matriz.Length; $j++) {
            $filaTranspuesta += $matriz[$j][$i]
        }
        $matrizTranspuesta += ,$filaTranspuesta
    }
    return $matrizTranspuesta
}

function Producto-Escalar {
    param ($matriz, $escalar)
    $matrizEscalar = @()
    foreach ($fila in $matriz) {
        $filaEscalar = @()
        foreach ($valor in $fila) {
            $filaEscalar += [math]::Round([double]$valor * $escalar, 2)
        }
        $matrizEscalar += ,$filaEscalar
    }
    return $matrizEscalar
}

# Realizar la operación indicada según corresponda
$resultado = @()
switch ($PSCmdlet.ParameterSetName) {
    "ProductoEscalar" {
        $resultado = Producto-Escalar -matriz $matrizArray -escalar $producto
    }
    "Transponer" {
        $resultado = Transponer-Matriz $matrizArray
    }
}

# Obtener el nombre del archivo de entrada y generar el nombre del archivo de salida
$nombreArchivo = [System.IO.Path]::GetFileNameWithoutExtension($matriz)
$directorio = [System.IO.Path]::GetDirectoryName($matriz)
$archivoSalida = "$directorio\salida.$nombreArchivo"

# Escribir la salida en el archivo
$resultado | ForEach-Object { $_ -join $separador } | Set-Content -Path $archivoSalida

Write-Host "Resultado guardado en $archivoSalida."
