/*
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#
#               Virtualizacion de Hardware              #
#                                                       #
#   APL2                                                #
#   Nro ejercicio: 5                                    #
#   Nro entrega: 1                                      #
#   Nombre del script: Cliente.cpp                      #
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
#include <sys/ipc.h>
#include <sys/mman.h>
#include <sys/shm.h>
#include <unistd.h>
#include <vector>
#include <regex>
#include <cstdlib>
#include <time.h>
#include <sys/socket.h>
#include <sys/types.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <netdb.h>

using namespace std;

const char* SEM_CLIENTE = "/sem_cliente";
const char* SEM_SERVIDOR = "/sem_servidor";
const char* SEM_PUNTOS = "/sem_puntos";

// Estructura para cada pregunta
typedef struct
{
    string pregunta;
    vector<string> opciones;
    int respuestaCorrecta;
} Pregunta;

// Variables globales
vector<Pregunta> preguntas;
sem_t* sem_cliente;
sem_t* sem_servidor;
sem_t* sem_puntos;

void mostrarAyuda() {
    cout << "Uso: ./Cliente.exe -n <nombre_jugador> -p <puerto> -s <ip_del_servidor>\n";
    cout << "Opciones:\n";
    cout << "   -n, --nickname  Nickname del usuario (Requerido).\n";
    cout << "   -p, --puerto    Nro de puerto (Requerido).\n";
    cout << "   -s, --servidor  Dirección IP o nombre del servidor (Requerido).\n";
    cout << "   -h, --help      Muestra esta ayuda.\n";
}

void limpiarRecursos(int signal) {
    exit(EXIT_SUCCESS);
}

void manejarSIGUSR1(int signal)
{
    cout << "Recibida señal SIGUSR1. Finalizando cliente..." << endl;
    limpiarRecursos(signal);
}

void procesarArgumentos(int argc, char *argv[], string& nickname, int& puerto, string& servidor) {
    for (int i = 1; i < argc; i++) {
        if (strcmp(argv[i], "-n") == 0 || strcmp(argv[i], "--nickname") == 0) {
            if (i + 1 < argc) {
                nickname = argv[++i];
            } else {
                cerr << "Error: Se requiere un nombre de jugador después de " << argv[i] << endl;
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
        } else if (strcmp(argv[i], "-s") == 0 || strcmp(argv[i], "--servidor") == 0) {
            if (i + 1 < argc) {
                servidor = argv[++i];
            } else {
                cerr << "Error: Se requiere una IP después de " << argv[i] << endl;
                mostrarAyuda();
                exit(EXIT_FAILURE);
            }
        } else if (strcmp(argv[i], "-h") == 0 || strcmp(argv[i], "--help") == 0) {
            mostrarAyuda();
            exit(EXIT_FAILURE);
        } else {
            cerr << "Parámetro desconocido: " << argv[i] << endl;
            mostrarAyuda();
            exit(EXIT_FAILURE);
        }
    }
}

void validarParametros(const string& nickname, int puerto, const string& servidor)
{
    // Validar que el nickname no esté vacío
    if (nickname.empty())
    {
        cerr << "Error: El nickname no puede estar vacío." << endl;
        exit(EXIT_FAILURE);
    }

    // Validar que el puerto esté en el rango válido
    if (puerto < 1024 || puerto > 65535)
    {
        cerr << "Error: El puerto debe estar en el rango de 1024 a 65535." << endl;
        exit(EXIT_FAILURE);
    }

    // Validar que la dirección del servidor no esté vacía
    if (servidor.empty())
    {
        cerr << "Error: La dirección del servidor no puede estar vacía." << endl;
        exit(EXIT_FAILURE);
    }

    // Validar si el servidor es una IP o un nombre de dominio válido
    regex ipRegex("^((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\\.){3}(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$");
    regex dominioRegex("^([a-zA-Z0-9-]+\\.)+[a-zA-Z]{2,}$");

    if (!regex_match(servidor, ipRegex) && !regex_match(servidor, dominioRegex))
    {
        cerr << "Error: La dirección del servidor debe ser una IP válida o un nombre de dominio válido." << endl;
        exit(EXIT_FAILURE);
    }
}

void conectarSemaforos()
{
    sem_cliente = sem_open(SEM_CLIENTE, 0);
    if (sem_cliente == SEM_FAILED) {
        cerr << "Error al conectar con el servidor." << endl;
        limpiarRecursos(0);
        exit(EXIT_FAILURE);
    }

    sem_servidor = sem_open(SEM_SERVIDOR, 0);
    if (sem_servidor == SEM_FAILED) {
        cerr << "Error al conectar con el servidor." << endl;
        limpiarRecursos(0);
        exit(EXIT_FAILURE);
    }

    sem_puntos = sem_open(SEM_PUNTOS, 0);
    if (sem_puntos == SEM_FAILED) {
        cerr << "Error al conectar con el servidor." << endl;
        limpiarRecursos(0);
        exit(EXIT_FAILURE);
    }
}

int configurarSocket(const char* servidor, int puerto) {
    struct sockaddr_in clientConfig;
    int socketComunicacion;

    memset(&clientConfig, '0', sizeof(clientConfig));

    clientConfig.sin_family = AF_INET;
    clientConfig.sin_port = htons(puerto);
    inet_pton(AF_INET, servidor, &clientConfig.sin_addr);

    socketComunicacion = socket(AF_INET, SOCK_STREAM, 0);

    int resultadoConexion = connect(socketComunicacion, (struct sockaddr *)&clientConfig, sizeof(clientConfig));

    if (resultadoConexion < 0)
    {
        cout << "Error en la conexión" << endl;
        limpiarRecursos(0);
        return EXIT_FAILURE;
    }

    return socketComunicacion;
}

int main(int argc, char *argv[]) {
    string nickname;
    string servidor;
    int socketCliente;
    int puerto = 0;
    int contador = 0;
    
    if (argc < 7) {
        mostrarAyuda();
        exit(EXIT_FAILURE);
    }
    
    // Procesamos y validamos los argumentos
    procesarArgumentos(argc, argv, nickname, puerto, servidor);
    validarParametros(nickname, puerto, servidor);

    // Manejamos las señales
    signal(SIGINT, SIG_IGN);
    signal(SIGTERM, limpiarRecursos);
    signal(SIGHUP, limpiarRecursos);
    signal(SIGUSR1, manejarSIGUSR1);

    // Conectamos con los semáforos
    conectarSemaforos();

    // Configuramos el socket para iniciar la comunicación con el servidor.
    socketCliente = configurarSocket(servidor.c_str(), puerto);

    char buffer[2000];
    int bytesRecibidos = 0;
    while ((bytesRecibidos = read(socketCliente, buffer, sizeof(buffer) - 1)) > 0)
    {
        buffer[bytesRecibidos] = 0;
        printf("%s\n", buffer);
    }

    close(socketCliente);

    // Iniciar la comunicación
    // cout << "Bienvenido, " << nickname << ". Esperando preguntas..." << endl;  
    
    // // Avisar al servidor que el cliente está listo
    // sem_wait(sem_servidor);
    // sem_post(sem_cliente);

    // // Asigno el pid del cliente para indicar que comenzo el juego
    // mc->cliente_pid = getpid();
    
    // while (contador < mc->preguntasCargadas) {
    //     // Mostrar la pregunta
    //     cout << "Pregunta: " << mc->preguntas[contador].pregunta << endl;
    //     for (int i = 0; i < MAX_OPCIONES; i++) {
    //         cout << i + 1 << ". " << mc->preguntas[contador].opciones[i] << endl;
    //     }

    //     // Obtener la respuesta del usuario
    //     int respuesta;
    //     cout << "Tu respuesta: ";
    //     cin >> respuesta;
    //     mc->preguntas[contador].respuestaCliente = respuesta; // Enviar la respuesta al servidor
    //     contador ++;
    //     // Avisar al servidor
    //     sem_post(sem_cliente);
    // }
    // sem_wait(sem_puntos);
    // std::cout << "Partida finalizada. Puntos: " << mc->puntos << std::endl;
    return EXIT_SUCCESS;
}
