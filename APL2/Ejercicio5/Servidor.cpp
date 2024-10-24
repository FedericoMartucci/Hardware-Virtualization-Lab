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
#include <list>
#include <sstream>

using namespace std;

const char* LOCK_FILE = "/tmp/servidor_memoria.lock";

// Estructura para cada pregunta
typedef struct
{
    string pregunta;
    vector<string> opciones;
    char respuestaCorrecta;
} Pregunta;

// Estructura para el cliente y su puntaje
typedef struct
{
    int socketId;
    int puntos;
    string nickname;
} Jugador;

// Variables globales
list<Jugador> jugadores;
vector<Pregunta> preguntas;
int lock_fd;

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
    // Liberamos archivo de bloqueo
    if (lock_fd != -1)
    {
        close(lock_fd);
        unlink(LOCK_FILE);
    }

    cerrarSocketsClientes();

    exit(EXIT_SUCCESS);
}

int cargarPreguntas(const char *archivo, int cantidadRecibida)
{
    ifstream file(archivo);
    string linea;
    int cantidadDePreguntas = 0;

    if (!file.is_open()) {
        cerr << "Error al abrir el archivo." << endl;
        limpiarRecursos(0);
    }

    while (getline(file, linea) && cantidadDePreguntas < cantidadRecibida)
    {
        string pregunta, opcion1, opcion2, opcion3;
        char respuesta;

        size_t pos = linea.find(",");
        pregunta = linea.substr(0, pos);
        linea.erase(0, pos + 1);

        pos = linea.find(",");
        string respuestaStr = linea.substr(0, pos);
        respuesta = respuestaStr[0];
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
        close(socketEscucha);
        exit(EXIT_FAILURE);
    }

    // Escuchar conexiones entrantes
    if (listen(socketEscucha, cantUsuarios) < 0)
    {
        perror("Configuración de escucha de conexiones fallida.");
        close(socketEscucha);
        exit(EXIT_FAILURE);
    }

    return socketEscucha;
}

void agregarJugador(int socketId, char buffer[]) {
    Jugador nuevoJugador;
    nuevoJugador.socketId = socketId;
    nuevoJugador.puntos = 0;
    nuevoJugador.nickname = string(buffer);

    jugadores.push_back(nuevoJugador);
    cout << "Nuevo jugador agregado con nickname: " << nuevoJugador.nickname 
         << " y ID: " << nuevoJugador.socketId << endl;
}

vector<char> serializarPregunta(const Pregunta &pregunta) {
    vector<char> buffer;

    // Serializar la longitud y el contenido de la pregunta
    int pregunta_len = pregunta.pregunta.size();
    buffer.insert(buffer.end(), reinterpret_cast<const char*>(&pregunta_len), reinterpret_cast<const char*>(&pregunta_len) + sizeof(int));
    buffer.insert(buffer.end(), pregunta.pregunta.begin(), pregunta.pregunta.end());

    // Serializar el número de opciones
    int num_opciones = pregunta.opciones.size();
    buffer.insert(buffer.end(), reinterpret_cast<const char*>(&num_opciones), reinterpret_cast<const char*>(&num_opciones) + sizeof(int));

    // Serializar cada opción
    for (const string &opcion : pregunta.opciones) {
        int opcion_len = opcion.size();
        buffer.insert(buffer.end(), reinterpret_cast<const char*>(&opcion_len), reinterpret_cast<const char*>(&opcion_len) + sizeof(int));
        buffer.insert(buffer.end(), opcion.begin(), opcion.end());
    }

    // Serializar la respuesta correcta
    buffer.insert(buffer.end(), reinterpret_cast<const char*>(&pregunta.respuestaCorrecta), reinterpret_cast<const char*>(&pregunta.respuestaCorrecta) + sizeof(int));

    return buffer;
}

bool enviarBuffer(int socket, const vector<char> &buffer) {
    int size = buffer.size();
    // Enviar el tamaño del buffer
    int bytesSent = send(socket, &size, sizeof(int), 0);
    if (bytesSent <= 0) {
        if (bytesSent == 0) {
            // El cliente se desconectó
            cerr << "El cliente se ha desconectado." << endl;
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
            // El cliente se desconectó
            cerr << "El cliente se ha desconectado." << endl;
        } else {
            // Error en el envío
            perror("Error en send");
        }
        return false;
    }
    return true;
}

