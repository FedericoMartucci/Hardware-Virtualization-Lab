/*
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#
#               Virtualizacion de Hardware              #
#                                                       #
#   APL2                                                #
#   Nro ejercicio: 5                                    #
#   Nro entrega: 1                                      #
#   Nombre del script: Servidor.cpp                     #
#                                                       #
#   Integrantes:                                        #
#                                                       #
#       Branchesi, Tomas Agustin      43013625          #
#       Martucci, Federico Ariel      44690247          #
#                                                       #
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#
*/

#include <csignal>
#include <cstring>
#include <fcntl.h>
#include <fstream>
#include <iostream>
#include <semaphore.h>
#include <sys/file.h>
#include <sys/mman.h>
#include <unistd.h>
#include <iostream>
#include <fstream>
#include <vector>
#include <string>
#include <netinet/in.h>
#include <unistd.h>
#include <cstring>
#include <thread>
#include <map>

using namespace std;

const char* SEM_CLIENTE = "/sem_cliente";
const char* SEM_SERVIDOR = "/sem_servidor";
const char* SEM_PUNTOS = "/sem_puntos";
const char* LOCK_FILE = "/tmp/servidor_memoria.lock";

// Estructura para cada pregunta
typedef struct
{
    string pregunta;
    vector<string> opciones;
    int respuestaCorrecta;
} Pregunta;

// Estructura para el cliente y su puntaje
typedef struct
{
    int socket;
    int puntos;
    int respuestaCliente;
    string nickname;
} Jugador;

// Variables globales
map<pid_t, Jugador> jugadores;
vector<Pregunta> preguntas;
int lock_fd;
sem_t *sem_cliente;
sem_t *sem_servidor;
sem_t *sem_puntos;

void mostrarAyuda()
{
    cout << "Uso: ./Servidor.exe -p <puerto> -u <cantidad_de_usuarios> -a <archivo> -c <cantidad_de_preguntas>\n";
    cout << "Opciones:\n";
    cout << "  -p, --puerto    Número de puerto (Requerido).\n";
    cout << "  -u, --usuarios  Cantidad de ususarios a esperar para iniciar la sala (Requerido).\n";
    cout << "  -a, --archivo   Archivo con las preguntas (Requerido).\n";
    cout << "  -c, --cantidad  Cantidad de preguntas por partida (Requerido).\n";
    cout << "  -h, --help      Muestra esta ayuda.\n";
}

void procesarArgumentos(int argc, char *argv[], const char *&archivo, int &cantPreguntas, int &cantUsuarios, int &puerto) {
    for (int i = 1; i < argc; i++) {
        if (strcmp(argv[i], "-a") == 0 || strcmp(argv[i], "--archivo") == 0) {
            if (i + 1 < argc) {
                archivo = argv[++i];
            } else {
                cerr << "Error: Se requiere un archivo después de " << argv[i] << endl;
                mostrarAyuda();
                exit(EXIT_FAILURE);
            }
        } else if (strcmp(argv[i], "-c") == 0 || strcmp(argv[i], "--cantidad") == 0) {
            if (i + 1 < argc) {
                cantPreguntas = stoi(argv[++i]);
            } else {
                cerr << "Error: Se requiere una cantidad después de " << argv[i] << endl;
                mostrarAyuda();
                exit(EXIT_FAILURE);
            }
        } else if (strcmp(argv[i], "-u") == 0 || strcmp(argv[i], "--usuarios") == 0) {
            if (i + 1 < argc) {
                cantUsuarios = stoi(argv[++i]);
            } else {
                cerr << "Error: Se requiere un cantidad de usuarios después de " << argv[i] << endl;
                mostrarAyuda();
                exit(EXIT_FAILURE);
            }
        } else if (strcmp(argv[i], "-p") == 0 || strcmp(argv[i], "--puerto") == 0) {
            if (i + 1 < argc) {
                puerto = stoi(argv[++i]);
            } else {
                cerr << "Error: Se requiere un puerto después de " << argv[i] << endl;
                mostrarAyuda();
                exit(EXIT_FAILURE);
            }
        } else if (strcmp(argv[i], "-h") == 0 || strcmp(argv[i], "--help") == 0) {
            mostrarAyuda();
            exit(EXIT_SUCCESS);
        } else {
            cerr << "Parámetro desconocido: " << argv[i] << endl;
            mostrarAyuda();
            exit(EXIT_FAILURE);
        }
    }
}

