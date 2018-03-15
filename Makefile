CC=gcc

TARGET=ipv4_locals

all: $(TARGET)

$(TARGET): $(TARGET).c
	$(CC) -o $(TARGET) $(TARGET).c

clean:
	$(RM) $(TARGET)