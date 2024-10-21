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
#include <semaphore.h>

using namespace std;

#define BUFFER_SIZE 16384

// Estructura para cada pregunta
typedef struct
{
    string pregunta;
    vector<string> opciones;
    char respuestaCorrecta;
} Pregunta;

// Variables globales
vector<Pregunta> preguntas;

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

vector<char> recibirBuffer(int socket) {
    int size;
    // Recibir el tamaño del buffer
    int bytesReceived = recv(socket, &size, sizeof(int), 0);
    if (bytesReceived <= 0) {
        if (bytesReceived == 0) {
            // El cliente se desconectó
            cerr << "El Servidor se ha desconectado." << endl;
        } else {
            // Error en la recepción
            perror("Error en recv");
        }
        return {};
    }
    // Reservar espacio para el contenido del buffer
    vector<char> buffer(size);
    // Recibir el contenido del buffer
    bytesReceived = recv(socket, buffer.data(), size, 0);
    if (bytesReceived <= 0) {
        if (bytesReceived == 0) {
            // El cliente se desconectó
            cerr << "El Servidor se ha desconectado." << endl;
        } else {
            // Error en la recepción
            perror("Error en recv");
        }
        return {};
    }
    return buffer;
}

Pregunta deserializarPregunta(const vector<char> &buffer) {
    Pregunta pregunta;
    size_t offset = 0;

    // Deserializar la longitud de la pregunta
    int pregunta_len;
    memcpy(&pregunta_len, &buffer[offset], sizeof(int));
    offset += sizeof(int);

    // Deserializar el contenido de la pregunta
    pregunta.pregunta = string(buffer.begin() + offset, buffer.begin() + offset + pregunta_len);
    offset += pregunta_len;

    // Deserializar el número de opciones
    int num_opciones;
    memcpy(&num_opciones, &buffer[offset], sizeof(int));
    offset += sizeof(int);

    // Deserializar cada opción
    pregunta.opciones.resize(num_opciones);
    for (int i = 0; i < num_opciones; ++i) {
        int opcion_len;
        memcpy(&opcion_len, &buffer[offset], sizeof(int));
        offset += sizeof(int);

        pregunta.opciones[i] = string(buffer.begin() + offset, buffer.begin() + offset + opcion_len);
        offset += opcion_len;
    }

    // Deserializar la respuesta correcta
    memcpy(&pregunta.respuestaCorrecta, &buffer[offset], sizeof(int));

    return pregunta;
}

vector<char> serializarRespuesta(char respuesta) {
    vector<char> buffer;
    buffer.push_back(respuesta);  // Serializa el char directamente
    return buffer;
}

bool enviarBuffer(int socket, const vector<char> &buffer) {
    int size = buffer.size();
    // Enviar el tamaño del buffer
    int bytesSent = send(socket, &size, sizeof(int), 0);
    if (bytesSent <= 0) {
        if (bytesSent == 0) {
            // El servidor se desconectó
            cerr << "El Servidor se ha desconectado." << endl;
        } else {
            // Error en el envío
            perror("Error en send");
        }
        return false;
    }


    // Enviar el contenido del buffer
    bytesSent = send(socket, buffer.data(), size, 0);
    if (bytesSent <= 0) {
        if (bytesSent == 0) {
            // El Servidor se desconectó
            cerr << "El Servidor se ha desconectado." << endl;
        } else {
            // Error en el envío
            perror("Error en send");
        }
        return false;
    }
    return true;
}

