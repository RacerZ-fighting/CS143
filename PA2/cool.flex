/*
 *  The scanner definition for COOL.
 *  Learning from https://github.com/Kiprey/Skr_Learning/blob/master/week3-6/PA2/cool.flex & https://github.com/skyzluo/CS143-Compilers-Stanford/blob/master/PA2/cool.flex
 */

/*
 *  Stuff enclosed in %{ %} in the first section is copied verbatim to the
 *  output, so headers and global definitions are placed here to be visible
 * to the code in the file.  Don't remove anything that was here initially
 */
%{
#include <cool-parse.h>
#include <stringtab.h>
#include <utilities.h>

/* The compiler assumes these identifiers. */
#define yylval cool_yylval
#define yylex  cool_yylex

/* Max size of string constants */
#define MAX_STR_CONST 1025
#define YY_NO_UNPUT   /* keep g++ happy */

extern FILE *fin; /* we read from this file */

/* define YY_INPUT so we read from the FILE fin:
 * This change makes it possible to use this scanner in
 * the Cool compiler.
 */
#undef YY_INPUT
#define YY_INPUT(buf,result,max_size) \
	if ( (result = fread( (char*)buf, sizeof(char), max_size, fin)) < 0) \
		YY_FATAL_ERROR( "read() in flex scanner failed");

char string_buf[MAX_STR_CONST]; /* to assemble string constants */
char *string_buf_ptr;

extern int curr_lineno;
extern int verbose_flag;

extern YYSTYPE cool_yylval;
static int comment_layer = 0; /* to process nested comments */
/*
 *  Add Your own definitions here
 */
/* reset status and return Error */
#define RESET \ 
	BEGIN(0);\
	return ERROR;
	
#define CHK_STR_LEN \ 
	if (string_buf_ptr - string_buf >= MAX_STR_CONST) {\ 
		cool_yylval.error_msg = "String constant too long";\
		char c;\
		while ((c = yyinput()) != '\"' && c != EOF);\
		RESET \			
	}	
%}

/*
 * Define names for regular expressions here.
 */

DARROW          =>
DIGIT		[0-9]

/* keyword */
CLASS		(?i:class)
ELSE		(?i:else)
FI		(?i:fi)
IF		(?i:if)
IN		(?i:in)
INHERITS	(?i:inherits)
ISVOID		(?i:isvoid)
LET		(?i:let)
LOOP		(?i:loop)
POOL		(?i:pool)
THEN		(?i:then)
WHILE		(?i:while)
CASE		(?i:case)
ESAC		(?i:esac)
NEW		(?i:new)
OF		(?i:of)
NOT		(?i:not)
TRUE		t(?i:rue)
FALSE		f(?i:alse)

/* wild card for Identifiers */
INTEGER		{DIGIT}+
LETTER		[a-zA-Z]
ID		({INTEGER}|{LETTER}|_)
TYPEID		[A-Z]{ID}*
OBJID		[a-z]{ID}*
/* special process for char '\n' */
BK		[\ \f\r\t\v]+  
SPENOTION	[\<\=\+/\-\*\,;\:\(\)@\{\}\.~]

/* used for start condition */
%x		COMMENT
%x 		INLINE_COMMENT
%x 		STRING

%%

 /*
  *  Nested comments
  */
<COMMENT,INITIAL>"(*"   {
				++ comment_layer;	
				BEGIN(COMMENT);
			}

<COMMENT>\n		{ ++ curr_lineno; }	/* maybe can modified to be universed! */ 
<COMMENT>. 		{ }
<COMMENT>"*)"		{
				if (-- comment_layer == 0) 	
				 	BEGIN(0);
			}
<COMMENT><<EOF>> 	{	
				cool_yylval.error_msg = "EOF in comment";
				RESET
			}
"*)"			{
				cool_yylval.error_msg = "Unmatched *)";
				RESET
			}
<INITIAL>"--" 		{
				BEGIN(INLINE_COMMENT);
			}
