/* hdctrl rev 2.11.03 850612 Hul Tytus */
/* Listing 2 */

#define READ 2 			/* read canmand for dfixO */
#define WRITE 1 		/* write command for dfix() */
#define NOSPC 0xd		/* out of space for alternate block */
#define SOFTER 0xf		/* software error in the driver */
#define DNR 4			/* drive not ready */
#define BADADD 0x21 		/* illegal block address */
#define SEEK 2 			/* drive seek error */
#define CSEEK 0x15 		/* controller seek error */
#define ECCERR 0x98 		/* error code when ECC must be used */
#define ALTCNT 127 		/* number of bad blocks ~rmissable */
#define ALTOT 128 		/* ALTCNT + 1 must be bInary unit */
#define BINCNT 64 		/* = ALTOT/2 */
#define ALTEXP 7 		/* ALTOT = 2**ALTEXP */
#define ARYBLK 3 		/* start of blocks for the arrays */
#define ALTBLK 7		/* first alternate block */
#define BLKSIZ 512 		/* size of blocks in bytes */
#define BLKINC 0x200000L 	/* BLKINC = BLKSIZ « 12 */
#define BADCNT 2 		/* number of blocks to hold both arrays */
				/* remember these are duplicated */ 
				/* first free block = ALTBLK + ALTCNI' */
				/* # of left shifts so that */
				/* # 512 byte blocks = count «SHIFT */
#define CYLSIZ 190 		/* >= sector count per cylinder */
extern unsigned drive;		/* determines which offset to use */
				/* if only one logical drive, make this 0 */
static char bloop[6] = {'B', 'A', 'D', 'B', 'L', 'K'};
static long badblk [ALTOT];	/* table of bad blocks */
static long newadd [ALTOT];	/* table of replacement blocks */
long lstblk = 0;		/* last usable block */
				/* you should use readc for this */ 
long maxblk = 0;		/* last system block */
				/* should be lstblk -134 in init after readc */
static int altflg;		/* number for array or zero */
static int okcount;		/* = 1 if all sectors' are natural */
				/* start of logical drive offset in 512 sectors */
long drvbgn[2] = {0,9600};
long readc();
long trans();

/*************************************************************************
*
*  Disk Write
*
**************************************************************************/
int diskw(block, point, count)	/* write count sectors starting at block */
				/* from pointIer) in memory */
long block, point;
int count;
{
	long sect,
	int x,
	block = block << SHIFT; 	/* convert logical 2048 byte sectors */
	count = count << SHIFT;		/* to physical 512 byte sectors */
	block = block + drvbgn[drive]; /* add logical drive offset */
	sect = trans(block, count);

	if (okcount) 	/* if an alternate sector is not used */
	{
		x = dwrite(sect, point,count);
		if (!x)
			return 0;
	}	

	while (count--) /* if error or alternate sector is required */
	{
		x = dfix(block, point, WRITE);
		if (x)
			return x;
		point = point + BLKINC; /* increment pointer & block */
		++block;
	}
	return 0;
}


/*************************************************************************
*
*  Disk Read
*
**************************************************************************/
int diskr(block, point, count) /* read count sectors to point */
long block, point;
int count;
{
	long sect;
	int x;
	block = block << SHIFT; /* convert logical 2048 byte sectors */
	count = count << SHIFT; /* to physical 512 byte sectors */
	block = block + drvbgn[drive];	/* add logical drive offset */
	sect = trans(block, count);
	if (okcount) 			/* if an alternate sector is not used */
	{
		x = dread(sect, point, count);
		if (!x)
			return 0;
	}

	while (count--) 		/* if error or alternate sector is required */
	{
		x = dfix (block, point, READ);
		if (x)
			return x;
		point = point + BLKINC; /* increment pointer & block */
		++block;
	}
	return 0;
}

/*************************************************************************
*
*  Handle Read/Write errors
*
**************************************************************************/
int dfix(blockk, src, cmd) 	/* cmd = 1 for write, 2 for read */
				/* this is routine that handles read & write errors */
long blockk, src;
int cmd;
{
	long block, check;
	int x, y, z;
start:
	y = 2;
	while(y--)  		/* try y times to get it right */
	{
		block = trans(blockk, 1);	/* get correct block number */
		if (!block)
			return BADADD; 	/*0 return means illegal block number */
		if (cmd = WRITE)
			x = dwrite(block, src, 1);
		else x = dread(block, src, 1);

		if (!x) 		/* if no error, return no error */
			return 0;
		if (x == DNR) 		/* if drive not ready, return */
			return x; 
		check = block - CYLSIZ;	/* figure a block in next cylinder */
		if (check < 0)
			check = block + CYLSIZ;
			vfy(check, 1);	/* wiggle head */
	}
	z = x;
	/* retries didn't work, so set alternate block */
	/* if correctable error */
	if ((x > 0xF && x < 0x20 && cmd == WRITE) || x == ECCERR)
	{
		x = place(block); 	/* assign alternate block */
		if (x)
			return x;	/* return if error */
		putary();		/* write RAM alternate tables to disk */
	/* if ECC error on read, write alt block wi corrected data */
		if (z == ECCERR && cmd == READ)
			{
			block = trans(blockk, 1);
			x = dwrite(block, src, 1);
			if (!x)
				return 0;
			}
		goto start;		/* now try again with alternate block */
	}
	return x;
}

