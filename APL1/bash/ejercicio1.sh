#! /bin/bash
declare directorioEntrada="";
declare rutaArchivoSalida="";
declare mostrarPorPantalla=false;

opciones=$(getopt -o d:s:ph --l directorio:,salida:,pantalla,help -- "$@" 2> /dev/null);

if [ "$?" != "0" ]; then
    echo "Opcion/es incorrectas";
    exit $ERROR_PARAMETROS_INVALIDOS;
fi

eval set -- "$opciones";

while true; do
    case "$1" in
        -d | --directorio)
            directorioEntrada="$2";
            shift 2;
            ;;
        -s | --salida)
            rutaArchivoSalida="$2";
            shift 2;
            ;;
        -p | --pantalla)
            mostrarPorPantalla=true;
            shift;
            ;;
        --)
            shift;
            break;
            ;;
        -h | --help)
            #ayuda;
            exit 0;
            ;;
        *)
            echo "ERROR: Argumento desconocido: $1";
            exit $ERROR_ARGUMENTO_DESCONOCIDO;
            ;;
    esac
done