<INLINE_COMMENT><<EOF>>	{
				BEGIN(0);
			}
<INLINE_COMMENT>\n	{
				BEGIN(0);
				++ curr_lineno;		
			}
<INLINE_COMMENT>. 	{  }
 /*
  *  The multiple-character operators.
  */
{DARROW}		{ return (DARROW); }
"<-"			{ return (ASSIGN); }
"<="			{ return (LE);  }

{BK}                 { }
 /*
  * Keywords are case-insensitive except for the values true and false,
  * which must begin with a lower-case letter.
  */

{CLASS}                 { return (CLASS); }
{ELSE}                  { return (ELSE);  }
{FI}                    { return (FI);    }
{IF}                    { return (IF);    }
{IN}                    { return (IN);    }
{INHERITS}              { return (INHERITS); }
{ISVOID}                { return (ISVOID); }
{LET}                   { return (LET);  }
{LOOP}                  { return (LOOP); }
{POOL}                  { return (POOL); }
{THEN}                  { return (THEN); }
{WHILE}                 { return (WHILE);}
{CASE}                  { return (CASE); }
{ESAC}                  { return (ESAC); }
{NEW}                   { return (NEW);  }
{OF}                    { return (OF);   }
{NOT}                   { return (NOT);  }
{TRUE}			{ 
		   	  cool_yylval.boolean = true;
			  return (BOOL_CONST);		
			}
{FALSE}			{
			  cool_yylval.boolean = false;
			  return (BOOL_CONST);
			} 
{SPENOTION}		{ return *yytext; }	/* (ASCII) value of the character itself */
{OBJID}			{
			  cool_yylval.symbol = idtable.add_string(yytext);
			  return (OBJECTID);
			}
{TYPEID}		{
			  cool_yylval.symbol = idtable.add_string(yytext);
			  return (TYPEID);
			}
{INTEGER}		{
			  cool_yylval.symbol = idtable.add_string(yytext);
			  return (INT_CONST);
			} 
 /*
  *  String constants (C syntax)
  *  Escape sequence \c is accepted for all characters c. Except for 
  *  \n \t \b \f, the result is c.
  *
  */
<INITIAL>"\""		{
			  BEGIN(STRING);
		   	  string_buf_ptr = string_buf; 		
			}
<STRING>"\""		{
			  BEGIN(0);
		 	  *string_buf_ptr++ = '\0'; 	 
			  cool_yylval.symbol = idtable.add_string(string_buf);
			  return (STR_CONST); 
			}
<STRING>"\\\n"		{
			  *string_buf_ptr++ = '\n';
			  ++ curr_lineno; 
			  CHK_STR_LEN
			} 
<STRING>\\[^\0]	        {
			  char chr = yytext[1];
			  if (chr == 'b')
			     *string_buf_ptr++ = '\b';
			  else if (chr == 't') 
			     *string_buf_ptr++ = '\t';
			  else if (chr == 'n')
			     *string_buf_ptr++ = '\n';
			  else if (chr == 'f')
			     *string_buf_ptr++ = '\f';
			  else
			     *string_buf_ptr++ = chr;  
			  CHK_STR_LEN
			}
<STRING>"\0"		{
			  cool_yylval.error_msg = "String contains null character";
			  char chr;
			  while ((chr = yyinput()) != '\"' && chr != EOF && chr != '\n'); 
			  RESET;
			}
<STRING><<EOF>> 	{
			  cool_yylval.error_msg = "EOF in string constant";
			  RESET		 
			}
<STRING>\n 		{
			  cool_yylval.error_msg = "Unterminated string constant";
			  ++ curr_lineno;
			  RESET 
			}
<STRING>.		{
			  *string_buf_ptr++ = *yytext;
			  CHK_STR_LEN
			}	 
\n			{  ++ curr_lineno; }
[^\n]			{
			  cool_yylval.error_msg = strdup(yytext);
			  RESET 
			} 
%%
