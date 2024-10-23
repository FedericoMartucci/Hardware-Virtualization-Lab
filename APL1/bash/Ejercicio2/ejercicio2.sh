#! /bin/bash

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#
#               Virtualizacion de Hardware              #
#                                                       #
#   APL1                                                #
#   Nro ejercicio: 2                                    #
#   Nro entrega: Reentrega                              #
#   Nombre del script: ejercicio2.sh                    #
#                                                       #
#   Integrantes:                                        #
#                                                       #
#       Branchesi, Tomas Agustin      43013625          #
#       Martucci, Federico Ariel      44690247          #
#                                                       #
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#


function ayuda() {
    echo "USO: $0 [-m|--matriz <archivo_matriz>] [-p|--producto <valor_escalar>] [-t|--trasponer] [-s|--separador <caracter_separador>]";
    echo "DESCRIPCIÓN: Este script realiza operaciones de producto escalar o trasposición sobre una matriz leída desde un archivo de texto.";
    echo "El archivo debe contener una matriz válida con valores numéricos (incluyendo decimales y negativos).";
    echo "El formato del archivo es el siguiente, donde cada número está separado por un separador especificado por el usuario:";
    echo "    Ejemplo de matriz:";
    echo "    0|1|2";
    echo "    1|1|1";
    echo "    -3|-3|-1";
    echo "";
    echo "OPCIONES:";
    echo "  -m, --matriz      Ruta del archivo de la matriz a procesar.";
    echo "  -p, --producto    Valor entero para realizar el producto escalar con la matriz.";
    echo "                    No puede usarse junto con -t (trasponer).";
    echo "  -t, --trasponer   Indica que se debe realizar la operación de trasposición de la matriz.";
    echo "                    No puede usarse junto con -p (producto escalar).";
    echo "  -s, --separador   Carácter separador de columnas en el archivo de la matriz.";
    echo "                    El separador no puede ser un número ni el símbolo menos '-'.";
    echo "  -h, --help        Muestra este mensaje de ayuda.";
    echo "";
    echo "ACLARACIONES:";
    echo "  - El archivo de matriz debe contener el mismo número de columnas en cada fila.";
    echo "  - El resultado se guardará en un archivo llamado 'salida.nombreArchivoEntrada' en el mismo directorio.";
    exit 0
}


# Validar que la matriz sea válida
function validar_matriz() {
  local archivo=$1
  local separador=$2

  while IFS= read -r linea; do
    # Comprobar si la línea tiene valores válidos
    if ! [[ $linea =~ ^[0-9$separador.-]+$ ]]; then
      echo "Error: La matriz contiene valores no numéricos."
      return 1
    fi

    # Validar si todas las filas tienen la misma cantidad de columnas
    columnas=$(echo "$linea" | tr "$separador" ' ' | wc -w)
    if [ -z "$numero_columnas" ]; then
      numero_columnas=$columnas
    elif [ "$numero_columnas" -ne "$columnas" ]; then
      echo "Error: La matriz no tiene el mismo número de columnas en todas las filas."
      return 1
    fi
  done < "$archivo"

  # Comprobar si el archivo estaba vacío
  if [ -z "$numero_columnas" ]; then
    echo "Error: El archivo de la matriz está vacío."
    return 1
  fi
}

# Realizar el producto escalar
function producto_escalar() {
  local archivo=$1
  local escalar=$2
  local separador=$3
  local salida=$4

  awk -F"$separador" -v escalar="$escalar" '{for(i=1;i<=NF;i++)$i=$i*escalar}1' OFS="$separador" "$archivo" > "$salida" 

}

# Realizar la transposición de la matriz
function transponer_matriz() {
  local archivo=$1
  local separador=$2
  local salida=$3

  awk -F"$separador" '{
    for (i=1; i<=NF; i++) {
      matriz[i, NR] = $i
      if (max_nf < NF) max_nf = NF
    }
  }
  END {
    for (i=1; i<=max_nf; i++) {
      for (j=1; j<=NR; j++) {
        printf("%s", matriz[i, j])
        if (j < NR) printf("%s", "'$separador'")
      }
      printf("\n")
    }
  }' "$archivo" > "$salida"
}

# Variables por defecto
separador="|"
archivo_matriz=""
escalar=""
transponer="false"

opciones=$(getopt -o m:p:s:th --l matriz:,producto:,separador:,trasponer,help -- "$@" 2> /dev/null);

if [ "$?" != "0" ]; then
    echo "Opcion/es incorrectas";
    exit 0;
fi

eval set -- "$opciones";

while true; do
  case "$1" in
    -m|--matriz)
      archivo_matriz="$2"
      shift 2
      ;;
    -p|--producto)
      escalar="$2"
      shift 2
      ;;
    -t|--trasponer)
      transponer="true"
      shift
      ;;
    -s|--separador)
      separador="$2"
      shift 2
      ;;
    -h|--help)
      ayuda
      ;;
    --)
      shift;
      break;
      ;;
    *)
      echo "Error: Opción desconocida $1"
      ayuda
      ;; 
  esac
done

# Validaciones iniciales
if [ -z "$archivo_matriz" ]; then
  echo "Error: Se debe especificar un archivo de matriz."
  ayuda
fi

if [ ! -f "$archivo_matriz" ]; then
  echo "Error: El archivo de matriz no existe."
  exit 1
fi

# Validar que el separador haya sido proporcionado
if [ -z "$separador" ]; then
  echo "Error: Debes especificar un separador utilizando la opción -s."
  exit 1
fi

# Validar que el separador no sea un número o el símbolo "-"
if [[ "$separador" =~ [0-9\-] ]]; then
  echo "Error: El separador no puede ser un número ni el símbolo menos."
  exit 1
fi


# Validar matriz
validar_matriz "$archivo_matriz" "$separador"
status=$?
if [ $status -ne 0 ]; then
  echo "Error en la validación de la matriz. Código de error: $status"
  exit $status
fi

# Validar el valor del escalar solo si se especificó
if [ -n "$escalar" ] && [[ ! "$escalar" =~ ^-?[0-9]+([.][0-9]+)?$ ]]; then
  echo "Error: El valor del parámetro --producto debe ser un número."
  exit 1
fi

# Generar el nombre del archivo de salida
nombre_archivo=$(basename "$archivo_matriz")
directorio=$(dirname "$archivo_matriz")
salida="$directorio/salida.$nombre_archivo"

# Realizar las operaciones según las opciones especificadas
if [ "$transponer" = "true" ] && [ -z "$escalar" ] ; then
  transponer_matriz "$archivo_matriz" "$separador" "$salida"
  echo "Transposición realizada. Resultado guardado en $salida."
elif [ -n "$escalar" ] && [ "$transponer" = "false" ]; then
  producto_escalar "$archivo_matriz" "$escalar" "$separador" "$salida"
  echo "Producto escalar realizado. Resultado guardado en $salida."
else
  echo "Error: No se puede realizar la transposición y el producto escalar al mismo tiempo."
  ayuda
fi
