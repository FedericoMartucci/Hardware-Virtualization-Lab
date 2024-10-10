COMPILER = g++

COMPILER_FLAGS = -std=c++17 -Wall 

DAEMON_SRC = daemon.cpp
LECTOR_SRC = lector.cpp
DAEMON_EXEC = daemon.exe
LECTOR_EXEC = lector.exe


all: $(DAEMON_EXEC) $(LECTOR_EXEC)


$(DAEMON_EXEC): $(DAEMON_SRC)
	$(COMPILER) $(COMPILER_FLAGS) -o $(DAEMON_EXEC) $(DAEMON_SRC)


$(LECTOR_EXEC): $(LECTOR_SRC)
	$(COMPILER) $(COMPILER_FLAGS) -o $(LECTOR_EXEC) $(LECTOR_SRC)


clean:
	rm -f $(DAEMON_EXEC) $(LECTOR_EXEC) 


rebuild: clean all
