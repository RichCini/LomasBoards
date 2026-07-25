/*	standard i/o header file for c86
*/

#define NULL 0
#define EOF (-1)	/* standard end of file */
#define EOS '\0'	/* standard end of string */
#define stdin 0x8000	/* standard input */
#define stdout 0x8001	/* standard output */
#define stderr 0x8002	/* standard error */
#define AREAD 0		/* ascii read */
#define AWRITE 1	/* ascii write */
#define AUPDATE 2	/* ascii update (take care with this one) */
#define BREAD 4		/* binary update */
#define BWRITE 5	/* binary write */
#define BUPDATE 6	/* binary update */
typedef char FILE;
#define getchar() fgetc(stdin)
#define getc(x) fgetc(x)
#define putchar(x) fputc(x,stdout)
#define putc(x,y) fputc(x,y)

/*	definition for setjmp and longjmp
*/

typedef int jmp_buf[3];

/*	end of standard header file
*/
#define MAXOP	20
#define NUMBER '0'
#define TOOBIG '9'
#define MAXFUN 17
#define NOFUN  'Z'
main()
{
	int	type;
	char	s[MAXOP];
	double	op2, temp1, temp2, atof(), pop(), push(), pow() ;
	double	sin(), cos(), tan(), asin(), acos(), atan(),sqrt();
	double	exp(), log(),log10(); 

	printf("Simple Desk Calculator\n");
	printf("Functions:\n");
	printf("\t+ = addition\n");
	printf("\t- = subtraction\n");
	printf("\t* = multiplication\n");
	printf("\t/ = division\n");
	printf("\t^ = exponentiation\n");
	printf("\t= = print top of stack\n");
	printf("\tThe following functions are also suported:\n");
	printf("\t\tsin, cos, tan, asin, acos, atan, sqrt, exp, ln,\n");
	printf("\t\tloq, pow, inv, pop, clr, and quit.\n");
	printf("This calculator uses Reverse Polish Notation.\n");
	printf("Example:\n");
	printf("\t3 4 * = <CR>\n");
	printf("\t\t12.000000\n");
	printf("Begin!\n");
	while ((type = getop(s, MAXOP)) != EOF)
		switch (type){

		case 0:
			push (sin(pop()));
			break;
		case 1:
			push (cos(pop()));
			break;
		case 2:
			push (tan(pop()));
			break;
		case 3:
			push (asin(pop()));
			break;
		case 4:
			push (acos(pop()));
			break;
		case 5:
			push (atan(pop()));
			break;
		case 6:
			push (sqrt(pop()));
			break;
		case 7:
			push (exp(pop()));
			break;
		case 8:
			push (log(pop()));
			break;
		case 9:
			push (log10(pop()));
			break;
		case 10:
			temp1=pop();
			temp2= pop();
			push(temp1);
			push(temp2);
			break;
                case 11:
			push (pow( 10.0,pop()));
			break;
		case 12:
			push(1/pop());
			break;
		case 13:
			pop();
			break;
		case 14:
			clear();
			break;
		case 15:	/* store not implemented yet */
			break;
		case 16:	/* exit */
			exit();
		case NUMBER:
			push(atof(s));
			break;
		case '+':
			push(pop() + pop());
			break;
		case '*':
			push(pop() * pop());
			break;
		case '-':
			push(pop() - pop());
			break;
		case '/':
			push(pop() / pop());
			break;
		case '^':	/* st-1 raised to st-1 power */
			temp1= pop(); 
			push(pow(pop(),temp1)); 
			break; 
		case '=':	/* print top of stack */
			printf("\t%f\n",push(pop()));
			break;
                case NOFUN:
			printf("\n unknown function encountered\n");
			break;
		case TOOBIG:
			printf("%.20s ... is too long\n",s);
			break;
		default:
			printf("unknown command %c\n",type);
			break;
		}
}
#define MAXVAL 100

int	sp = 0;
double	val[MAXVAL];

double	push(f)
double	f;
{
	if (sp < MAXVAL)
		return(val[sp++] = f);
	else {
		printf("error: stack full\n");
		clear();
		return (0);
	}
}

double pop()
{
	if (sp > 0 )
		return(val[--sp]);
	else {
		printf("error: stack empty\n");
		clear();
	return (0);
	}
}

clear()
{
	sp=0;
}

getop(s, lim)
char	s[];
int	lim;
{
static char *function[] ={
	"sin",  /* 0 */
	"cos",  /* 1 */
	"tan",  /* 2 */
	"asin", /* 3 */
	"acos", /* 4 */
	"atan", /* 5 */
	"sqrt", /* 6 */
	"exp",  /* 7 */
	"ln",   /* 8 */
	"log",  /* 9 */
	"swap",	/* 10 swap top 2 stack elements */
	"pow",	/* 11- 10^stack top */
	"inv",  /* 12  1/stack top */
	"pop",	/* 13  remove stack top */
	"clr",  /* 14  clear stack */
	"store",  /* 15  store the stack top in the specified register */
	"quit"  /* 16 exit to the os */
	};
	int	i, c;

	while ((c = getch()) == ' ' || c == '\t' || c == '\n')
		;
	if (c != '.' && (c < '0' || c > '9')){
		switch(c){
                case '+':
		case '-':
		case '/':
		case '*':
		case '^':
                case '=':
			return(c);
			break;
		default:
		        s[0] = c;
			for ( i = 1; isalpha(c=getch()); i++)
				s[i]=c;
			s[i]='\0';
			for ( i = 0; i < MAXFUN; i++){
				if ( strcmp(s,function[i])==0)
					return(i);
			}
			return(NOFUN);
		}
	}
	s[0]=c;
	for (i =1; (c = getch()) >= '0' && c <= '9'; i++)
		if ( i < lim)
			s[i]=c;
	if (c == '.') {
		if (i < lim)
			s[i] = c;
		for ( i++; ((c = getch()) >= '0') && (c <= '9'); i++)
			if (i < lim) 
			s[i] = c;
	}
	if (i < lim) {
		ungetch(c);
		s[i] = '\0';
		return(NUMBER);
	} else {
		while ( c != '\n' && c != EOF)
			c = getchar();
		s[lim-1] = '\0';
		return(TOOBIG);
	}
}

#define BUFSIZE 100

char buf[BUFSIZE];
int bufp = 0;

getch()
{
	return((bufp > 0) ? buf[--bufp] : getchar());
}

ungetch(c)
int	c;
{
	if(bufp > BUFSIZE)
		printf("ungetch: too many characters\n");
	else
		buf[bufp++] = c;
}
