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

using namespace std;

#define MAX_PREGUNTAS 100  // Máximo número de preguntas en la memoria compartida
#define MAX_OPCIONES 3     // Máximo número de opciones por pregunta
#define TAM_PREGUNTA 256   // Tamaño máximo de una pregunta

const char* MEMORIA_COMPARTIDA = "/memoria_compartida";
const char* SEM_CLIENTE = "/sem_cliente";
const char* SEM_SERVIDOR = "/sem_servidor";
const char* SEM_PUNTOS = "/sem_puntos";
const char* LOCK_FILE = "/tmp/servidor_memoria.lock";

// Estructura para cada pregunta
typedef struct {
    char pregunta[TAM_PREGUNTA];
    char opciones[MAX_OPCIONES][TAM_PREGUNTA];
    int respuestaCorrecta;
    int respuestaCliente;
} Pregunta;

// Estructura de memoria compartida
typedef struct {
    Pregunta preguntas[MAX_PREGUNTAS];  // Reemplazamos vector por array
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
    std::cout << "Uso: ./Servidor.exe -a <archivo> -c <cantidad>\n";
    std::cout << "Opciones:\n";
    std::cout << "  -a, --archivo   Archivo con las preguntas (Requerido).\n";
    std::cout << "  -c, --cantidad  Cantidad de preguntas por partida (Requerido).\n";
    std::cout << "  -h, --help      Muestra esta ayuda.\n";
}

void manejarSIGUSR1(int signal)
{
    if (mc->cliente_pid == 0)
    {
        cout << "Recibida señal SIGUSR1. Finalizando servidor..." << endl;
        munmap(mc, sizeof(MemoriaCompartida));
        shm_unlink(MEMORIA_COMPARTIDA);
        sem_close(sem_cliente);
        sem_unlink(SEM_CLIENTE);
        sem_close(sem_servidor);
        sem_unlink(SEM_SERVIDOR);
        sem_close(sem_puntos);
        sem_unlink(SEM_PUNTOS);
        close(lock_fd);
        unlink(LOCK_FILE);
        exit(0);
    }
    else
    {
        cerr << "Recibida señal SIGUSR1, pero hay una partida en progreso. Ignorando..." << std::endl;
    }
}


void limpiarRecursos(int signal)
{
    // Liberamos recursos del cliente en caso de haber partida.
    if(mc->cliente_pid != 0)
        kill(mc->cliente_pid, SIGUSR1);

    // Liberamos memoria compartida
    if (mc) {
        munmap(mc, sizeof(MemoriaCompartida));
        shm_unlink(MEMORIA_COMPARTIDA);
    }
    
    // Liberamos semáforo del cliente
    if (sem_cliente) {
        sem_close(sem_cliente);
        sem_unlink(SEM_CLIENTE);
    }

    // Liberamos semáforo del servidor
    if (sem_servidor) {
        sem_close(sem_servidor);
        sem_unlink(SEM_SERVIDOR);
    }

    // Liberamos semáforo de los puntos
    if (sem_puntos) {
        sem_close(sem_puntos);
        sem_unlink(SEM_PUNTOS);
    }

    // Liberamos archivo de bloqueo
    if (lock_fd != -1) {
        close(lock_fd);
        unlink(LOCK_FILE);
    }
    
    exit(EXIT_SUCCESS);
}

void crearMemoriaCompartida() {
    idMemoria = shm_open(MEMORIA_COMPARTIDA, O_CREAT | O_RDWR, 0600);
    if (idMemoria == -1) {
        perror("Error al crear memoria compartida");
        limpiarRecursos(0);
        exit(EXIT_FAILURE);
    }
    if (ftruncate(idMemoria, sizeof(MemoriaCompartida)) == -1) {
        perror("Error al dimensionar la memoria compartida");
        limpiarRecursos(0);
        exit(EXIT_FAILURE);
    }
}

void mapearMemoriaCompartida() {
    mc = (MemoriaCompartida*) mmap(NULL, sizeof(MemoriaCompartida),
        PROT_READ | PROT_WRITE, MAP_SHARED, idMemoria, 0);
    if (mc == MAP_FAILED) {
        perror("Error al mapear la memoria compartida");
        limpiarRecursos(0);
        exit(EXIT_FAILURE);
    }
}

void inicializarSemaforos()
{
    sem_cliente = sem_open(SEM_CLIENTE, O_CREAT, 0666, 0);
    if (sem_cliente == SEM_FAILED)
    {
        perror("Error al crear semáforo de cliente");
        exit(EXIT_FAILURE);
    }

    sem_servidor = sem_open(SEM_SERVIDOR, O_CREAT, 0666, 0);
    if (sem_servidor == SEM_FAILED)
    {
        perror("Error al crear semáforo de servidor");
        sem_close(sem_cliente);
        sem_unlink(SEM_CLIENTE);
        exit(EXIT_FAILURE);
    }

    sem_puntos = sem_open(SEM_PUNTOS, O_CREAT, 0600, 0);
    if (sem_puntos == SEM_FAILED)
    {
        perror("Error al crear semáforo de puntos");
        sem_close(sem_cliente);
        sem_unlink(SEM_CLIENTE);
        sem_close(sem_servidor);
        sem_unlink(SEM_SERVIDOR);
        exit(EXIT_FAILURE);
    }
}

