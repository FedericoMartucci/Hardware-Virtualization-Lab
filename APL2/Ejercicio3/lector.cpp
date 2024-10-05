/*
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#
#               Virtualizacion de Hardware              #
#                                                       #
#   APL2                                                #
#   Nro ejercicio: 1                                    #
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
#include <sstream>
#include <cstdlib>
#include <string.h>

#define FIFO_PATH "/tmp/fifo"

int main(int argc, char *argv[]) {
    int sensorNumber = -1;
    int interval = -1;
    int messageCount = -1;
    std::string idsFilePath;

    // Procesar parámetros en cualquier orden
    for (int i = 1; i < argc; ++i) {
        if (strcmp(argv[i], "--numero") == 0 || strcmp(argv[i], "-n") == 0) {
            sensorNumber = std::stoi(argv[++i]);
        } else if (strcmp(argv[i], "--segundos") == 0 || strcmp(argv[i], "-s") == 0) {
            interval = std::stoi(argv[++i]);
        } else if (strcmp(argv[i], "--mensajes") == 0 || strcmp(argv[i], "-m") == 0) {
            messageCount = std::stoi(argv[++i]);
        } else if (strcmp(argv[i], "--ids") == 0 || strcmp(argv[i], "-i") == 0) {
            idsFilePath = argv[++i];
        } else if (strcmp(argv[i], "--help") == 0 || strcmp(argv[i], "-h") == 0) {
            std::cout << "Uso: " << argv[0] << " --numero <sensor_number> --segundos <interval> "
                      << "--mensajes <message_count> --ids <ids_file>" << std::endl;
            return 0;
        }
    }

    // Validar parámetros requeridos
    if (sensorNumber == -1 || interval == -1 || messageCount == -1 || idsFilePath.empty()) {
        std::cerr << "Error: Faltan parámetros obligatorios. Use --help para más información." << std::endl;
        return 1;
    }

    // Leer IDs del archivo de simulación
    std::ifstream idsFile(idsFilePath);
    if (!idsFile.is_open()) {
        std::cerr << "Error al abrir el archivo de IDs: " << idsFilePath << std::endl;
        return 1;
    }

    std::ofstream fifoStream;

    // Enviar mensajes al FIFO
    std::string sensorID;
    int sentMessages = 0;
    while (sentMessages < messageCount && std::getline(idsFile, sensorID)) {
        fifoStream.open(FIFO_PATH, std::ios::out);
        if (!fifoStream.is_open()) {
            std::cerr << "Error al abrir el FIFO para escritura: " << FIFO_PATH << std::endl;
            break;
        }

        // Formar mensaje con el número del sensor y el ID
        fifoStream << sensorNumber << " " << sensorID << std::endl;
        std::cout << "Enviado: Sensor " << sensorNumber << " - Huella: " << sensorID << std::endl;
        fifoStream.close();

        ++sentMessages;
        sleep(interval);  // Esperar el intervalo especificado
    }

    std::cout << "El lector ha enviado " << sentMessages << " mensajes y finalizará." << std::endl;

    idsFile.close();
    return 0;
}
