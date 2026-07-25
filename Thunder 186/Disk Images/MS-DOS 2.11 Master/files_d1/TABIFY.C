/*
	Tabify
	written by Leor Zolman

	command format:
		tabify filename new_filename

	This program takes a text file and converts sequences
	of spaces into tabs wherever possible.

	Revised 2/1/81 to process "scount" when encountering
	an opening '"'; Ward C.
*/
#define ERROR -1
#include "bdscio.h"
#include "stdio.h"
	int scount, column, ifd, ofd, i, c;
main(argc,argv)
char **argv;
{
	if (argc != 3) {
		printf("usage: tabify oldfile newfile\n");
		exit();
	}
	ifd = fopen(argv[1],"rb");
	ofd = fopen(argv[2],"wb");
	if (ifd == 0 || ofd == 0) {
		printf("Can't open file(s)\n");
		exit();
	}

	scount = column = 0;

	do {
		c = getc(ifd);
		if (c == ERROR) {
			putc(CPMEOF,ofd);
			break;
		 }
		switch(c) {
		   case '\r':	putc1(c,ofd);
				scount = column = 0;
				break;
		   case '\n':	putc1(c,ofd);
				scount = 0;
				break;
		   case ' ':	column++;
				scount++;
				if (!(column%8)) {
				   if (scount > 1)
					putc1('\t',ofd);
				   else
					putc1(' ',ofd);
					scount = 0;
				 }
				break;
		   case '\t':	scount = 0;
				column += (8-column%8);
				putc1('\t',ofd);
				break;
		   case '"':	outspc('"');
				do {
				   c = getc(ifd);
				   if (c == 0) {
				    printf("Quote error.\n");
				    exit();
				   }
				   putc1(c,ofd);
				} while (c != '"');
				do {
					c = getc(ifd);
					putc1(c,ofd);
				} while (c != '\n');
				column = scount = 0;
				break;
		   case 0x1a:	putc(CPMEOF,ofd);
				break;
		   default:	outspc(c);
				column++;
		 }
	 } while (c != CPMEOF);

	fflush(ofd);
	fclose(ifd);
	fclose(ofd);
}

outspc(c)	/* output any stored spaces */
char c;
{	for (i=0; i<scount; i++)
		putc1(' ',ofd);
	scount = 0;
	putc1(c,ofd);
}

putc1(c,buf)
char c;
{
	putchar(c);
	if (putc(c,buf) == EOF ) {
		printf("putc just retured an error!\n");
		exit();
	}
}

		   case ' ':	