vector<char> recibirBuffer(int socket) {
    int size;
    // Recibir el tamaño del buffer
    int bytesReceived = recv(socket, &size, sizeof(int), 0);
    if (bytesReceived <= 0) {
        if (bytesReceived == 0) {
            // El cliente se desconectó
            cerr << "El cliente se ha desconectado." << endl;
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
            cerr << "El cliente se ha desconectado." << endl;
        } else {
            // Error en la recepción
            perror("Error en recv");
        }
        return {};
    }
    return buffer;
}

char deserializarRespuesta (const vector<char> &buffer){
    char respuesta;
    memcpy(&respuesta,buffer.data(), sizeof(respuesta));
    return respuesta;
}

void cerrarSocketsClientes() {
    for (auto it = jugadores.begin(); it != jugadores.end();) {
        close(it->socketId);
        it = jugadores.erase(it);
    }
}

pair<int, list<Jugador>> obtenerGanadores() {
    int puntajeMaximo = 0;
    list<Jugador> ganadores;

    // Encontrar la puntuación máxima
    for (const auto& jugador : jugadores) {
        if (jugador.puntos > puntajeMaximo) {
            puntajeMaximo = jugador.puntos;
        }
    }

    // Encontrar todos los jugadores con la puntuación máxima
    for (const auto& jugador : jugadores) {
        if (jugador.puntos == puntajeMaximo) {
            ganadores.push_back(jugador);
        }
    }

    return make_pair(puntajeMaximo, ganadores);
}


