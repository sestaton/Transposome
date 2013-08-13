#!/bin/bash

CC=g++
CFLAGS= -ansi -O5 -Wall
LDFLAGS= -ansi -lm -Wall
EXEC=louvain_community louvain_convert louvain_hierarchy
OBJ1= graph_binary.o community.o
OBJ2= graph.o

all: $(EXEC)

louvain_community : $(OBJ1) main_community.o
	$(CC) -o $@ $^ $(LDFLAGS)

louvain_convert : $(OBJ2) main_convert.o
	$(CC) -o $@ $^ $(LDFLAGS)

louvain_hierarchy : main_hierarchy.o
	$(CC) -o $@ $^ $(LDFLAGS)

##########################################
# Generic rules
##########################################

%.o: %.cpp %.h
	$(CC) -o $@ -c $< $(CFLAGS)

%.o: %.cpp
	$(CC) -o $@ -c $< $(CFLAGS)

clean:
	rm -f *.o *~ $(EXEC)
