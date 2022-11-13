%{
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define TRUE 1
#define FALSE 0

extern FILE *yyin;
extern FILE *yyout;

int yyparse();
int yyerror(const char *s);

char *g_name_of_file;

extern int yylex();

unsigned int g_line_amt = 1;            
unsigned int g_cond_amt = 0;            //для подсчёта вложенных условных конструкций
unsigned int g_if_in_trgt = FALSE;   


inline static void CheckCurState();

void ToggleCurState(unsigned int new_state) { g_if_in_trgt = new_state;}

void ErrorMsg(const char* error_type, const char* error_cause, int line_number);

%}
%define parse.error verbose

%union 
{
        char *str;
        int digit;
}


%token COMMAND RUN_COMMAND CONT_COMMAND SHELL_COMMAND
%token VAR_DEFINITION TEMPLATE TEMPLATE_TRGT SFX_TRGT 

%token EOL
%token SPECIAL T1
%token IF IFNEQ IFEQ 
%token ELSE IFDEF IFNDEF ENDEF ENDIF
%token INCLUDE DEFINE EXPORT ERROR FUNCTION

%token <str> PATH
%token <str> CHARS
%token <str> VAR_AUT
%token <str> UNIT_NAME
%token <str> NAME_OF_FILE

%start input



%%

input: 
      line
    | input line                    //стартовая строка
    ;

line: EOL                          
    //отлов возможных ошибок
    | unit EOL                     { ErrorMsg("alone unit","", g_line_amt-1);}
    | CHARS EOL                    { ErrorMsg("alone unit","", g_line_amt-1);}
    | SHELL_COMMAND EOL            { ErrorMsg("alone unit","", g_line_amt-1);}
                                    //
    | command_seq                  { CheckCurState();}
    | variable                     { ToggleCurState(FALSE);}              
    | target                       { ToggleCurState(TRUE);}
    | condition                 
    | include                       //включение нового make-файла
    | define                        //именованная командная последовательность
    | ERROR
    ;


variable: 
      variable_name VAR_DEFINITION EOL                   //объявление переменной: имя = последовательность_символов
    | variable_name VAR_DEFINITION variable_units EOL   //для экспорта переменных верхнего уровня на нижний
    | EXPORT UNIT_NAME EOL
    | EXPORT variable
    ;

variable_name: 
      UNIT_NAME                    
    | VAR_AUT                                         { ErrorMsg("auto var",(const char*)$1, g_line_amt);}
    | PATH	                                          { ErrorMsg("path var",(const char*)$1, g_line_amt);}
    | NAME_OF_FILE                                    { ErrorMsg("filename var",(const char*)$1, g_line_amt);}
    ;

variable_units: 
      UNIT_NAME                                       //может быть как один объект, так и лист объектов
    | CHARS
    | PATH
    | NAME_OF_FILE
    |'(' variable_units ')'
    |'{' variable_units '}' 
    | variable_unit
    | variable_units variable_unit
    | variable_units UNIT_NAME
    | variable_units CHARS
    | variable_units PATH
    | variable_units NAME_OF_FILE
    | variable_units '(' variable_units ')'
    | variable_units '{' variable_units '}'
    | variable_units ',' variable_units
    ;
    
variable_unit: 
      VAR_DEFINITION
    | FUNCTION
    | SHELL_COMMAND
    | variable_unit_spec  
    | variable_value
    | VAR_AUT                                         { ErrorMsg("auto var",(const char*)$1, g_line_amt);}
    ;

variable_unit_spec: 
      ':'
    | '|'    
    | '+'
    | '/'
    | '-'  
    | '&'
    | ';'
    | '['
    | ']'
    | '<'
    | '>'
    ;

