CC = gcc
CFLAGS = -g -O2 -I/usr/local/include -I/usr/local/lib
LFLAGS = -lcrypto

all: aquaticprime

aquaticprime: ${OBJS}
	${CC} ${CFLAGS} AquaticPrimeCLI.c ${LFLAGS} -o aquaticprime

install: aquaticprime
	cp aquaticprime /usr/local/bin/

clean:
	rm aquaticprime