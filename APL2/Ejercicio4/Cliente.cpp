#include <iostream>
#include <sys/ipc.h>
#include <sys/shm.h>
#include <cstring>
#include <csignal>
#include <semaphore.h>
#include <unistd.h>

using namespace std;

#define MAX_PREGUNTAS 10   // Máximo número de preguntas
#define MAX_OPCIONES 3     // Máximo número de opciones por pregunta
#define TAM_PREGUNTA 256   // Tamaño máximo de una pregunta

const char* MEMORIA_COMPARTIDA = "/dev/shm/memoria_compartida";
const char* SEM_CLIENTE = "/sem_cliente";
const char* SEM_SERVIDOR = "/sem_servidor";

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
int mc_fd;
sem_t* sem_cliente;
sem_t* sem_servidor;

// Inicializar semáforo
void operarSemaforo(sem_t* sem, int operacion) {
    if (operacion > 0) {
        sem_post(sem);
    } else {
        sem_wait(sem);
    }
}

void mostrarAyuda() {
    cout << "Uso: ./cliente --nickname <nombre_jugador>\n";
    cout << "Opciones:\n";
    cout << "  --nickname      Nickname del usuario (Requerido).\n";
    cout << "  -h, --help      Muestra esta ayuda.\n";
}

int main(int argc, char *argv[]) {
    // Ignorar SIGINT
    signal(SIGINT, SIG_IGN);

    // Validar parámetros
    if (argc < 3) {
        mostrarAyuda();
        return 1;
    }

    string nickname;
    
    // Procesar argumentos
    for (int i = 1; i < argc; i++) {
        if (strcmp(argv[i], "--nickname") == 0) {
            if (i + 1 < argc) {
                nickname = argv[++i];
            } else {
                cerr << "Error: Se requiere un nombre de jugador después de " << argv[i] << endl;
                mostrarAyuda();
                return 1;
            }
        } else if (strcmp(argv[i], "-h") == 0 || strcmp(argv[i], "--help") == 0) {
            mostrarAyuda();
            return 0;
        } else {
            cerr << "Parámetro desconocido: " << argv[i] << endl;
            mostrarAyuda();
            return 1;
        }
    }

    // Conectar a la memoria compartida
    key_t key = ftok(MEMORIA_COMPARTIDA, 65);
    int shmId = shmget(key, sizeof(MemoriaCompartida), 0600);
    if (shmId == -1) {
        cerr << "Error: El servidor no está corriendo o no se pudo conectar a la memoria compartida." << endl;
        return 1;
    }
    
    mc = (MemoriaCompartida *) shmat(shmId, nullptr, 0);
    if (mc == (MemoriaCompartida *)-1) {
        cerr << "Error al conectar a la memoria compartida." << endl;
        return 1;
    }

    // Conectar a los semáforos
    sem_cliente = sem_open(SEM_CLIENTE, 0);
    if (sem_cliente == SEM_FAILED) {
        cerr << "Error al conectar al semáforo del cliente." << endl;
        return 1;
    }

    sem_servidor = sem_open(SEM_SERVIDOR, 0);
    if (sem_servidor == SEM_FAILED) {
        cerr << "Error al conectar al semáforo del servidor." << endl;
        return 1;
    }

    // Iniciar la comunicación
    cout << "Bienvenido, " << nickname << ". Esperando preguntas..." << endl;
    operarSemaforo(sem_servidor, 1); // Avisar al servidor que el cliente está listo

    while (true) {
        // Esperar a recibir una pregunta
        operarSemaforo(sem_cliente, -1);

        // Mostrar la pregunta
        cout << "Pregunta: " << mc->preguntas[mc->preguntaActual].pregunta << endl;
        for (int i = 0; i < MAX_OPCIONES; i++) {
            cout << i + 1 << ". " << mc->preguntas[mc->preguntaActual].opciones[i] << endl;
        }

        // Obtener la respuesta del usuario
        int respuesta;
        cout << "Tu respuesta: ";
        cin >> respuesta;
        mc->preguntaActual = respuesta; // Enviar la respuesta al servidor

        // Avisar al servidor
        operarSemaforo(sem_servidor, 1);
    }

    return 0;
}
