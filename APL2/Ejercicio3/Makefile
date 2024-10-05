# Nombre del compilador
COMPILER = g++

# Flags de compilación
COMPILER_FLAGS = -std=c++17 -Wall 

# Archivos fuente y ejecutables
DAEMON_SRC = daemon.cpp
LECTOR_SRC = lector.cpp
DAEMON_EXEC = daemon.exe
LECTOR_EXEC = lector.exe

# Regla para compilar los ejecutables
all: $(DAEMON_EXEC) $(LECTOR_EXEC)

# Regla para compilar el ejecutable del daemon a partir del archivo fuente
$(DAEMON_EXEC): $(DAEMON_SRC)
	$(COMPILER) $(COMPILER_FLAGS) -o $(DAEMON_EXEC) $(DAEMON_SRC)

# Regla para compilar el ejecutable del lector a partir del archivo fuente
$(LECTOR_EXEC): $(LECTOR_SRC)
	$(COMPILER) $(COMPILER_FLAGS) -o $(LECTOR_EXEC) $(LECTOR_SRC)

# Regla para limpiar archivos generados
clean:
	rm -f $(DAEMON_EXEC) $(LECTOR_EXEC)

# Regla para limpiar y recompilar todo
rebuild: clean all