int main(int argc, char *argv[]) {
    string nickname;
    string servidor;
    vector<char> buffer(BUFFER_SIZE);
    int valorLeido;
    int socketCliente;
    int puerto = 0;
    
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

    // Configuramos el socket para iniciar la comunicación con el servidor.
    socketCliente = configurarSocket(servidor.c_str(), puerto);

    if (send(socketCliente, nickname.c_str(), nickname.size(), 0) < 0) {
        perror("Error el servidor puede estar desconectado");
        close(socketCliente);
        exit(EXIT_FAILURE);
    }
    cout << "Nickname enviado al servidor: " << nickname << endl;

    char confirmacion[2048] = {0};
    // Esperando el mensaje de confirmación del servidor en la cual recibo mi id y nickname.
    valorLeido = recv(socketCliente, confirmacion, sizeof(confirmacion) - 1, 0);
    if (valorLeido < 0) {
        perror("Error en recv");
        close(socketCliente);
        exit(EXIT_FAILURE);
    }
    if(valorLeido == 0) {
        perror("Servidor desconectado.\n");
        close(socketCliente);
        exit(EXIT_FAILURE);
    }

    // Aseguramos que el buffer de confirmación termine en '\0'
    confirmacion[valorLeido] = '\0';
    printf("Mensaje de confirmación del servidor: %s\n", confirmacion);


    // Esperar el mensaje de inicio del juego
    valorLeido = recv(socketCliente, buffer.data(), BUFFER_SIZE, 0);
    if (valorLeido < 0) {
        perror("Error al recibir datos del servidor \n");
        close(socketCliente);
        exit(EXIT_FAILURE);
    }
    if(valorLeido == 0) {
        perror("Servidor desconectado.\n");
        close(socketCliente);
        exit(EXIT_FAILURE);
    }

    printf("%s\n", buffer.data());

     // Comunicación con el servidor
    bool juegoTerminado=false;
    while (!juegoTerminado) {
        // Esperar hasta que el servidor indique que es el turno del cliente
        char menIni[1024] = {0};
        valorLeido = recv(socketCliente, menIni, sizeof(menIni) - 1, 0);
        if (valorLeido < 0) {
            perror("Error al recibir datos del servidor o conexión cerrada \n");
            close(socketCliente);
            exit(EXIT_FAILURE);
        }
        if(valorLeido == 0) {
            perror("Servidor desconectado.\n");
            close(socketCliente);
            exit(EXIT_FAILURE);
        }

        if (strncmp(menIni, "¡El juego ha terminado!", strlen("¡El juego ha terminado!")) == 0) {
            printf("%s", menIni); // Imprimir el mensaje de juego terminado
            juegoTerminado = true;
            break;
        }

        vector<char> preguntaSerializada = recibirBuffer(socketCliente);
        if (preguntaSerializada.empty()) {
            printf("Error, Servidor desconectado o error de conexion\n");
            close(socketCliente);
            exit(EXIT_FAILURE);
        }

        Pregunta preguntaRecibida = deserializarPregunta(preguntaSerializada);

        int numeroOpciones = preguntaRecibida.opciones.size(); // Número total de opciones disponibles
        
        // Mostrar la pregunta
        cout << "Pregunta: " << preguntaRecibida.pregunta << endl;
        for (int i = 0; i < numeroOpciones; i++) {
            cout << i + 1 << ". " << preguntaRecibida.opciones[i] << endl;
        }

        char respuesta;

        //Para los do-while tener en cuenta que estos cierren cuando el servidor se desconecte. es decir, enviar una condición extra
        do {
            printf("Tu respuesta es ");
            scanf(" %c", &respuesta); // El espacio antes de %c consume cualquier carácter de espacio en blanco

            // Limpiar el búfer de entrada
            while (getchar() != '\n'); // Leer y descartar los caracteres restantes

            // Si la respuesta está fuera del rango, indicamos que es inválida
            if (respuesta < '1' || respuesta > ('0' + numeroOpciones)) {
                printf("Respuesta inválida. Por favor, ingresa una opción entre 1 y %d.\n", numeroOpciones);
            }

        } while (respuesta < '1' || respuesta > ('0' + numeroOpciones));

        // Serializar la respuesta y enviarla al servidor
        vector<char> respuestaSerializada = serializarRespuesta(respuesta);
        if(!enviarBuffer(socketCliente, respuestaSerializada)){
            printf("Error, Servidor desconectado o error de conexion\n");
            close(socketCliente);
            exit(EXIT_FAILURE);
        }
    }

    close(socketCliente);
    return EXIT_SUCCESS;
}
