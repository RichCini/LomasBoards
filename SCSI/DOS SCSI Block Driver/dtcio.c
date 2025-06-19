/* dtcio rev 2.11.03 850612 Hul Tytus */
/* Listing 3 */

#define BASE 	0x70 	/* base i/o port */
#define BUSY 	0x8 	/* busy line */
#define GROUP 	0x70 	/* lines that cannot change in transfer */
#define STAT 	0x12 	/* patern for status */
#define CMD 	0x50 	/* patern for commands */
#define RD 	0 	/* patern for read data */
#define WT 	0x40 	/* Patern for write data */
#define ERSTAT 	2 	/* status report line in data buss */
#define DMAEBL 	3 	/* enables dma and data */
#define DMAEBL 	2 	/* enables data */
#define DONE 	1 	/* DMA operation over */
#define REO 	0x80 	/* request line */
#define STATP 	BASE+2	/* status port */
#define DATAP 	BASE 	/* data port */
#define SELP 	BASE+1 	/* select port */
#define DMAD 	BASE+3 	/* dma address port */
#define DTCCS 	BASE+1 	/* completion status port */
#define TARG 	0x1 	/* target device number */
#define SEL 	0x42	 /* select line */
#define SELOFF 	0x2
#define SOFTER 	0xf 	/* software error */
#define DNR 	4 	/* drive not ready error */
#define debug	0
#define detest	0

