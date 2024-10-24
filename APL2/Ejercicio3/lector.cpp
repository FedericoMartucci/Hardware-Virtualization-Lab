/*
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#
#               Virtualizacion de Hardware              #
#                                                       #
#   APL2                                                #
#   Nro ejercicio: 3                                    #
#   Nro entrega: 1                                      #
#   Nombre del script: lector.cpp                       #
#                                                       #
#   Integrantes:                                        #
#                                                       #
#       Branchesi, Tomas Agustin      43013625          #
#       Martucci, Federico Ariel      44690247          #
#                                                       #
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#
*/

#include <iostream>
#include <fstream>
#include <string>
#include <unistd.h>
#include <cstring>
#include <cstdlib>
#include <regex>
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>

#define FIFO_PATH "/tmp/fifo"

int main(int argc, char *argv[])
{
    int nroSensor = -1;
    int cantSegundos = -1;
    int cantMensajes = -1;
    std::string pathArchivo;

    // Validación de los parámetros de entrada
    for (int i = 1; i < argc; ++i)
    {
        if ((strcmp(argv[i], "--numero") == 0 || strcmp(argv[i], "-n") == 0))
        {
            if (i + 1 < argc && argv[i + 1][0] != '-')
            { // Comprobar que el siguiente valor no sea otro parámetro
                nroSensor = std::stoi(argv[++i]);
            }
            else
            {
                std::cerr << "Error: Falta el valor del parámetro --numero." << std::endl;
                return 1;
            }
        }
        else if ((strcmp(argv[i], "--segundos") == 0 || strcmp(argv[i], "-s") == 0))
        {
            if (i + 1 < argc && argv[i + 1][0] != '-')
            {
                cantSegundos = std::stoi(argv[++i]);
            }
            else
            {
                std::cerr << "Error: Falta el valor del parámetro --segundos." << std::endl;
                return 1;
            }
        }
        else if ((strcmp(argv[i], "--mensajes") == 0 || strcmp(argv[i], "-m") == 0))
        {
            if (i + 1 < argc && argv[i + 1][0] != '-')
            {
                cantMensajes = std::stoi(argv[++i]);
            }
            else
            {
                std::cerr << "Error: Falta el valor del parámetro --mensajes." << std::endl;
                return 1;
            }
        }
        else if ((strcmp(argv[i], "--ids") == 0 || strcmp(argv[i], "-i") == 0))
        {
            if (i + 1 < argc && argv[i + 1][0] != '-')
            {
                pathArchivo = argv[++i];
            }
            else
            {
                std::cerr << "Error: Falta el valor del parámetro --ids." << std::endl;
                return 1;
            }
        }
        else if ((strcmp(argv[i], "--help") == 0 || strcmp(argv[i], "-h") == 0))
        {
            std::cout << "Uso: " << argv[0] << " --numero <numero_de_sensor> --segundos <cantidad_de_segundos> "
                      << "--mensajes <cantidad_de_mensajes> --ids <archivo_ids>" << std::endl;
            return 0;
        }
        else
        {
            std::cerr << "Error: Parámetro no reconocido: " << argv[i] << std::endl;
            return 1;
        }
    }

    // Validar que se encuentren todos los parametros
    if (nroSensor == -1)
    {
        std::cerr << "Error: El parámetro --numero es obligatorio." << std::endl;
        return 1;
    }
    if (cantSegundos == -1)
    {
        std::cerr << "Error: El parámetro --segundos es obligatorio." << std::endl;
        return 1;
    }
    if (cantMensajes == -1)
    {
        std::cerr << "Error: El parámetro --mensajes es obligatorio." << std::endl;
        return 1;
    }
    if (pathArchivo.empty())
    {
        std::cerr << "Error: El parámetro --ids es obligatorio." << std::endl;
        return 1;
    }

    std::ifstream idsFile(pathArchivo);
    if (!idsFile.is_open())
    {
        std::cerr << "Error al abrir el archivo de IDs: " << pathArchivo << std::endl;
        return 1;
    }

    std::regex idPattern("^[0-9]{10}$");
    std::ofstream fifoStream;
    std::string sensorID;
    int mjsEnviados = 0;

    // Leer cada ID del archivo y enviarlo al FIFO
    while (mjsEnviados < cantMensajes && std::getline(idsFile, sensorID))
    {
        // Validar que el ID tenga el formato correcto
        if (!std::regex_match(sensorID, idPattern))
        {
            std::cerr << "Error: ID inválido encontrado en el archivo (" << sensorID << "). Debe ser un número de 10 dígitos." << std::endl;
            continue;
        }

        int fifoFD = open(FIFO_PATH, O_WRONLY);
        if (fifoFD == -1)
        {
            std::cerr << "Error al abrir el FIFO para escritura: " << FIFO_PATH << std::endl;
            break;
        }

        std::string mensaje = std::to_string(nroSensor) + " " + sensorID;
    
        ssize_t bytesEscritos = write(fifoFD, mensaje.c_str(), mensaje.size());

        if (bytesEscritos == -1)
        {
            std::cerr << "Error al escribir en el FIFO: " << FIFO_PATH << std::endl;
            close(fifoFD);
            break;
        }

        std::cout << "Enviado: Sensor " << nroSensor << " - Huella: " << sensorID << std::endl;

        close(fifoFD);

        ++mjsEnviados;
        sleep(cantSegundos); // Esperar el intervalo especificado antes de enviar el siguiente mensaje
    }

    std::cout << "El lector ha enviado " << mjsEnviados << " mensajes y finalizará." << std::endl;
    idsFile.close();
    return 0;
}