//ссылка на переменную
variable_value: 
      '$' UNIT_NAME                                        
    | '$' '$' UNIT_NAME                             
    | '$' CHARS                                     { ErrorMsg("string var",(const char*)$2, g_line_amt);   }
    | '$' PATH                                      { ErrorMsg("path var",(const char*)$2, g_line_amt);     }
    | '$' '$' PATH                                  { ErrorMsg("path var",(const char*)$3, g_line_amt);     }
    | '$' '$' CHARS                                 { ErrorMsg("string var",(const char*)$3, g_line_amt);   }
    | '$' '(' PATH ')'                              { ErrorMsg("path var",(const char*)$3, g_line_amt);     }
    | '$' '{' PATH '}'                              { ErrorMsg("path var",(const char*)$3, g_line_amt);     }
    | '$' '(' CHARS ')'                             { ErrorMsg("string var",(const char*)$3, g_line_amt);   }
    | '$' '{' CHARS '}'                             { ErrorMsg("string var",(const char*)$3, g_line_amt);   }
    | '$' NAME_OF_FILE                              { ErrorMsg("filename var",(const char*)$2, g_line_amt); }
    | '$' '$' NAME_OF_FILE                          { ErrorMsg("filename var",(const char*)$3, g_line_amt); }
    | '$' '(' UNIT_NAME  ')'                        
    | '$' '{' UNIT_NAME  '}'                        
    | '$' '{' NAME_OF_FILE '}'                      { ErrorMsg("filename var",(const char*)$3, g_line_amt); }
    | '$' '(' NAME_OF_FILE ')'                      { ErrorMsg("filename var",(const char*)$3, g_line_amt); }
    | '$' '(' variable_unit ')'
    | '$' '{' variable_unit '}'
    | '$' '$' '(' variable_units ')'                                 //переменные записываются в скрипте как `$(foo)' или `${foo}'
    | '$' '$' '(' variable_units ')' '/'
    | '$' '$' '{' variable_units '}'
    | '$' '(' UNIT_NAME  ':' subst VAR_DEFINITION subst ')'         //Ссылка с заменой (substitution reference)
    | '$' '{' UNIT_NAME  ':' subst VAR_DEFINITION subst '}'         //Синтаксис `$(переменная:a=b)' (или `${переменная:a=b}')
    | '$' '(' variable_unit  ':' subst VAR_DEFINITION subst ')'     //должно быть взято значение переменной переменная, и каждая найденная в нем цепочка символов a, 
    | '$' '{' variable_unit  ':' subst VAR_DEFINITION subst '}'     //находящаяся в конце слова, должна быть заменена на цепочку символов b
    | variable_value '/' variable_value
    | variable_value '/' template
    ;


    subst: 
      UNIT_NAME
    | NAME_OF_FILE
    ;


//правила для цели//

/*
    В общем виде, правило выглядит так:

    цели : пререквизиты
            команда
            ...
    или так:

    цели : пререквизиты ; команда
            команда
            ...
*/


target: 
      target_spec prerequisite EOL       
    | target_spec prerequisite ';' units EOL
    | target_spec prerequisite ';' EOL
    ;

target_spec:
      target_names ':'
    | target_names ':'':' 
    | SFX_TRGT ':'
    | SPECIAL ':'
    ;

target_names: 
      target_names target_name
    | target_name
    ;

target_name: 
      UNIT_NAME  { }
    | PATH
    | NAME_OF_FILE
    | TEMPLATE_TRGT
    | template
    | VAR_AUT                                       { ErrorMsg("auto var",(const char*)$1, g_line_amt);}
    | variable_value
    ;


//правила для пререквизитов//

prerequisite:
    | prerequisite_units 
    | '|' prerequisite_units
    | prerequisite_units '|' prerequisite_units
    | prerequisite_units  VAR_DEFINITION prerequisite_units     
    ;

prerequisite_units: 
      prerequisite_unit
    | prerequisite_units prerequisite_unit
    ;

prerequisite_unit: 
      UNIT_NAME 
    | PATH
    | NAME_OF_FILE
    | FUNCTION
    | template
    | VAR_AUT                                       { ErrorMsg("auto var", (const char*)$1, g_line_amt);}
    | variable_value
    | SPECIAL
    ;

template: 
         TEMPLATE
    | '('TEMPLATE')'
    ;


//правило для команд, которые идут после пререквизитов

command_seq: 
      cmd EOL     
    | cmd units EOL
    | cmd_cont EOL
    ;

cmd_cont: 
      CONT_COMMAND
    | cmd_cont CONT_COMMAND
    | cmd_cont cmd
    ;
cmd: 
      COMMAND
    | RUN_COMMAND
    ;