int main(int argc, char *argv[])
{
    const char *archivo = nullptr;
    int cantPreguntas = 0;
    int puerto = 0;
    int cantUsuarios = 0;
    int usuariosConectados = 0;
    int preguntasRealizadas = 0;
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

    // Cargamos las preguntas del archivo csv
    preguntasCargadas = cargarPreguntas(archivo, cantPreguntas);

    // Configuramos el socket
    socketServidor = configurarSocket(cantUsuarios, puerto);

    cout << "Servidor escuchando en el puerto " << puerto << endl;


     while (usuariosConectados < cantUsuarios) {
        int socketCliente;
        if ((socketCliente = accept(socketServidor, NULL, NULL)) < 0) {
            perror("Error en la conexión con el cliente.");
            close(socketServidor);
            limpiarRecursos(1);
            exit(EXIT_FAILURE);
        }

        //Recibimos el nickname del cliente
        char bufferConexion[1024] = {0};
        int valorLeido = recv(socketCliente, bufferConexion, 1024, 0);
        if (valorLeido < 0) {
            perror("No se recibieron datos");
            close(socketServidor);
            limpiarRecursos(1);
            exit(EXIT_FAILURE);
        }

        if (valorLeido == 0){
            printf("\n Error de conexión: cliente desconectado.\n");
            continue;
        }

        agregarJugador(socketCliente, bufferConexion);

        char registro[1024];
        // Convertimos el socketId a cadena
        sprintf(registro, "%d", socketCliente);

        // Concatenamos la cadena del número al buffer original
        strcat(bufferConexion, " ");
        strcat(bufferConexion, registro);

        char leyenda[2048] = "Nuevo jugador conectado cuyo nickname y puerto son: ";
        strcat(leyenda, bufferConexion);

        int send_result = send(socketCliente, leyenda, strlen(leyenda), 0);
        if (send_result < 0) {
            perror("Error en send en armado de conexión con cliente");
            close(socketCliente);
            cerrarSocketsClientes();
            exit(EXIT_FAILURE);
        }
        usuariosConectados++;
    }

    // Notificar a cada cliente que el juego ha comenzado
    for (auto it = jugadores.begin(); it != jugadores.end(); ) {
        const char *message = "El juego ha comenzado\n";
        printf("Notificando al cliente %d\n", it->socketId);
        int noti = send(it->socketId, message, strlen(message), 0);

        if (noti < 0) {
            perror("Error al enviar mensaje");
            printf("Cliente con socket %d eliminado de la lista debido a error de envío.\n", it->socketId);
            close(it->socketId);
            it = jugadores.erase(it);
        } else if (noti == 0) {
            printf("Cliente con socket %d desconectado.\n", it->socketId);
            close(it->socketId);
            it = jugadores.erase(it);
        } else {
            ++it;
        }
    }

    bool respMensaje = false;

    while (preguntasRealizadas < preguntasCargadas && jugadores.size() > 1) {
        auto jugador = jugadores.begin();
        while (jugador != jugadores.end() && preguntasRealizadas < preguntasCargadas && jugadores.size() > 1) {
            if (preguntasRealizadas < preguntasCargadas && jugadores.size() > 1) {
                char menIni[1024] = {0};
                printf("enviando turno a: %d\n", jugador->socketId);

                // Intentar recibir para verificar la conexión
                char bufferTest[1];
                int recvResult = recv(jugador->socketId, bufferTest, sizeof(bufferTest), MSG_PEEK | MSG_DONTWAIT);
                if (recvResult == 0 || (recvResult < 0 && errno != EAGAIN && errno != EWOULDBLOCK)) {
                    perror("Jugador desconectado detectado por recv");
                    close(jugador->socketId);
                    jugador = jugadores.erase(jugador);
                    continue;
                }
                strcpy(menIni, "Siguiente turno!");
                if (send(jugador->socketId, menIni, strlen(menIni), 0) <= 0) {
                    perror("Error en mensaje o jugador desconectado");
                    printf("Error, jugador desconectado o error de conexion\n");
                    close(jugador->socketId);
                    jugador = jugadores.erase(jugador);
                    continue;
                }
                printf("turno enviado\n");

                // Serializar pregunta para enviársela al cliente
                vector<char> preguntaSerializada = serializarPregunta(preguntas[preguntasRealizadas]);

                // Enviar pregunta al cliente
                respMensaje = enviarBuffer(jugador->socketId, preguntaSerializada);
                if (!respMensaje) {
                    printf("Error, jugador desconectado o error de conexion\n");
                    close(jugador->socketId);
                    jugador = jugadores.erase(jugador);
                    continue;
                }

                // Recibir respuesta del cliente y deserializarla
                vector<char> respuestaRecibida = recibirBuffer(jugador->socketId);
                if (respuestaRecibida.empty()) {
                    printf("Error, jugador desconectado o error de conexion\n");
                    close(jugador->socketId);
                    jugador = jugadores.erase(jugador);
                    continue;
                }

                char respuestaCliente = deserializarRespuesta(respuestaRecibida);

                // Validar respuesta del cliente
                if (preguntas[preguntasRealizadas].respuestaCorrecta == respuestaCliente) {
                    jugador->puntos++; //gador.puntos pero en vez de la copia, accedes a literalmente esa pos de mem
                }

                jugador ++;
            } else {
                break;
            }
        }
        preguntasRealizadas ++;
    }

    printf("Notificando finalización de juego\n");

    if (jugadores.size() <= 1) {
        printf("\n¡El juego ha terminado!: no hay suficientes jugadores para continuar.\n");
        for (const auto& jugador : jugadores) {
            const char* message = "¡El juego ha terminado!: no hay suficientes jugadores para continuar.\n";
            send(jugador.socketId, message, strlen(message), 0);
        }
    } else {
        printf("\n¡El juego ha terminado!\n");

        // Obtener los ganadores y su puntaje
        pair<int, list<Jugador>> resultado = obtenerGanadores();
        int maxPuntuacion = resultado.first;
        list<Jugador> ganadores = resultado.second;

        // Construir mensaje de finalización del juego con ganadores
        ostringstream mensajeFinal;
        mensajeFinal << "¡El juego ha terminado!\n";
        mensajeFinal << "Puntuación máxima: " << maxPuntuacion << "\n";
        mensajeFinal << "Ganadores:\n";
        for (const auto& ganador : ganadores) {
            mensajeFinal << "ID Jugador: " << ganador.socketId << ", Nickname: " << ganador.nickname << ", Puntuación: " << ganador.puntos << "\n";
            cout << "Ganador " << ganador.socketId << ", " << ganador.nickname << endl;
        }
        //cout << mensajeFinal.str();

        string mensajeFinalStr = mensajeFinal.str();
        const char* mensajeFinalCStr = mensajeFinalStr.c_str();

        cout << "Mensaje final: " << mensajeFinalCStr << endl;

        for (const auto& jugador : jugadores) {
            int bytesEnviadosUltimoMensaje = send(jugador.socketId, mensajeFinalCStr, strlen(mensajeFinalCStr), 0);
            if (bytesEnviadosUltimoMensaje == -1) {
                cerr << "Error al enviar mensaje a ID Jugador: " << jugador.socketId << endl;
            } else if (bytesEnviadosUltimoMensaje < (int) strlen(mensajeFinalCStr)) {
                // Manejo de mensaje parcialmente enviado
                cerr << "Mensaje parcialmente enviado a ID Jugador: " << jugador.socketId << endl;
            }
        }
    }

    cout << "Finalizando servidor..." << endl;
    limpiarRecursos(0);

    // Cerrar el socket del servidor
    close(socketServidor);

    return EXIT_SUCCESS;
}