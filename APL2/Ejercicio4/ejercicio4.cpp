#include <iostream>
#include <fstream>
#include <cstring>
#include <csignal>
#include <sys/ipc.h>
#include <sys/shm.h>
#include <sys/types.h>
#include <semaphore.h>
#include <fcntl.h>
#include <unistd.h>
#include <cstdlib>

#define SHM_KEY 1234       // Clave de memoria compartida
#define MAX_QUESTIONS 10   // Máximo número de preguntas
#define MAX_OPTIONS 3      // Máximo número de opciones por pregunta
#define QUESTION_SIZE 256  // Tamaño máximo de una pregunta

// Estructura para cada pregunta
struct Question {
    char text[QUESTION_SIZE];
    char options[MAX_OPTIONS][QUESTION_SIZE];
    int correctAnswer;
};

// Estructura de memoria compartida
struct SharedMemory {
    Question questions[MAX_QUESTIONS];
    int currentQuestion;
    int score;
    sem_t sem_client;
    sem_t sem_server;
};

// Variables globales para el servidor
int shm_id;
SharedMemory* shm_ptr;

// Función para leer preguntas desde un archivo
void loadQuestionsFromFile(const char* filename, SharedMemory* shm_ptr, int question_count) {
    std::ifstream file(filename);
    if (!file.is_open()) {
        std::cerr << "Error: no se pudo abrir el archivo de preguntas.\n";
        exit(1);
    }

    for (int i = 0; i < question_count; ++i) {
        std::string line;
        std::getline(file, line);
        if (line.empty()) break;

        // Parsear línea de pregunta
        char* token = std::strtok(&line[0], ",");
        std::strcpy(shm_ptr->questions[i].text, token);

        for (int j = 0; j < MAX_OPTIONS; ++j) {
            token = std::strtok(nullptr, ",");
            std::strcpy(shm_ptr->questions[i].options[j], token);
        }

        token = std::strtok(nullptr, ",");
        shm_ptr->questions[i].correctAnswer = std::atoi(token);
    }
    file.close();
}

// Manejar la señal SIGUSR1 para finalizar el servidor
void handleSIGUSR1(int sig) {
    if (shm_ptr->currentQuestion == 0) { // No hay partidas en progreso
        std::cout << "Servidor finalizando...\n";
        shmdt(shm_ptr);
        shmctl(shm_id, IPC_RMID, nullptr);  // Eliminar la memoria compartida
        exit(0);
    }
}

void runServer(const char* filename, int question_count) {
    // Crear memoria compartida
    shm_id = shmget(SHM_KEY, sizeof(SharedMemory), IPC_CREAT | 0666);
    if (shm_id < 0) {
        std::cerr << "Error al crear la memoria compartida.\n";
        exit(1);
    }

    shm_ptr = (SharedMemory*)shmat(shm_id, nullptr, 0);
    if (shm_ptr == (void*)-1) {
        std::cerr << "Error al adjuntar la memoria compartida.\n";
        exit(1);
    }

    // Inicializar semáforos
    sem_init(&shm_ptr->sem_client, 1, 0);
    sem_init(&shm_ptr->sem_server, 1, 1);
    shm_ptr->score = 0;
    shm_ptr->currentQuestion = 0;

    // Cargar preguntas desde el archivo
    loadQuestionsFromFile(filename, shm_ptr, question_count);

    // Manejar la señal SIGUSR1
    signal(SIGUSR1, handleSIGUSR1);

    std::cout << "Servidor esperando al cliente...\n";
    
    while (true) {
        // Esperar a que el cliente esté listo
        sem_wait(&shm_ptr->sem_server);

        // Enviar pregunta al cliente
        if (shm_ptr->currentQuestion < question_count) {
            std::cout << "Enviando pregunta " << shm_ptr->currentQuestion + 1 << " al cliente...\n";
        } else {
            std::cout << "Partida finalizada. Puntaje final: " << shm_ptr->score << "\n";
            shm_ptr->currentQuestion = 0;
        }

        // Liberar al cliente
        sem_post(&shm_ptr->sem_client);
    }
}