//правила для условий//

/*
условная-директива
фрагмент-для-выполненного-условия
endif

условная-директива
фрагмент-для-выполненного-условия
else
фрагмент-для-невыполненного-условия
endif

возможные варианты для условия

ifeq (параметр1, параметр2)
ifeq 'параметр1' 'параметр2'
ifeq "параметр1" "параметр2"
ifeq "параметр1" 'параметр2'
ifeq 'параметр1' "параметр2"

*/


condition: 
      if '(' cond ',' cond ')' EOL
    | if '(' ',' cond ')' EOL
    | if '(' cond ',' ')' EOL
    | if '(' ',' ')' EOL
    | if CHARS CHARS EOL
    | if T1 '(' CHARS ')' EOL
    | if T1 '(' variable_value ')'  EOL
    | if units '(' units ')' EOL
    | if '!' T1 '(' CHARS ')' EOL
    | if '!' T1 '(' units ')' EOL
    | if '!' T1 '(' CHARS ')' '|' '|' T1 '(' CHARS ')' EOL
    | if '!' T1 '(' units ')' '|' '|' T1 '(' units ')' EOL
    | if '(' SHELL_COMMAND ',' ')' EOL
    | ifdef unit EOL 
    | ELSE		                                  { if(!g_cond_amt) yyerror("else without ifeq/ifdef statement");}
    | ENDIF                                     { if(!g_cond_amt) yyerror("endif without ifeq/ifdef statement"); else --g_cond_amt;}
    ;

if: 
    IF                                          { ++g_cond_amt;}
    | IFEQ                                      { ++g_cond_amt;}
    | IFNEQ                                     { ++g_cond_amt;}
    ;

ifdef: 
      IFDEF                                     { ++g_cond_amt; } 
    | IFNDEF                                    { ++g_cond_amt; }
    ;

cond: 
      unit
    | CHARS
    | FUNCTION
    ;


//правила для многострочных переменных//

define: DEFINE UNIT_NAME EOL def_cmds ENDEF EOL
    ;

def_cmds: 
      def_cmd
    | def_cmds def_cmd 
    ;

def_cmd: 
      def_cmd_spec 
    | VAR_DEFINITION
    | SHELL_COMMAND
    | NAME_OF_FILE
    | variable_value
    | UNIT_NAME
    | FUNCTION
    | VAR_AUT  
    | PATH
    | CHARS
    | EOL   
    ;

def_cmd_spec: 
      ':'
    | '|'    
    | '+'
    | '/'
    | '-'  
    | '&'
    | ';'
    | '['
    | ']'
    | '<'
    | '>'
    | '!'
    ;
    

//для включений других make-файлов//


include: 
    INCLUDE filenames
    | INCLUDE FUNCTION

filenames: 
    NAME_OF_FILE
    | '<' NAME_OF_FILE '>'    
    | UNIT_NAME
    | PATH
    | variable_value
    ;

units: 
      unit
    | units unit
    ;

unit: 
      UNIT_NAME
    | PATH
    | NAME_OF_FILE
    | VAR_AUT
    | variable_value
    ;

%%


inline void CheckCurState()
{
    if(g_if_in_trgt == FALSE)
      ErrorMsg("unmatched command sequence", "", g_line_amt-1);
}


void ErrorMsg(const char* error_type, const char* error_cause, int line_number)
{
    printf("\nLine %u: ", line_number);
    printf("\033[35mwarning");
    printf("\033[0m: %s ", error_type);
    if (strcmp(error_cause, "") > 0)
        printf("\033[35m%s\033[0m", error_cause);
}


int yyerror(const char *s)
{  
    fprintf(stderr, "\nLine %u: ", g_line_amt);
    fprintf(stderr, "\033[31merror");
    fprintf(stderr, "\033[0m: %s", s);
    fprintf(stderr, "\nProgram finished analysis\n");
    exit(0);
}


int main(int argc, char **argv)
{
  if (argc > 1)
  {
    if(!(yyin = fopen(argv[1], "r")))
    {
      perror(argv[1]);
      return (1);
    }
  }

  g_name_of_file = argv[1];
  yyparse();
  printf("\nProgram finished analysis\n");
  return 0;
}