/*
#########################################################
#               Virtualizacion de hardware              #
#                                                       #
#   APL2 - Ejercicio 4                                  #
#   Nombre del script: Servidor.cpp                     #
#                                                       #
#   Integrantes:                                        #
#                                                       #
#       Ocampo, Nicole Fabiana              44451238    #
#       Sandoval Vasquez, Juan Leandro      41548235    #
#       Tigani, Martin Sebastian            32788835    #
#       Villegas, Lucas Ezequiel            37792844    #
#       Vivas, Pablo Ezequiel               38703964    #
#                                                       #
#   Instancia de entrega: Reentrega                     #
#                                                       #
#########################################################
*/

#include <iostream>
#include <fstream>
#include <cstring>
#include <csignal>
#include <unistd.h>
#include <fcntl.h>
#include <sys/mman.h>
#include <semaphore.h>
#include <sys/file.h>

#define MAX_PREGUNTAS 10   // Máximo número de preguntas
#define MAX_OPCIONES 3     // Máximo número de opciones por pregunta
#define TAM_PREGUNTA 256   // Tamaño máximo de una pregunta

const char* MEMORIA_COMPARTIDA = "/memoria_compartida";
const char* SEM_CLIENTE = "/sem_cliente";
const char* SEM_SERVIDOR = "/sem_servidor";
const char* LOCK_FILE = "/tmp/servidor_memoria.lock";

// Estructura para cada pregunta
typedef struct {
    char pregunta[TAM_PREGUNTA];
    char opciones[MAX_OPCIONES][TAM_PREGUNTA];
    int respuestaCorrecta;
} Pregunta;

// Estructura de memoria compartida
typedef struct {
    Pregunta preguntas[MAX_PREGUNTAS];
    int preguntaActual;
    int puntos;
    pid_t cliente_pid;
} MemoriaCompartida;

// Variables globales
MemoriaCompartida* mc;
int idMemoria;
int lock_fd;
sem_t* sem_cliente;
sem_t* sem_servidor;

void mostrarAyuda() {
    std::cout << "Uso: ./servidor -a <archivo> -c <cantidad>\n";
    std::cout << "Opciones:\n";
    std::cout << "  -a, --archivo   Archivo con las preguntas (Requerido).\n";
    std::cout << "  -c, --cantidad  Cantidad de preguntas por partida (Requerido).\n";
    std::cout << "  -h, --help      Muestra esta ayuda.\n";
}

void manejarSIGUSR1(int signal)
{
    if (mc->cliente_pid == 0)
    {
        std::cout << "Recibida señal SIGUSR1. Finalizando servidor..." << std::endl;
        munmap(mc, sizeof(MemoriaCompartida));
        shm_unlink(MEMORIA_COMPARTIDA);
        sem_unlink(SEM_CLIENTE);
        sem_unlink(SEM_SERVIDOR);
        close(lock_fd);
        unlink(LOCK_FILE);
        exit(0);
    }
    else
    {
        std::cerr << "Recibida señal SIGUSR1, pero hay una partida en progreso. Ignorando..." << std::endl;
    }
}


void limpiarRecursos()
{

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

    // Liberamos archivo de bloqueo
    if (lock_fd != -1) {
        close(lock_fd);
        unlink(LOCK_FILE);
    }
}

void crearMemoriaCompartida() {
    idMemoria = shm_open(MEMORIA_COMPARTIDA, O_CREAT | O_RDWR, 0600);
    if (idMemoria == -1) {
        perror("Error al crear memoria compartida");
        limpiarRecursos();
        exit(EXIT_FAILURE);
    }
    if (ftruncate(idMemoria, sizeof(MemoriaCompartida)) == -1) {
        perror("Error al dimensionar la memoria compartida");
        limpiarRecursos();
        exit(EXIT_FAILURE);
    }
}

void mapearMemoriaCompartida() {
    mc = (MemoriaCompartida*) mmap(NULL, sizeof(MemoriaCompartida), PROT_READ | PROT_WRITE, MAP_SHARED, idMemoria, 0);
    if (mc == MAP_FAILED) {
        perror("Error al mapear la memoria compartida");
        limpiarRecursos();
        exit(EXIT_FAILURE);
    }
}

void inicializarSemaforos()
{
    sem_cliente = sem_open(SEM_CLIENTE, O_CREAT, 0666, 0);
    if (sem_cliente == SEM_FAILED)
    {
        perror("Error al crear semáforo cliente");
        exit(EXIT_FAILURE);
    }

    sem_servidor = sem_open(SEM_SERVIDOR, O_CREAT, 0666, 0);
    if (sem_servidor == SEM_FAILED)
    {
        perror("Error al crear semáforo servidor");
        sem_close(sem_cliente);
        sem_unlink(SEM_CLIENTE);
        exit(EXIT_FAILURE);
    }
}

void cargarPreguntas(const char* archivo) {
    std::ifstream file(archivo);
    std::string linea;
    int indice = 0;

    while (std::getline(file, linea) && indice < MAX_PREGUNTAS) {
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
}

int main(int argc, char *argv[])
{
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

    if (cantidad <= 0 || cantidad > MAX_PREGUNTAS) {
        std::cerr << "Error: La cantidad de preguntas debe ser entre 1 y " << MAX_PREGUNTAS << std::endl;
        exit(EXIT_FAILURE);
    }

    signal(SIGINT, SIG_IGN);
    signal(SIGUSR1, manejarSIGUSR1);

    // Crear archivo de bloqueo
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
    cargarPreguntas(archivo);

    std::cout << "Servidor iniciado. Esperando usuario..." << std::endl;

    while (true) {
        sem_wait(sem_cliente); // Esperamos al cliente
        std::cout << "Cliente conectado.\n";

        // Mostramos preguntas y procesamos respuestas
        for (int i = 0; i < MAX_PREGUNTAS; ++i) {
            std::cout << "Pregunta: " << mc->preguntas[i].pregunta << "\n";
            std::cout << "1. " << mc->preguntas[i].opciones[0] << "\n";
            std::cout << "2. " << mc->preguntas[i].opciones[1] << "\n";
            std::cout << "3. " << mc->preguntas[i].opciones[2] << "\n";

            // Esperamos respuesta del cliente
            sem_post(sem_servidor);
            sem_wait(sem_cliente);

            int respuesta = mc->preguntaActual; // Leemos respuesta del cliente
            if (respuesta == mc->preguntas[i].respuestaCorrecta) {
                mc->puntos++;
            }
        }

        std::cout << "Partida finalizada. Puntos: " << mc->puntos << std::endl;
        sem_post(sem_servidor); // Permitimos al cliente finalizar
    }

    printf("Finalizando servidor...\n");
    limpiarRecursos();
   
    return EXIT_SUCCESS;
}