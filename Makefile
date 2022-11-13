TARGET = analyzer

all:
	bison -d mk.y
	lex mk.l  
	cc lex.yy.c mk.tab.c -o $(TARGET) -lfl

clean:
	rm lex.yy.c mk.tab.c mk.tab.h
	rm -f $(TARGET)