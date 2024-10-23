FROM ubuntu:24.10


RUN apt-get update && \
    apt-get install -y g++ make && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Copias todo el contenido actual a /apl que sera lo que se encuentre en el cont
COPY . /apl

# le decis que justamente vas a trabajar en ese path en el contenedor
WORKDIR /apl

# Compilar cada ejercicio
RUN make -C ./Ejercicio1 && \
    make -C ./Ejercicio2 && \
    make -C ./Ejercicio3 && \
    make -C ./Ejercicio4 && \
    make -C ./Ejercicio5

# comando por defecto 
CMD ["bash"]
