/*
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#
#               Virtualizacion de Hardware              #
#                                                       #
#   APL2                                                #
#   Nro ejercicio: 2                                    #
#   Nro entrega: 1                                      #
#   Nombre del script: ejercicio2.cpp                   #
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
#include <filesystem>
#include <thread>
#include <mutex>
#include <vector>
#include <queue>
#include <string>
#include <map>


// Declarar los espacios de nombres que usaremos
using namespace std;
using namespace std::filesystem;

// Variables globales para sincronización y manejo de archivos
mutex mtx;
queue<path> archivosAProcesar;

// Función para procesar archivos y buscar la cadena en cada línea
void buscarEnArchivo(int threadId, const string& patronDeBusqueda) {
    while (true) {
        path archivoActual;

        // Obtener un archivo de la cola de manera segura
        /*
        *
        *   Usamos lock_guard en vez de mtx.lock y mtx.unlock ya que
        *   no es recomendable debido a que si el código genera una excepción o un retorno 
        *   prematuro, el mutex podría quedar bloqueado y causar un deadlock, de esta forma
        *   se garantiza que el mutex se desbloquee al salir del ámbito por cualquier ocurrencia.
        *
        */
        {
            lock_guard<mutex> lock(mtx);
            if (archivosAProcesar.empty()) return; // Si no hay más archivos, salir
            archivoActual = archivosAProcesar.front();
            archivosAProcesar.pop();
        }

        // Abrir el archivo y buscar la cadena en cada línea
        ifstream archivo(archivoActual);
        string linea;
        int numeroDeLinea = 1;
        while (getline(archivo, linea)) {
            if (linea.find(patronDeBusqueda) != string::npos) {
                lock_guard<mutex> lock(mtx);
                cout << "Thread " << threadId << ": " << archivoActual.filename() 
                     << " - Line " << numeroDeLinea << endl;
            }
            ++numeroDeLinea;
        }
    }
}

// Función para imprimir la ayuda
void mostrarAyuda(const string& nombrePrograma) {
    cout << "Uso: " << nombrePrograma << " -t <num_threads> -d <directorio> <cadena_buscar>" << endl;
    cout << "Opciones:" << endl;
    cout << "  -t, --threads <num>     Cantidad de threads a ejecutar concurrentemente" << endl;
    cout << "  -d, --directorio <path> Ruta del directorio a analizar" << endl;
    cout << "  -h, --help              Muestra la ayuda del ejercicio" << endl;
}

bool esNumero(const string& valor) {
    if(valor.empty()) return false;

    for (char digito : valor){
        if(!isdigit(digito)){
            return false;
        }
    }

    return true;
}

 // Validar que se hayan ingresado las banderas requeridas
bool sonBanderasValidas(map<string, string>& argumentos) {

    if (argumentos.find("threads") == argumentos.end()) {
        cerr << "Error: No se especificó la cantidad de threads con -t o --threads.\n";
        return false;
    }
    if (argumentos.find("directorio") == argumentos.end()) {
        cerr << "Error: No se especificó el directorio con -d o --directorio.\n";
        return false;
    }
    if (argumentos.find("cadena") == argumentos.end()) {
        cerr << "Error: No se especificó la cadena a buscar.\n";
        return false;
    }

    return true;
}

bool sonParametrosValidos(int argc, char* argv[], map<string, string>& argumentos) {
    for (int i = 1; i < argc; ++i) {
        string arg = argv[i];
        if (arg == "-t" || arg == "--threads") {
            if (i + 1 < argc && esNumero(argv[i + 1])) {
                argumentos["threads"] = argv[++i];
                if (stoi(argumentos["threads"]) <= 0) {
                    cerr << "El número de threads debe ser un entero positivo." << endl;
                    return false;
                }
            } else {
                cerr << "Debe proporcionar un número de threads positivo después de " << arg << "." << endl;
                return false;
            }
        } else if (arg == "-d" || arg == "--directorio") {
            if (i + 1 < argc) {
                argumentos["directorio"] = argv[++i];
                if (!exists(argumentos["directorio"]) || !is_directory(argumentos["directorio"])) {
                    cerr << "La ruta proporcionada no es un directorio válido." << endl;
                    return false;
                }
            } else {
                cerr << "Debe proporcionar una ruta de directorio después de " << arg << "." << endl;
                return false;
            }
        } else if (arg == "-h" || arg == "--help") {
            mostrarAyuda(argv[0]);
            return false;
        } else {            
            // Se asume que el argumento sin bandera es la cadena a buscar
            if(arg.empty()) {
                cerr << "Debe proporcionar un patrón de búsqueda válido." << endl;
                return false;
            }
            argumentos["cadena"] = arg;
        }
    }

    return true;
}

int main(int argc, char* argv[]) {
    if (argc < 6) {
        mostrarAyuda(argv[0]);
        return 1;
    }

    // Mapa para almacenar los valores de los argumentos
    map<string, string> argumentos;

    if(!sonParametrosValidos(argc, argv, argumentos) || !sonBanderasValidas(argumentos))
        return 1;

    path directorio = argumentos["directorio"];

    // Poner todos los archivos del directorio en la cola de trabajo
    for (const auto& archivo : directory_iterator(directorio)) {
        if (is_regular_file(archivo.path())) {
            archivosAProcesar.push(archivo.path());
        }
    }

    int cantHilos = stoi(argumentos["threads"]);
    
    // Crear e iniciar threads
    vector<thread> hilos;
    for (int i = 0; i < cantHilos; ++i) {
        hilos.emplace_back(buscarEnArchivo, i, ref(argumentos["cadena"]));
    }

    // Esperar a que todos los threads terminen
    for (thread& hilo : hilos) {
        hilo.join();
    }

    return 0;
}