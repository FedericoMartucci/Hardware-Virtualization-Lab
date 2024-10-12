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
#include <fcntl.h>
#include <sys/stat.h>

using namespace std;

#define FIFO_PATH "/tmp/fifo"

set<string> validIDs;  // Para almacenar los IDs válidos
ofstream archivoLog;
const char* FILE_IDS = "ids_validos.txt";

// Función que captura las señales y finaliza el demonio de manera segura
void senialHandler(int signum)
{
    cout << "Terminando demonio por señal: " << signum << endl;
    if (archivoLog.is_open())
    {
        cout << "Demonio finalizado correctamente." << endl;
        archivoLog.close();
    }
    unlink(FIFO_PATH);
    exit(signum);
}


string calcularFechaActual()
{
    time_t now = time(0);
    char buf[80];
    struct tm tstruct = *localtime(&now);
    strftime(buf, sizeof(buf), "%Y-%m-%d %X", &tstruct);
    return buf;
}

// Cargar los IDs válidos desde el archivo ids_validos.txt
bool cargarIDsValidos()
{
    ifstream validIdsFile(FILE_IDS);
    if (!validIdsFile.is_open())
    {
        cerr << "Error al abrir el archivo de IDs válidos: " << FILE_IDS << endl;
        return false;
    }

    string id;
    while (getline(validIdsFile, id))
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
        cerr << "Error al hacer fork." << endl;
        exit(1);
    }
    if (pid > 0)
    {
        exit(0);  // Termina el proceso padre
    }

    // Crear un nuevo sesión de líder
    if (setsid() < 0)
    {
        cerr << "Error al crear una nueva sesión." << endl;
        exit(1);
    }

    cout << "El PID es: " << getpid() << endl;

    // Cambiar el directorio de trabajo
    chdir("/");

    // Redirigir los descriptores de archivo
    freopen("/dev/null", "r", stdin);
    freopen("/dev/null", "w", stdout);
    freopen("/dev/null", "w", stderr);
}

int main(int argc, char *argv[])
{
    string logPath;

    // Procesar los parámetros de entrada (orden flexible)
    for (int i = 1; i < argc; ++i)
    {
        if (strcmp(argv[i], "--log") == 0 || strcmp(argv[i], "-l") == 0)
        {
            if (i + 1 < argc)
            {
                logPath = argv[i + 1];
                ++i;  // Saltar al siguiente parámetro
            }
            else
            {
                cerr << "Error: Falta el nombre del archivo de log." << endl;
                return 1;
            }
        }
        else if (strcmp(argv[i], "--help") == 0 || strcmp(argv[i], "-h") == 0)
        {
            cout << "Uso: " << argv[0] << " --log <log_file>" << endl;
            cout << "Uso: " << "El archivo de logs donde se iran registrando las huellas de los distintos lectores" << endl;
            return 0;
        }
    }

    if (logPath.empty())
    {
        cerr << "Error: Parámetro --log es obligatorio." << endl;
        return 1;
    }

    // Abrir archivo de log usando fstream
    archivoLog.open(logPath, ios::out | ios::app);
    if (!archivoLog.is_open())
    {
        cerr << "Error abriendo archivo de log: " << logPath << endl;
        return 1;
    }


    if (!cargarIDsValidos())
    {
        return 1;
    }

    // Crear el FIFO si no existe
    if (mkfifo(FIFO_PATH, 0666) == -1)
    {
        cerr << "Error creando el FIFO: " << FIFO_PATH << endl;
        return 1;
    }

    // Capturar señales para terminación segura
    signal(SIGINT, senialHandler);
    signal(SIGTERM, senialHandler);

    createDaemon();

    ifstream fifoStream;

    // Bucle principal para leer del FIFO y escribir en el log
    while (true)
    {
        fifoStream.open(FIFO_PATH);
        if (!fifoStream.is_open())
        {
            cerr << "Error al abrir el FIFO para lectura: " << FIFO_PATH << endl;
            continue;
        }

        string linea;
        while (getline(fifoStream, linea))
        {
            istringstream iss(linea);
            string nroSensor, sensorID;
            iss >> nroSensor >> sensorID;

            if (!nroSensor.empty() && !sensorID.empty())
            {
                string status = validIDs.count(sensorID) ? "[VÁLIDA]" : "[INVÁLIDA]";
                archivoLog << "[" << calcularFechaActual() << "] "
                        << "Sensor " << nroSensor << " - Huella: " << sensorID
                        << " " << status << endl;
                archivoLog.flush();  // Nos aseguramos de volcar la info al archivo
            }
        }

        fifoStream.close();
        sleep(1);  // Pausa para evitar carga excesiva
    }


    return 0;
}
