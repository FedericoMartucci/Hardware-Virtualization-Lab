COMPILER = g++

COMPILER_FLAGS = -std=c++17 -Wall
LIBS = -lpthread

CLIENT_SRC = Cliente.cpp
SERVER_SRC = Servidor.cpp
CLIENT_EXEC = Cliente.exe
SERVER_EXEC = Servidor.exe

all: $(CLIENT_EXEC) $(SERVER_EXEC)

$(CLIENT_EXEC): $(CLIENT_SRC)
	$(COMPILER) $(COMPILER_FLAGS) -o $(CLIENT_EXEC) $(CLIENT_SRC) $(LIBS)

$(SERVER_EXEC): $(SERVER_SRC)
	$(COMPILER) $(COMPILER_FLAGS) -o $(SERVER_EXEC) $(SERVER_SRC) $(LIBS)

clean:
	rm -f $(CLIENT_EXEC) $(SERVER_EXEC)

rebuild: clean all
