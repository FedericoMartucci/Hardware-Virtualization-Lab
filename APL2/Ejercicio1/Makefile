# Nombre del compilador
COMPILER = g++

# Flags de compilación
COMPILER_FLAGS = -std=c++17 -Wall -pthread

# Archivos fuente y ejecutable
SRC = ejercicio1.cpp
EXEC = ejercicio1.exe

# Regla para compilar el ejecutable
all: $(EXEC)

# Regla para compilar el ejecutable a partir del archivo fuente
$(EXEC): $(SRC)
	$(COMPILER) $(COMPILER_FLAGS) -o $(EXEC) $(SRC)

# Regla para limpiar archivos generados
clean:
	rm -f $(EXEC)

# Regla para limpiar y recompilar todo
rebuild: clean all
