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

using namespace std;

#define MAX_PREGUNTAS 100   // Máximo número de preguntas
#define MAX_OPCIONES 3     // Máximo número de opciones por pregunta
#define TAM_PREGUNTA 256   // Tamaño máximo de una pregunta

const char* MEMORIA_COMPARTIDA = "/memoria_compartida";
const char* SEM_CLIENTE = "/sem_cliente";
const char* SEM_SERVIDOR = "/sem_servidor";
const char* SEM_PUNTOS = "/sem_puntos";
const char* LOCK_FILE = "/tmp/cliente_memoria.lock";

// Estructura para cada pregunta
typedef struct {
    char pregunta[TAM_PREGUNTA];
    char opciones[MAX_OPCIONES][TAM_PREGUNTA];
    int respuestaCorrecta;
    int respuestaCliente;
} Pregunta;

// Estructura de memoria compartida
typedef struct {
    Pregunta preguntas[MAX_PREGUNTAS];
    int puntos;
    int preguntasCargadas;
    pid_t cliente_pid;
} MemoriaCompartida;

// Variables globales
MemoriaCompartida* mc;
int idMemoria;
int lock_fd;
sem_t* sem_cliente;
sem_t* sem_servidor;
sem_t* sem_puntos;

void mostrarAyuda() {
    cout << "Uso: ./Cliente.exe --nickname <nombre_jugador>\n";
    cout << "Opciones:\n";
    cout << "  -n, --nickname  Nickname del usuario (Requerido).\n";
    cout << "  -h, --help      Muestra esta ayuda.\n";
}

void limpiarRecursos(int signal) {
    close(lock_fd);
    unlink(LOCK_FILE);
    exit(EXIT_SUCCESS);
}

void manejarSIGUSR1(int signal)
{
    cout << "Recibida señal SIGUSR1. Finalizando cliente..." << endl;
    limpiarRecursos(signal);
}

int main(int argc, char *argv[]) {
    // Validar parámetros
    if (argc < 3) {
        mostrarAyuda();
        return EXIT_FAILURE;
    }

    string nickname;
    int contador = 0;
    
    // Procesar argumentos
    for (int i = 1; i < argc; i++) {
        if (strcmp(argv[i], "-n") == 0 || strcmp(argv[i], "--nickname") == 0) {
            if (i + 1 < argc) {
                nickname = argv[++i];
            } else {
                cerr << "Error: Se requiere un nombre de jugador después de " << argv[i] << endl;
                mostrarAyuda();
                return EXIT_FAILURE;
            }
        } else if (strcmp(argv[i], "-h") == 0 || strcmp(argv[i], "--help") == 0) {
            mostrarAyuda();
            return EXIT_SUCCESS;
        } else {
            cerr << "Parámetro desconocido: " << argv[i] << endl;
            mostrarAyuda();
            return EXIT_FAILURE;
        }
    }

    // Ignorar SIGINT
    signal(SIGINT, SIG_IGN);
    signal(SIGTERM, limpiarRecursos);
    signal(SIGHUP, limpiarRecursos);
    signal(SIGUSR1, manejarSIGUSR1);

    // Crear archivo de bloqueo para evitar tener dos clientes en simultaneo.
    lock_fd = open(LOCK_FILE, O_CREAT | O_RDWR, 0666);
    if (lock_fd == -1)
    {
        perror("Error al crear archivo de bloqueo");
        exit(EXIT_FAILURE);
    }
    if (flock(lock_fd, LOCK_EX | LOCK_NB) == -1)
    {
        perror("Error: otro cliente ya está en ejecución");
        close(lock_fd);
        exit(EXIT_FAILURE);
    }

    // Conectar a la memoria compartida
    idMemoria = shm_open(MEMORIA_COMPARTIDA, O_CREAT | O_RDWR, 0600);
    if (idMemoria == -1) {
        perror("Error al leer memoria compartida");
        limpiarRecursos(0);
        exit(EXIT_FAILURE);
    }

    mc = (MemoriaCompartida*) mmap(NULL, sizeof(MemoriaCompartida),
        PROT_READ | PROT_WRITE, MAP_SHARED, idMemoria, 0);
    if (mc == MAP_FAILED) {
        perror("Error al mapear la memoria compartida");
        limpiarRecursos(0);
        exit(EXIT_FAILURE);
    }

    // Conectar a los semáforos
    sem_cliente = sem_open(SEM_CLIENTE, 0);
    if (sem_cliente == SEM_FAILED) {
        cerr << "Error al conectar al semáforo del cliente." << endl;
        limpiarRecursos(0);
        exit(EXIT_FAILURE);
    }

    sem_servidor = sem_open(SEM_SERVIDOR, 0);
    if (sem_servidor == SEM_FAILED) {
        cerr << "Error al conectar al semáforo del servidor." << endl;
        limpiarRecursos(0);
        exit(EXIT_FAILURE);
    }

    sem_puntos = sem_open(SEM_PUNTOS, 0);
    if (sem_puntos == SEM_FAILED) {
        cerr << "Error al conectar al semáforo del servidor." << endl;
        limpiarRecursos(0);
        exit(EXIT_FAILURE);
    }

    // Iniciar la comunicación
    cout << "Bienvenido, " << nickname << ". Esperando preguntas..." << endl;  
    
    // Avisar al servidor que el cliente está listo
    sem_wait(sem_servidor);
    sem_post(sem_cliente);

    // Asigno el pid del cliente para indicar que comenzo el juego
    mc->cliente_pid = getpid();
    
    while (contador < mc->preguntasCargadas) {
        // Mostrar la pregunta
        cout << "Pregunta: " << mc->preguntas[contador].pregunta << endl;
        for (int i = 0; i < MAX_OPCIONES; i++) {
            cout << i + 1 << ". " << mc->preguntas[contador].opciones[i] << endl;
        }

        // Obtener la respuesta del usuario
        int respuesta;
        cout << "Tu respuesta: ";
        cin >> respuesta;
        mc->preguntas[contador].respuestaCliente = respuesta; // Enviar la respuesta al servidor
        contador ++;
        // Avisar al servidor
        sem_post(sem_cliente);
    }
    sem_wait(sem_puntos);
    std::cout << "Partida finalizada. Puntos: " << mc->puntos << std::endl;


    return 0;
}
