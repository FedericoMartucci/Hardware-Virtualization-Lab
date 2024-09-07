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

declare ERROR_DIRECTORIO=1;

function ayuda(){
    #TODO: Implementar ayuda
}




if ! [ -d "$directorioEntrada" ]; then
    echo "ERROR: Se debe especificar un directorio válido.";
    exit $ERROR_DIRECTORIO;
fi

