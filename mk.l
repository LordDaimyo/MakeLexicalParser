%{
#include "mk.tab.h"

extern unsigned int g_line_amt;
extern int yyerror(const char *);
unsigned int cont = 0;
extern char* g_name_of_file;
static void UpdateLine();
static void HandleFunction();
%}

DIGIT [0-9]
UNIT_NAME [_a-zA-Z\*\-\+\@\\]

RUN_CMD ^(\@[^\@]*\@)?\t\.\/[^\n]*          
CMD_S ^(\@[^\@]*\@)?\t[^\n]*
%%


{RUN_CMD}                        { return RUN_COMMAND;}
{CMD_S}                          { return COMMAND;}
{RUN_CMD}(\\\n[ \t]*[^\n]*)*     { UpdateLine(); return RUN_COMMAND;}
{CMD_S}(\\\n[ \t]*[^\n]*)*       { UpdateLine(); return COMMAND;}

"#"[^\n]*   {}

"("         { return '('; }
")"         { return ')'; }
"{"         { return '{'; }
"$"         { return '$'; }
"]"         { return ']'; }
"["         { return '['; }
"-"         { return '-'; }
"+"         { return '+'; }
"\""        { return '"'; }
"|"         { return '|'; }
";"         { return ';'; }
"/"         { return '/'; }
"&"         { return '&'; }
"<"         { return '<'; }
"}"         { return '}'; }
","         { return ','; }           
"?"         { return '?'; }
"!"         { return '!'; }
":"         { return ':'; }
">"         { return '>'; }
"`"         { return '`'; }
\'          { return '\''; }
\n          { ++g_line_amt; cont = 0; return EOL;}
[ \t]+\n    { ++g_line_amt; cont = 0; return EOL;}
"@"         {  }
"if"        { return IF;}
"else"      { return ELSE;}
".if"       { return IF;}
".else"     { return ELSE;}
^"endef"    { return ENDEF;}
"ifeq"      { return IFEQ;}
"endif"     { return ENDIF;}
"ifneq"     { return IFNEQ;}
"ifdef"     { return IFDEF;}
"ifndef"    { return IFNDEF;}
^"define"   { return DEFINE;}
^"export"   { return EXPORT;}
^"include"  { return INCLUDE;}
^"-include" { return INCLUDE;}
^".include" { return INCLUDE;}
"override"  { }
<<EOF>>     { static int once = 0; return once++ ? 0 : EOL;}
  

".PHONY"|".SUFFIXES"|".DEFAULT"|".PRECIOUS"|".INTERMEDIATE"|".SECONDARY"|".DELETE_ON_ERROR"|".IGNORE"|".SILENT"|".EXPORT_ALL_VARIABLES"|".NOTPARALLEL"    { return SPECIAL; }


