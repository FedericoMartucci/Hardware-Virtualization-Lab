/*
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#
#               Virtualizacion de Hardware              #
#                                                       #
#   APL2                                                #
#   Nro ejercicio: 1                                    #
#   Nro entrega: 1                                      #
#   Nombre del script: daemon.cpp                       #
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
#include <sstream>
#include <string>
#include <csignal>
#include <ctime>
#include <cstdlib>
#include <cstring>
#include <set>
#include <unistd.h>
#include <sys/stat.h>

#define FIFO_PATH "/tmp/fifo"

std::set<std::string> validIDs; // Para almacenar los IDs válidos
std::ofstream logFile;

// Función que captura las señales y finaliza el demonio de manera segura
void signalHandler(int signum)
{
    std::cout << "Terminando demonio por señal: " << signum << std::endl;
    if (logFile.is_open())
    {
        std::cout << "Demonio finalizado correctamente." << std::endl;
        logFile.close();
    }
    std::remove(FIFO_PATH);
    exit(signum);
}

// Función para obtener la fecha y hora actual
std::string currentDateTime()
{
    time_t now = time(0);
    char buf[80];
    struct tm tstruct = *localtime(&now);
    strftime(buf, sizeof(buf), "%Y-%m-%d %X", &tstruct);
    return buf;
}

bool loadValidIDs()
{
    std::ifstream validIdsFile("fingerprint_db.txt");
    if (!validIdsFile.is_open())
    {
        std::cerr << "Error al abrir el archivo de IDs válidos: " << "fingerprint_db.txt" << std::endl;
        return false;
    }

    std::string id;
    while (std::getline(validIdsFile, id))
    {
        validIDs.insert(id);
    }

    validIdsFile.close();
    return true;
}

// Función para crear el demonio
void createDaemon()
{
    pid_t pid = fork();
    if (pid < 0)
    {
        std::cerr << "Error al hacer fork." << std::endl;
        exit(1);
    }
    if (pid > 0)
    {
        exit(0); // Termina el proceso padre
    }

    // Crear un nuevo sesión de líder
    if (setsid() < 0)
    {
        std::cerr << "Error al crear una nueva sesión." << std::endl;
        exit(1);
    }

    // Cambiar el directorio de trabajo
    chdir("/");

    // Redirigir los descriptores de archivo
    freopen("/dev/null", "r", stdin);
    freopen("/dev/null", "w", stdout);
    freopen("/dev/null", "w", stderr);
}

int main(int argc, char *argv[])
{
    std::string logPath;

    // Procesar los parámetros de entrada (orden flexible)
    for (int i = 1; i < argc; ++i)
    {
        if (strcmp(argv[i], "--log") == 0 || strcmp(argv[i], "-l") == 0)
        {
            if (i + 1 < argc)
            {
                logPath = argv[i + 1];
                ++i; // Saltar al siguiente parámetro
            }
            else
            {
                std::cerr << "Error: Falta el nombre del archivo de log." << std::endl;
                return 1;
            }
        }
        else if (strcmp(argv[i], "--help") == 0 || strcmp(argv[i], "-h") == 0)
        {
            std::cout << "Uso: " << argv[0] << " --log <log_file>" << std::endl;
            return 0;
        }
    }

    if (logPath.empty())
    {
        std::cerr << "Error: Parámetro --log es obligatorio." << std::endl;
        return 1;
    }

    // Abrir archivo de log usando fstream
    logFile.open(logPath, std::ios::out | std::ios::app);
    if (!logFile.is_open())
    {
        std::cerr << "Error abriendo archivo de log: " << logPath << std::endl;
        return 1;
    }

    // Cargar IDs válidos
    if (!loadValidIDs())
    {
        return 1;
    }

    // Crear el FIFO si no existe
    if (mkfifo(FIFO_PATH, 0666) == -1)
    {
        std::cerr << "Error creando el FIFO: " << FIFO_PATH << std::endl;
        return 1;
    }

    // Capturar señales para terminación segura
    signal(SIGINT, signalHandler);
    signal(SIGTERM, signalHandler);

    std::ifstream fifoStream;

    createDaemon();

    // Bucle principal para leer del FIFO y escribir en el log
    while (true)
    {
        fifoStream.open(FIFO_PATH);
        if (!fifoStream.is_open())
        {
            std::cerr << "Error al abrir el FIFO para lectura: " << FIFO_PATH << std::endl;
            continue;
        }

        std::string line;
        while (std::getline(fifoStream, line))
        {
            std::istringstream iss(line);
            std::string sensorNumber, sensorID;
            iss >> sensorNumber >> sensorID;

            if (sensorNumber.empty() || sensorID.empty())
            {
                continue;
            }

            std::string status = validIDs.count(sensorID) ? "[VÁLIDA]" : "[INVÁLIDA]";
            logFile << "[" << currentDateTime() << "] "
                    << "Sensor " << sensorNumber << " - Huella: " << sensorID
                    << " " << status << std::endl;
        }

        fifoStream.close();
        sleep(1); // Pausa para evitar carga excesiva
    }

    return 0;
}