int cargarPreguntas(const char* archivo, int cantidadRecibida) {
    std::ifstream file(archivo);
    std::string linea;
    int indice = 0;


    while (std::getline(file, linea) && indice < cantidadRecibida) {
        std::string pregunta, opcion1, opcion2, opcion3;
        int respuesta;

        size_t pos = linea.find(",");
        pregunta = linea.substr(0, pos);
        linea.erase(0, pos + 1);

        pos = linea.find(",");
        respuesta = std::stoi(linea.substr(0, pos));
        linea.erase(0, pos + 1);

        pos = linea.find(",");
        opcion1 = linea.substr(0, pos);
        linea.erase(0, pos + 1);

        pos = linea.find(",");
        opcion2 = linea.substr(0, pos);
        linea.erase(0, pos + 1);

        opcion3 = linea;

        strncpy(mc->preguntas[indice].pregunta, pregunta.c_str(), TAM_PREGUNTA);
        strncpy(mc->preguntas[indice].opciones[0], opcion1.c_str(), TAM_PREGUNTA);
        strncpy(mc->preguntas[indice].opciones[1], opcion2.c_str(), TAM_PREGUNTA);
        strncpy(mc->preguntas[indice].opciones[2], opcion3.c_str(), TAM_PREGUNTA);
        mc->preguntas[indice].respuestaCorrecta = respuesta;

        indice++;
    }
    file.close();
    return indice;
}

int main(int argc, char *argv[]) {
    // Validar parámetros
    if (argc < 5)
    {
        mostrarAyuda();
        exit(EXIT_FAILURE);
    }

    const char* archivo = nullptr;
    int cantidad = 0;

    // Procesar argumentos
    for (int i = 1; i < argc; i++) {
        if (strcmp(argv[i], "-a") == 0 || strcmp(argv[i], "--archivo") == 0) {
            if (i + 1 < argc) {
                archivo = argv[++i];
            } else {
                std::cerr << "Error: Se requiere un archivo después de " << argv[i] << std::endl;
                mostrarAyuda();
                exit(EXIT_FAILURE);
            }
        } else if (strcmp(argv[i], "-c") == 0 || strcmp(argv[i], "--cantidad") == 0) {
            if (i + 1 < argc) {
                cantidad = std::stoi(argv[++i]);
            } else {
                std::cerr << "Error: Se requiere una cantidad después de " << argv[i] << std::endl;
                mostrarAyuda();
                exit(EXIT_FAILURE);
            }
        } else if (strcmp(argv[i], "-h") == 0 || strcmp(argv[i], "--help") == 0) {
            mostrarAyuda();
            exit(EXIT_SUCCESS);
        } else {
            std::cerr << "Parámetro desconocido: " << argv[i] << std::endl;
            mostrarAyuda();
            exit(EXIT_FAILURE);
        }
    }

    if (cantidad <= 0) {
        std::cerr << "Error: La cantidad de preguntas debe ser mayor a 0" << std::endl;
        exit(EXIT_FAILURE);
    }

    signal(SIGINT, SIG_IGN);
    signal(SIGTERM, limpiarRecursos);
    signal(SIGHUP, limpiarRecursos);
    signal(SIGUSR1, manejarSIGUSR1);

    // Crear archivo de bloqueo para evitar tener dos servidores en simultaneo.
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
     
    // Creamos y mapeamos memoria compartida
    crearMemoriaCompartida();
    mapearMemoriaCompartida();
    
    // Inicializamos los semaforos
    inicializarSemaforos();

    // Cargamos las preguntas del archivo csv
    mc->preguntasCargadas = cargarPreguntas(archivo, cantidad);

    std::cout << "Servidor iniciado. Esperando usuario..." << std::endl;
    
    while (true) {
        mc->cliente_pid = 0;
        sem_post(sem_servidor);
        sem_wait(sem_cliente); // Esperamos al cliente
        mc->puntos = 0;
        std::cout << "Cliente conectado.\n";

        // Mostramos preguntas y procesamos respuestas
        for (int i = 0; i < mc->preguntasCargadas; ++i) {
            // Esperamos respuesta del cliente
            sem_wait(sem_cliente);
            // Leemos respuesta del cliente
            if (mc->preguntas[i].respuestaCliente == mc->preguntas[i].respuestaCorrecta) {
                mc->puntos++;
            }
        }
        sem_post(sem_puntos); // Permitimos al cliente finalizar
        std::cout << "Fin de la partida. Esperando usuario...\n";
    }

    printf("Finalizando servidor...\n");
    limpiarRecursos(0);
   
    return EXIT_SUCCESS;
}