void validarParametros(int cantUsuarios, int puerto, int cantPreguntas)
{
    // Validamos que la cantidad sea un numero positivo mayor a 0.
    if (cantUsuarios <= 0)
    {
        cerr << "Error: La cantidad de preguntas debe ser mayor a 0" << std::endl;
        exit(EXIT_FAILURE);
    }

    // Validamos que sea un puerto válido.
    if (puerto < 1024 || puerto > 65535)
    {
        cerr << "Error: El puerto debe estar en el rango de 1024 a 65535." << std::endl;
        exit(EXIT_FAILURE);
    }

    // Validamos que la cantidad sea un numero positivo mayor a 0.
    if (cantPreguntas <= 0)
    {
        cerr << "Error: La cantidad de preguntas debe ser mayor a 0" << std::endl;
        exit(EXIT_FAILURE);
    }
}

void crearLockFile()
{
    lock_fd = open(LOCK_FILE, O_CREAT | O_RDWR, 0666);
    
    if (lock_fd == -1)
    {
        perror("Error al crear archivo de bloqueo");
        exit(EXIT_FAILURE);
    }

    if (flock(lock_fd, LOCK_EX | LOCK_NB) == -1)
    {
        perror("Error: otro servidor ya está en ejecución");
        close(lock_fd);
        exit(EXIT_FAILURE);
    }
}

void manejarSIGUSR1(int signal)
{
    if (jugadores.empty())
    {
        cout << "Recibida señal SIGUSR1. Finalizando servidor..." << endl;
        sem_close(sem_cliente);
        sem_unlink(SEM_CLIENTE);
        sem_close(sem_servidor);
        sem_unlink(SEM_SERVIDOR);
        sem_close(sem_puntos);
        sem_unlink(SEM_PUNTOS);
        close(lock_fd);
        unlink(LOCK_FILE);
        exit(EXIT_SUCCESS);
    }
    else
    {
        cerr << "Recibida señal SIGUSR1, pero hay una partida en progreso. Ignorando..." << std::endl;
    }
}

void limpiarRecursos(int signal)
{
    // Liberamos semáforo del cliente
    if (sem_cliente)
    {
        sem_close(sem_cliente);
        sem_unlink(SEM_CLIENTE);
    }

    // Liberamos semáforo del servidor
    if (sem_servidor)
    {
        sem_close(sem_servidor);
        sem_unlink(SEM_SERVIDOR);
    }

    // Liberamos semáforo de los puntos
    if (sem_puntos)
    {
        sem_close(sem_puntos);
        sem_unlink(SEM_PUNTOS);
    }

    // Liberamos archivo de bloqueo
    if (lock_fd != -1)
    {
        close(lock_fd);
        unlink(LOCK_FILE);
    }

    exit(EXIT_SUCCESS);
}

void inicializarSemaforos()
{
    sem_cliente = sem_open(SEM_CLIENTE, O_CREAT, 0666, 0);
    if (sem_cliente == SEM_FAILED)
    {
        perror("Error al crear semáforo de cliente");
        limpiarRecursos(0);
        exit(EXIT_FAILURE);
    }

    sem_servidor = sem_open(SEM_SERVIDOR, O_CREAT, 0666, 0);
    if (sem_servidor == SEM_FAILED)
    {
        perror("Error al crear semáforo de servidor");
        limpiarRecursos(0);
        exit(EXIT_FAILURE);
    }

    sem_puntos = sem_open(SEM_PUNTOS, O_CREAT, 0600, 0);
    if (sem_puntos == SEM_FAILED)
    {
        perror("Error al crear semáforo de puntos");
        limpiarRecursos(0);
        exit(EXIT_FAILURE);
    }
}

int cargarPreguntas(const char *archivo, int cantidadRecibida)
{
    ifstream file(archivo);
    string linea;
    int cantidadDePreguntas = 0;

    if (!file.is_open()) {
        cerr << "Error al abrir el archivo." << endl;
        return -1;
    }

    while (getline(file, linea) && cantidadDePreguntas < cantidadRecibida)
    {
        string pregunta, opcion1, opcion2, opcion3;
        int respuesta;

        size_t pos = linea.find(",");
        pregunta = linea.substr(0, pos);
        linea.erase(0, pos + 1);

        pos = linea.find(",");
        respuesta = stoi(linea.substr(0, pos));
        linea.erase(0, pos + 1);

        pos = linea.find(",");
        opcion1 = linea.substr(0, pos);
        linea.erase(0, pos + 1);

        pos = linea.find(",");
        opcion2 = linea.substr(0, pos);
        linea.erase(0, pos + 1);

        opcion3 = linea;

        // Creamos el objeto Pregunta
        Pregunta nuevaPregunta;
        nuevaPregunta.pregunta = pregunta;
        nuevaPregunta.opciones.push_back(opcion1);
        nuevaPregunta.opciones.push_back(opcion2);
        nuevaPregunta.opciones.push_back(opcion3);
        nuevaPregunta.respuestaCorrecta = respuesta;

        // Agregamos la pregunta al vector de preguntas
        preguntas.push_back(nuevaPregunta);

        cantidadDePreguntas++;
    }

    file.close();
    return cantidadDePreguntas;
}

