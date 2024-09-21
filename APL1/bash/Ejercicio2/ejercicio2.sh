#! /bin/bash

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#
#               Virtualizacion de Hardware              #
#                                                       #
#   APL1                                                #
#   Nro ejercicio: 2                                    #
#   Nro entrega: 1                                      #
#   Nombre del script: ejercicio2.sh                    #
#                                                       #
#   Integrantes:                                        #
#                                                       #
#       Branchesi, Tomas Agustin      43013625          #
#       Martucci, Federico Ariel      44690247          #
#                                                       #
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#


function ayuda() {
  echo "Para ejecutar el script: $0 -m \"archivo_matriz\" -p \"escalar\" -t -s \"separador"\"
  echo "El orden de los parametros no es estricto!"
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


while [[ "$#" -gt 0 ]]; do
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
validar_matriz "$archivo_matriz" "$separador" || exit 1

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
