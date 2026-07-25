/*

	command format:
		print filename1 filename2

	File 2 may be the printer by specifying PRN:
	This program takes a source program and performs tab
	expansion, pagination, and margin offset.
        REV 1.0

*/
#define ERROR -1
#define CPMEOF 0x1a	/* CP/M End-of-text-file marker (sometimes!)  */
#include "stdio.h"

	int column, ifd, ofd, i, c, lcount;
	int lines, tmargin, lmargin;

main(argc,argv)
char **argv;
{
	if (argc != 3) {
		printf("usage: print filename1 filename2\n");
		printf("EXAMPLES:\n");
		printf("PRINT TEST.A86 PRN:\n");
		printf("PRINT TEST.A86 TEST.PRN\n");
		printf("PRINT TEST.A86 CON:\n");
		exit();
	}
	printf("PRINT file processor Rev 1.00\n");
	ifd = fopen(argv[1],"rb");
	ofd = fopen(argv[2],"wb");
	if (ifd == 0) {
		printf("Can't open the read file\n");
		exit();
	}
	if (ofd == 0 ) {
		printf("Can't open the write file\n");
		exit();
	}
	printf("Enter top margin: ");
	scanf("%d",&tmargin);
	printf("Enter left margin: ");
	scanf("%d",&lmargin);
	printf("Enter number of print lines per page: ");
	scanf("%d",&lines);
	printf("The input file is now being processed.\n");
	lcount = column = 0;
	putc('\f',ofd);
	putc('\r',ofd);
	for ( i = tmargin ; i > 0 ; i--) {
		putc('\n',ofd);
	}
	for ( i = lmargin ; i > 0 ; i--) {
		putc(' ',ofd);
	}

	do {
		c = getc(ifd);
		if (c == ERROR) {
			putc(0x0c,ofd); /* output formfeed at end of file */
			putc(CPMEOF,ofd); /* also eof incase disk file */
			break;
		 }
		switch(c) {
		   case '\r':	putc(c,ofd);
				column = 0;
				break;
		   case '\n':	putc(c,ofd);
				lcount++;
				if( lcount > lines ){
					putc('\f',ofd);
					for ( i = tmargin ; i > 0 ; i-- ){
						putc('\n',ofd); 
					}
					lcount = 0;
				}
				if (column < lmargin){
				   for(i = lmargin - column; i > 0 ; i-- ) {
						putc(' ',ofd);
				   }
				}
				break;
		   case '\f':	putc(c,ofd);
				putc('\r',ofd);
				column = 0;
				for ( i = tmargin; i > 0 ; i--){
					putc('\n',ofd);
				}

				for ( i = lmargin ; i > 0 ; i-- ){
					putc(' ',ofd);
				}
				lcount = 0;
				break;
		   case '\t':	for ( i =(8-( column % 8)); i > 0 ; i--){ 
					putc(' ',ofd); 
					column++; 
					} 
				break;
		   case 0x1a:	putc(CPMEOF,ofd);
				break;
		   default:	putc(c,ofd);
				column++;
		 }
	 } while (c != CPMEOF);

	fflush(ofd);
	fclose(ifd);
	fclose(ofd);
}
 