int configurarSocket(int cantUsuarios, int puerto) {
    struct sockaddr_in serverConfig;
    int socketEscucha;

    memset(&serverConfig, '0', sizeof(serverConfig));

    serverConfig.sin_family = AF_INET; // IPV4: 127.0.0.1
    serverConfig.sin_addr.s_addr = htonl(INADDR_ANY);
    serverConfig.sin_port = htons(puerto); // Es recomendable que el puerto sea mayor a 1023 para aplicaciones de usuario.

    // Creamos el socket
    if ((socketEscucha = socket(AF_INET, SOCK_STREAM, 0)) == 0)
    {
        perror("Creación de socket fallida.");
        exit(EXIT_FAILURE);
    }

    // Asociamos socket al puerto recibido
    if (bind(socketEscucha, (struct sockaddr *)&serverConfig, sizeof(serverConfig)) < 0)
    {
        perror("Bind fallido.");
        exit(EXIT_FAILURE);
    }

    // Escuchar conexiones
    if (listen(socketEscucha, cantUsuarios) < 0)
    {
        perror("Configuración de escucha de conexiones fallida.");
        exit(EXIT_FAILURE);
    }

    return socketEscucha;
}

void hilo(int socketId)
{
    time_t ticks = time(NULL);
    char sendBuff[2000];
    snprintf(sendBuff, sizeof(sendBuff), "%.24s\r\n", ctime(&ticks));

    write(socketId, sendBuff, strlen(sendBuff));
    close(socketId);
}

// while (true)
// {
//     mc->cliente_pid = 0;
//     sem_post(sem_servidor);
//     sem_wait(sem_cliente); // Esperamos al cliente
//     mc->puntos = 0;
//     std::cout << "Cliente conectado.\n";

//     // Mostramos preguntas y procesamos respuestas
//     for (int i = 0; i < preguntasCargadas; ++i)
//     {
//         // Esperamos respuesta del cliente
//         sem_wait(sem_cliente);
//         // Leemos respuesta del cliente
//         if (mc->preguntas[i].respuestaCliente == mc->preguntas[i].respuestaCorrecta)
//         {
//             mc->puntos++;
//         }
//     }
//     sem_post(sem_puntos); // Permitimos al cliente finalizar
//     std::cout << "Fin de la partida. Esperando usuario...\n";
// }


// void handle_client(int client_socket, std::map<int, ClientInfo> &clients, std::vector<std::string> &questions)
// {
//     char buffer[1024];
//     int question_index = 0;

//     while (true)
//     {
//         memset(buffer, 0, sizeof(buffer));
//         int valread = read(client_socket, buffer, 1024);

//         if (valread == 0)
//         {
//             std::cout << "Cliente desconectado." << std::endl;
//             close(client_socket);
//             return;
//         }

//         std::string client_response(buffer);
//         std::cout << "Respuesta del cliente: " << client_response << std::endl;

//         // Enviar la siguiente pregunta
//         if (question_index < questions.size())
//         {
//             std::string question = questions[question_index];
//             send(client_socket, question.c_str(), question.size(), 0);
//             question_index++;
//         }
//         else
//         {
//             std::string end_msg = "Fin del juego.";
//             send(client_socket, end_msg.c_str(), end_msg.size(), 0);
//             break;
//         }
//     }
// }

int main(int argc, char *argv[])
{
    const char *archivo = nullptr;
    int cantPreguntas = 0;
    int puerto = 0;
    int cantUsuarios = 0;
    int preguntasCargadas;
    int socketServidor;

    if (argc < 9)
    {
        mostrarAyuda();
        exit(EXIT_FAILURE);
    }

    // Procesamos y validamos los argumentos
    procesarArgumentos(argc, argv, archivo, cantPreguntas, cantUsuarios, puerto);
    validarParametros(cantUsuarios, puerto, cantPreguntas);

    // Manejamos las señales
    signal(SIGINT, SIG_IGN);
    signal(SIGTERM, limpiarRecursos);
    signal(SIGHUP, limpiarRecursos);
    signal(SIGUSR1, manejarSIGUSR1);

    // Creamos archivo de bloqueo para evitar tener dos servidores en simultáneo.
    crearLockFile();

    // Inicializamos los semaforos
    inicializarSemaforos();

    // Cargamos las preguntas del archivo csv
    preguntasCargadas = cargarPreguntas(archivo, cantPreguntas);

    // Configuramos el socket
    socketServidor = configurarSocket(cantUsuarios, puerto);

    cout << "Servidor escuchando en el puerto " << puerto << endl;

    while (true)
    {
        int socketComunicacion = accept(socketServidor, (struct sockaddr *)NULL, NULL);
        
        thread th(hilo, socketComunicacion);
        th.detach();
    }

    printf("Finalizando servidor...\n");
    limpiarRecursos(0);

    return EXIT_SUCCESS;
}