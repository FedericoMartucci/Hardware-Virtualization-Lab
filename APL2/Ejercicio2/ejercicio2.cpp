#include <iostream>
#include <fstream>
#include <filesystem>
#include <thread>
#include <mutex>
#include <vector>
#include <queue>
#include <string>

// Declaración de espacios de nombres
using namespace std;
using namespace std::filesystem;

// Variables globales para sincronización y manejo de archivos
mutex mtx;
queue<path> files_to_process;

// Función para procesar archivos y buscar la cadena en cada línea
void search_in_file(int thread_id, const string& search_string) {
    while (true) {
        path current_file;

        // Obtener un archivo de la cola de manera segura
        {
            lock_guard<mutex> lock(mtx);
            if (files_to_process.empty()) return; // Si no hay más archivos, salir
            current_file = files_to_process.front();
            files_to_process.pop();
        }

        // Abrir el archivo y buscar la cadena en cada línea
        ifstream file(current_file);
        string line;
        int line_number = 1;
        while (getline(file, line)) {
            if (line.find(search_string) != string::npos) {
                lock_guard<mutex> lock(mtx);
                cout << "Thread " << thread_id << ": " << current_file.filename() 
                     << " - Line " << line_number << ": " << line << endl;
            }
            ++line_number;
        }
    }
}

int main(int argc, char* argv[]) {
    if (argc < 4) {
        cerr << "Uso: " << argv[0] << " -t <num_threads> -d <directorio> <cadena_buscar>\n";
        return 1;
    }

    // Parsear argumentos
    int num_threads = stoi(argv[2]);
    path directory_path = argv[4];
    string search_string = argv[5];

    // Validar el directorio
    if (!exists(directory_path) || !is_directory(directory_path)) {
        cerr << "El directorio proporcionado no es válido.\n";
        return 1;
    }

    // Poner todos los archivos del directorio en la cola de trabajo
    for (const auto& entry : directory_iterator(directory_path)) {
        if (entry.is_regular_file()) {
            files_to_process.push(entry.path());
        }
    }

    // Crear e iniciar threads
    vector<thread> threads;
    for (int i = 0; i < num_threads; ++i) {
        threads.emplace_back(search_in_file, i, ref(search_string));
    }

    // Esperar a que todos los threads terminen
    for (auto& th : threads) {
        th.join();
    }

    return 0;
}