void runClient(const char* nickname) {
    // Conectar a la memoria compartida
    shm_id = shmget(SHM_KEY, sizeof(SharedMemory), 0666);
    if (shm_id < 0) {
        std::cerr << "Error al conectar a la memoria compartida.\n";
        exit(1);
    }

    shm_ptr = (SharedMemory*)shmat(shm_id, nullptr, 0);
    if (shm_ptr == (void*)-1) {
        std::cerr << "Error al adjuntar la memoria compartida.\n";
        exit(1);
    }

    std::cout << "Cliente " << nickname << " conectado.\n";

    while (true) {
        // Esperar a que el servidor envíe una pregunta
        sem_wait(&shm_ptr->sem_client);

        if (shm_ptr->currentQuestion < MAX_QUESTIONS) {
            // Mostrar la pregunta
            Question& q = shm_ptr->questions[shm_ptr->currentQuestion];
            std::cout << "Pregunta: " << q.text << "\n";
            for (int i = 0; i < MAX_OPTIONS; ++i) {
                std::cout << i + 1 << ". " << q.options[i] << "\n";
            }

            // Leer respuesta del usuario
            int answer;
            std::cout << "Ingrese su respuesta (1-3): ";
            std::cin >> answer;

            // Actualizar puntaje
            if (answer == q.correctAnswer) {
                std::cout << "¡Correcto!\n";
                shm_ptr->score++;
            } else {
                std::cout << "Incorrecto. La respuesta correcta era: " << q.options[q.correctAnswer - 1] << "\n";
            }

            // Avanzar a la siguiente pregunta
            shm_ptr->currentQuestion++;

            // Liberar al servidor
            sem_post(&shm_ptr->sem_server);
        } else {
            std::cout << "Partida finalizada. Puntaje final: " << shm_ptr->score << "\n";
            break;
        }
    }

    // Desconectar de la memoria compartida
    shmdt(shm_ptr);
}

int main(int argc, char* argv[]) {
    if (argc < 2) {
        std::cerr << "Uso: " << argv[0] << " --server <archivo_preguntas> <cantidad_preguntas> | --client <nickname>\n";
        return 1;
    }

    if (std::strcmp(argv[1], "--server") == 0 && argc == 4) {
        const char* filename = argv[2];
        int question_count = std::atoi(argv[3]);
        runServer(filename, question_count);
    } else if (std::strcmp(argv[1], "--client") == 0 && argc == 3) {
        const char* nickname = argv[2];
        runClient(nickname);
    } else {
        std::cerr << "Uso incorrecto de los parámetros.\n";
        return 1;
    }

    return 0;
}

int crearFork() {
    pid_t procesoHijo = fork();
    if (procesoHijo == -1) {
        perror("Error en la creacion de fork()");
        exit(ERROR_CREACION_FORK);
    }
    return procesoHijo;
}


    if (argc > 1) {
        return validarParametroAyuda(argc, argv[1]);
    }
    cout << "Por favor, aguarde unos segundos hasta que se muestre la jerarquia completa ..." << endl;
    /*=============== Estoy en el proceso Padre ===============*/
    prctl(PR_SET_NAME, NOMBRE_PROCESO_PADRE.c_str(), 0, 0, 0);
    informarProcesoActual(obtenerNombreProceso(getpid()), getpid(), getppid());
    sleep(SEGUNDOS_ESPERA_PROCESO_PADRE);
    int estado;
    pid_t pidHijo1 = fork();
    if (pidHijo1 == CREACION_EXITOSA) {
        /*=============== Estoy en el proceso Hijo 1 ===============*/
        prctl(PR_SET_NAME, NOMBRE_PROCESO_PRIMER_HIJO.c_str(), 0, 0, 0);
        informarProcesoActual(obtenerNombreProceso(getpid()), getpid(), getppid());
        sleep(SEGUNDOS_ESPERA_PROCESOS_HIJOS);
 if (crearFork() == CREACION_EXITOSA) {
            /*=============== Estoy en el proceso Nieto 1 ===============*/
            prctl(PR_SET_NAME, NOMBRE_PROCESO_PRIMER_NIETO.c_str(), 0, 0, 0);
            informarProcesoActual(obtenerNombreProceso(getpid()), getpid(), getppid());
            sleep(SEGUNDOS_ESPERA_PROCESOS_NIETOS);
        } else {
            /*=============== Estoy en el proceso Hijo 1 ===============*/
            if (crearFork() == CREACION_EXITOSA) {
                /*=============== Estoy en el proceso Zombie (Nieto 2) ===============*/
                prctl(PR_SET_NAME, NOMBRE_PROCESO_SEGUNDO_NIETO.c_str(), 0, 0, 0);
                informarProcesoActual(obtenerNombreProceso(getpid()), getpid(), getppid());
                sleep(SEGUNDOS_ESPERA_PROCESOS_ZOMBIES);
                exit(0);
            } else {
                /*=============== Estoy en el proceso Hijo 1 ===============*/
                if (crearFork() == CREACION_EXITOSA) {
                    /*=============== Estoy en el proceso Nieto 3 ===============*/
                    prctl(PR_SET_NAME, NOMBRE_PROCESO_TERCER_NIETO.c_str(), 0, 0, 0);
                    informarProcesoActual(obtenerNombreProceso(getpid()), getpid(), getppid());
                } else {
                    /*=============== Estoy en el proceso Hijo 1 ===============*/
                    // Espero a Nieto 3
                    wait(NULL);
                    // Espero a Nieto 1
                    wait(NULL);
                }
            }