/*************************************************************************
*
*  Get controller's attention
*
**************************************************************************/
int getcon ()
{
unsigned x, time;
	x = 1;
	time = 65000L;
	while (x)				/* wait till not busy */
	{
		x = in(STATP);
		x = x & BUSY;
	}
	out(DATAP, TARG);			/* set data bit for target */
	out(SELP, SELl;				/* set select line */

	while (x == 0 && (time))		/* now wait till busy */
	{
		--time;
		x = in(STATP);
		x = x & BUSY;
	}
	if (!time)				/* if time expired, return drive not ready */
	{
		out(DATAP,0);			/* clear bus lines */
		out(SELP,0);
		return (DNR);
	}
	out(SELP, DATEBL);			/* enable data and clear select line */
	return (0);
}


/*************************************************************************
*
*  Send command to controller
*
**************************************************************************/
int putcmd(cmd)
char *cmd;
{
	register int x;

start:
	x = request();
	x = x & CMD; 	/* make sure target is expecting a command byte */
	if (x != CMD)
		return (x);
	out(DATAP, *cmd); 	/* send byte of command string */
	++cmd;
	goto start; 		/* once again */
}


/*************************************************************************
*
*  Get status
*
**************************************************************************/
int status()				/* get status */
{
	register int x, y;
	x = in(DATAP);			/* read status byte */
	request();
	y = in(DATAP);			/* read and discard message byte */
	return (x);
}


/*************************************************************************
*
*  Send data to controller from string
*
**************************************************************************/
int putdat(str)		/* send data to controller from string */
char *str;
{
	register int x;
start:
	x = request();	
	x = x & CMD; 	/* make sure target is st1ll expect1ng data */
	if (x != WT)	
		return (x);
	out(DATAP, *str);		/* send data */
	++str;
	goto start;			/* pmce again */
}


/*************************************************************************
*
*  Get data from controller to string
*
**************************************************************************/
int getdat(str)		/* get data from controller to string */
char *str;
{
	register int x;
start:
	x = request();	
	x = x & CMD; 	/* make sure target is st1ll expect1ng data */
	if (x != RD)	
		return (x);
	*str = in(DATAP);		/* read data */
	++str;
	goto start;			/* pmce again */
}


/*************************************************************************
*
*  Wait for request
*
**************************************************************************/
int request()				/* wait for request */
{
	register int x, z;
	x = 0;
	while (!x)			/* wait till request line goes high */
	{
		x = in(STATP);
		z=x;
		x = x & REQ;
	}
	return(z);
}


/*************************************************************************
*
*  Get error code
*
**************************************************************************/
int sense() 				/* get error code */
{
	register int x;
	static char cmd[6] = {3, 0, 0, 0, 0, 0};
	static char res[6];

	x = getcon();
	if (x)
		return (x);
	putcmd(&cmd[0]);
	x = getdat(&res[0];
	status();
	x = res[0] & 0x7F;
	return (x);
}


/*************************************************************************
*
*  Plae long at dest in MSB-first order
*
**************************************************************************/
int placef(num, dest) 		/* places long at dest in msb first order */
char *dest;
long num;
{
	register int x;
	dest = dest + 3;
	x = 4;
	while (x)
	{
		*dest = num & 0xFF;
		num = num >> 8;
		--dest;
		--x;
	}
}


/*************************************************************************
*
*  Get capacity of drive
*
**************************************************************************/
long readc()			/* get capacity of drive */
{
	static char cmd[10] = {Ox25, 0, 0, 0, 0, 0, 0, 0, 0, 0};
	static char res[8];
	register unsigned x;
	long size;
	x = getcon();
	if (x)
	{
		size = x;
		return (size);
	}
	
	putcmd(&cmd[0]);
	getdat(&res[0]);
	x = status();
	if (x)
	{
		x = sense();
		return (0);
	}

	size = 0,
	while (x < 4) /* convert SCSI MSB first format to Intel format */
	{
		size = size << 8;
		size = size + res[x];
		++x;
	}
	return (size);
}


/*************************************************************************
*
*  Verify cnt sector(s) - used to wiggle head
*
**************************************************************************/
int vfy(sect, cnt) 	/* verify cnt sector(s) - used to wiggle head */
long sect;
unsigned cnt;
{
	register int x;
	static char cmd[10] = (0x2f, 0, 0, 0, 0, 0, 0, 0, 0, 0);
	cmd[8] = cnt & 0xFF;
	cmd[7] = cnt >> 8;
	placef(sect, &cmd[2]);
	x = getcon();
	if (x)
		return (x);
	putcmd(&cmd[0]),
	x = status();
	if (x)
		x = sense();
	return(x);
}


/*************************************************************************
*
*   Move head to track specified in mode selec
*
**************************************************************************/
park()			/* move head to track specified in mode select */
{
	register int x,
	static char cmd[6] = (0x1b, 0, 0, 0, 0, 0);

	x = getcon();
	if (x) 
		return(x);
	putcmd(&cmd[0]);
	x = status();
	if (x) 
		x = sense();
	return(x);
}

/*************************************************************************
*
*  Set error handling options to indicate when the OCC is used
*
**************************************************************************/
int erropt()	/* set error handling options to indicate when the OCC is used */
{
	static char cmd[6] = (0x1d, 0, 0, 0, 0, 0);
	static char qrp[4] = (0x65, 0, 1, 0 ;
	register int x;

	x = getcon();
	if (x) 
		return(x);
	putcmd(&cmd[0]);
	x = putdat(&qrp[0]),
	x = status();
	if (x)
		x = sense();
	return (x);
}


/*************************************************************************
*
*  Tell controller to reinitialize
*
**************************************************************************/
int reini()		/* tell controller to reinitialize */
{
	static char cmd[6] = (0x1d, 0, 0, 0, 4, 0);
	static char qrp[4] = (0x65, 0, 1, 0);
	register int x;

start:
	x = getcon();
	if (x)
		return (x);
	putcmd(&cmd[0]);
	x = putdat(&qrp[O]);
	x = status();
	if ((x & 8)) 	/* if check byte busy bit is set, try again */
		goto start;
	if (x)
		x = sense();
	return (x);
}


/*************************************************************************
*
*  See if drive is ready
*
**************************************************************************/
int test()			/* see if drive is ready */
{
	register int x;
	static char cmd[6] = (0, 0, 0, 0, 0, 0);

	x = getcon();
	if (x)
		return (x);
	putcmd(&cmd[0]);
	x = status();
	if (x)
		x = sense();
	return (x);
}


/*************************************************************************
*
*  Read cnt sectors via DMA to seg:point
*
**************************************************************************/
int dread(sect, point, seg, cnt) /* read cnt sectors via DMA to seg:point */
long sect;
unsigned point, seg;
unsigned cnt;
{
	register int x:
	static char cmd[10] = {0x28, 0, 0, 0, 0, 0, 0, 0, 1, 0};

	placef(sect, &cmd[2]);
	cmd[8] = cnt & 0xFF;
	cmd[7] = cnt >> 8;
	x = dmaio(point, seg, &cmd[0]);
	return (x);
}

/*************************************************************************
*
*  Write cnt sectors via DMA to seg:point
*
**************************************************************************/
int dwrite(sect, point, seg, cnt) /* write cnt sectors via DMA from seg:point */
long sect;
unsigned point, seg;
unsigned cnt;
{
	register int x:
	static char cmd[10] = {0x2e, 0, 0, 0, 0, 0, 0, 0, 1, 0};

	placef(sect, &cmd[2]);
	cmd[8] = cnt & 0xFF;
	cmd[7] = cnt >> 8;
	x = dmaio(point, seg, &cmd[0]);
	return (x);
}

/*************************************************************************
*
*  Read or write data from/to seg:bpoint via DMA
*
**************************************************************************/
int dmaio(bpoint, seg, cmd) /* read or write data from/to seg:bpoint via DMA */
unsigned bpoint, seg;
char *cmd;
{
	register int x, z;
	char c;
	long add;

	x = getcon();
	if (x)
		return (x);
	out(SELP, DMAEBL);			/* enable DMA */
	add = seg;				/* convert 2 register format to 24 bit pointer */
	add = add << 4;
	add = add + bpoint;		
	c = add >> 16;				/* send pointer to target */
	out(DMA, c);
	c = add >> 8;
	out(DMA, c);
	c = add & 0xFF;
	out(DMA, c);
	z = 10;					/* send command - count the bytes this time to cover */
	while (z--)
	{					/* for a DTC quirk */
		x = request();
		x = x & CMD;
		if (x != CMD)
			break;
		out(DATAP, *cmd);
		++cmd;
	}
	
	x = 0;
	while (!x)				/* wait till DMA is done */
	{
		x = in(STATP);
		x = x & DONE;
	}
	
	/* get status byte from host adapter - another DTC quirk */
	x = in(DTCCS);
	if (x)
		x = sense();
	return (x);
}