$\("abspath"    { HandleFunction();return FUNCTION;}
$\("addsuffix"  { HandleFunction();return FUNCTION;}
$\("addprefix"  { HandleFunction();return FUNCTION;}
$\("and"        { HandleFunction();return FUNCTION;}
$\("basename"   { HandleFunction();return FUNCTION;}
$\("call"       { HandleFunction();return FUNCTION;}
$\("dir"        { HandleFunction();return FUNCTION;}
$\("eval"       { HandleFunction();return FUNCTION;}
$\("error"      { HandleFunction();return ERROR;   }
$\("file"       { HandleFunction();return FUNCTION;}
$\("firstword"  { HandleFunction();return FUNCTION;}
$\("findstring" { HandleFunction();return FUNCTION;}
$\("foreach"    { HandleFunction();return FUNCTION;}
$\("filter"     { HandleFunction();return FUNCTION;}
$\("filter-out" { HandleFunction();return FUNCTION;}
$\("flavour"    { HandleFunction();return FUNCTION;}
$\("if"         { HandleFunction();return FUNCTION;}
$\("join"       { HandleFunction();return FUNCTION;}
$\("notdir"     { HandleFunction();return FUNCTION;}
$\("or"         { HandleFunction();return FUNCTION;}
$\("origin"     { HandleFunction();return FUNCTION;}
$\("patsubst"   { HandleFunction();return FUNCTION;}
$\("realpath"   { HandleFunction();return FUNCTION;}
$\("sort"       { HandleFunction();return FUNCTION;}
$\("strip"      { HandleFunction();return FUNCTION;}
$\("suffix"     { HandleFunction();return FUNCTION;}
$\("subst"      { HandleFunction();return FUNCTION;}
$\("value"      { HandleFunction();return FUNCTION;}
$\("wordlist"   { HandleFunction();return FUNCTION;}
$\("wildcard"   { HandleFunction();return FUNCTION;}
$\("word"       { HandleFunction();return FUNCTION;}

^"%"({UNIT_NAME}|{DIGIT}|[\.]|[//])*                                        { return TEMPLATE_TRGT;}
^"."({UNIT_NAME}|{DIGIT})*"."({UNIT_NAME}|{DIGIT})+                         { return SFX_TRGT;}


\"[^\"]*\"                                                                  { yylval.str = strdup(yytext); return CHARS; }
\'[^\']*\'                                                                  { yylval.str = strdup(yytext); return CHARS; }

\`[^\`]*\`                                                                  { return SHELL_COMMAND; }
$\(shell.*\)                                                                { return SHELL_COMMAND; }
$\(warning.*\)                                                              { return SHELL_COMMAND; }
"defined"                                                                   { return T1; }
"exist"                                                                     { return T1; }
"empty"                                                                     { return T1; }
"target"                                                                    { return T1; }

"::="|"="                                                                   { return VAR_DEFINITION; }
[":"|"!"|"?"|"+"]"="                                                        { return VAR_DEFINITION; }

$("@"|"%"|"<"|"?"|"^"|"+"|"*")                                              { yylval.str = strdup(yytext);return VAR_AUT; }



\%({UNIT_NAME}|{DIGIT}|[\.])*                                               { return TEMPLATE;}

\\[\r]?\n[ \t]*                                                             { ++g_line_amt;}

({UNIT_NAME}|{DIGIT})+                                                      { yylval.str = strdup(yytext); return UNIT_NAME; }


({UNIT_NAME}|{DIGIT}|[\.])+                                                 { yylval.str = strdup(yytext); return NAME_OF_FILE; }
(\/|[\.\.]|[\.])?(({UNIT_NAME}|{DIGIT}|[\.]|[\.\.])+[\/]?)+([\/]|[\/\*])?   { yylval.str = strdup(yytext); return PATH; }

[ \t\f\v\r]
.                                                                           { printf("Unrecognized symbol: %c\n",yytext[0]);yyerror("lexical error"); exit(0); }

%%

static void HandleFunction()
{
    int c = 0; 
    int sc_count = 1; 
    int prev = 0;
    while((c=input())) 
    { 
        switch (c)
        {
            case ')': 
            { 
                if(--sc_count == 0) 
                    return;
                break;
            }
            case '(':
            { 
                ++sc_count;
                break;
            }
            case '\n':
            {
                if (prev == '\\')
                {
                    ++g_line_amt;
                    break;
                }
                else
                    yyerror("!syntax function error");                
            }
            default: prev = c; break;
        }
    }
}


static void UpdateLine()
{
    char str[256];
    memset(str,0,256);
    snprintf(str,256,"sed -n \'%u,$ p\' %s | grep \'[^\\\\$]*[^\\\\]$\' -m1 -n | cut -d : -f 1", g_line_amt, g_name_of_file);
    FILE *f = popen(str, "r");
    if (!feof(f)) {
         if(fgets(str,256,f) != NULL)
         {
            g_line_amt += atoi(str);
            --g_line_amt;
         }
    }
    pclose(f);
}

int yywrap()
{
    return 1;
}
