CXXFLAGS = -Wall -Wextra -Wshadow -O2
LINK.o = $(LINK.cc)
LDFLAGS = -lrt -lfftw3f

main: main.o channel.o coroutines.o ephemeris.o LiquidCrystal.o main.o peri.o search.o solve.o spi.o user.o

clean:
	rm -f *.o main