/*************************************************************************
*
*  Translate Sector
*
**************************************************************************/
long trans(block, cnt) 		/* translates logical to physical sector */
				/* returns 0 for error */ 
				/* okcount = 1 if all sectors are natural */
int cnt;
long block;
{
	int x, y;
	block = block + FSTBLK;
	if (block > maxblk)
	{
		altflg = 0;
		return 0;
	}
	
	x = BINCNT; 		/* x = mid point of possible alternates */
	y = badblk[0];		/* y = number of actual alternates */
	Whlle (x > y) 		/* divide x by 2 untill x becomes binary */
		x - x >> 1;	/* mid point of actual alternates */
	altflg = x;
	okcount = 0;

	while (x) 		/* do binary search to see if block has an al ternate */
	{
		x = x >> 1;
		if (block == badblk[altflg]) /* if block has an alternate */
			return (newadd[altflgl]); /* return alternate */
		if (block > badblk[altflg] && badblk[altflg] > 0)
			altflg = altflg + x;
		else altflg = altflg - x;
	}

	if (block > badblk[altflgl])
		if (altflg=ALTCNT)
			okcount=1;
		else ++altflg;
	/* now check to see it any of next blocks have alternates */
	if ((badblk[altflg]) >= (block + (long) cnt))
		okcount = 1;
	/* indicates that all blocks in transfer are not alternates */
	if (!badblk[altflgl])
		okcount = 1;
	altflg = 0;
	return block;
}


/*************************************************************************
*
*  Replace Bad Block
*
**************************************************************************/
int place(blockk)	/* if altflg=0, inserts new block to badblk[] & */
			/* newadd[] and changes altflg */
			/* if altflg>0, inserts new # to newadd[altflg] */

long blockk;
{
int x, y;
long block;
block = blockk;
	/* check to see if an alt block is available */
	if (newadd[0] >= ALTCNT)
		return NOSPC;
	if (altflg) 		/* block is already marked bad */
		goto lump;
	++badblk[0];		/* increment length of array */
	x = 1;

				/* and find location for block */
	while (block> badblk[x] && badblk[x] != 0 && X < ALTCNT)
		++x;
	y = badblk[0]; 		/* y = last element in array when finished */
				/* move upper part of array up one element */
	while (y> x)
		{
		badblk[y] = badblk[y - 1];
		newadd[y] = newadd[y - 1];
		--y;
		}
	badblk[x] = block; 	/* insert new bad block */
	altflg = x;		/* block is now marked */
lump:
	x = newblk(altflg);	/* get new alternate sector */
	return x;
}


/*************************************************************************
*
*  Assign New Block Number
*
**************************************************************************/
int newblk(arynum) 		/* gives new block # to newadd[altflg] */
				/* returns error if all alternates in use */
int arynum;
{
	if (newadd[0] >= ALTCNT) 	/* return error if table if full */
		return NOSPC;
	newadd[arynum] = newadd[0] + ALTBLK;
	++newadd[0]; 			/* increment total number of alternates */
	return 0;
}


/*************************************************************************
*
*  Write block arrays to disk
*
**************************************************************************/
iht putary() 			/* puts both arrays to the disk */
				/* remember to declare badblk[] just before newadd[] */
{
	int x, y, ds;
	long blck;
	char *sourc;

	ds = dsget(); 		/* get current ds register */
	blck = ARYBLK;
	x = 2; 			/* remember badblks are duplicated */
	while (x--)
	{
		sourc = &badblk[0];
		y = BADCNT;
		while (y--)
		{
	/* sourc & ds simulate a long that holds segment & pointer registers */
			dwrite(blck, sourc, ds, 1);
			sourc = sourc + BLKSIZ;
			++blck;
		}
	}
}

/*************************************************************************
*
*  Read block arrays from disk
*
**************************************************************************/
int getary()			/* moves array from disk to ram */
{
	char *dest;
	int y, x, ds;
	long block;
	
	ds=dsget();		/* get current ds register */
	dest = &badblk[0];
	block = ARYBLK;
	y = BADCNT;
	while (y--)
	{
		/* dest & ds simulate a 32 bit pointer */
		x = dread(block, dest, ds, 1);
		if (x) 	/* if error, get from second disk copy of tables */
		{
			x = dread((block + BADCNT), dest, ds, 1);
			if (x && x != ECCERR)
				return x;
		}
		dest = dest + BLKSIZ;
		++block;
	}
	return 0;
}


/*************************************************************************
*
*  Initialize drive and controller
*
**************************************************************************/
int init()			/* initialize driver and controller */
{
	int x;
	x=reinit();
	if(x)
		return x;
	lstblk = readc();
	maxblk = lstblk - FSTBLK;
	if (lstblk < 256) 	/* if error is reported */
	{
		x = lstblk;
		lstblk = 0;
		maxblk = 0;
		return x;
	}
	
	x = getary(); 		/* load alternate tables */
	if (x)
		return x;
	altflg = 0;
	x = erropt(); 		/*set Adaptec option for error on successfull ECC */
	return x;
}