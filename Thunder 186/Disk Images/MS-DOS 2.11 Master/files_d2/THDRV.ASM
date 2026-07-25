	PAGE	80,120
	TITLE   HRDDRV.SYS for the LDP systems.

; Hard Disk Driver for Version 2.x of MSDOS.
FALSE	EQU	0
TRUE	EQU	NOT FALSE

THUNDER	EQU	TRUE

;TYPES OF DRIVES SUPPORTED
QUANTUM_2040_FIRST	EQU	FALSE	;40 MBYTE QUANTUM 8" FIRST 20 MBYTE
QUANTUM_2040_SECOND	EQU	FALSE	;40 MBYTE QUANTUM 8" SECOND 20 MBYTE
QUANTUM_2020		EQU	FALSE	;20 MBYTE QUANTUM 8"
QUANTUM_2010		EQU	FALSE	;20 MBYTE QUANTUM 8"
QUANTUM_520		EQU	FALSE	;20 MBYTE QUANTUM 5 1/4"
QUANTUM_540_FIRST	EQU	FALSE	;40 MBYTE QUANTUM 5 1/4" FIRST 20MBYTE
QUANTUM_540_SECOND	EQU	FALSE	;40 MBYTE QUANTUM 5 1/4" SCND 20 MBYTE
SHUGART_SA706		EQU	FALSE	;5 MBYTE SHUGART HALF HEIGHT
SHUGART_SA712		EQU	FALSE	;10 MBYTE SHUGART HALF HEIGHT
SHUGART_SA1004		EQU	TRUE 	;10 MBYTE SHUGART 8" DRIVE
USER_DEFINED		EQU	FALSE	;MUST FILL IN TABLE FURTHER ON!!!!!

CODE	SEGMENT
ASSUME	CS:CODE,DS:CODE,ES:CODE,SS:CODE

	ORG	0		;Starts at an offset of zero.

	SUBTTL	Device driver tables.

;-----------------------------------------------+
;     DWORD pointer to next device		| 1 word offset.
;	  (-1,-1 if last device)		| 1 word segement.
;-----------------------------------------------+
;     Device attribute WORD			; 1 word.
;	Bit 15 = 1 for chacter devices. 	;
;		 0 for Block devices.		;
;						;
;	Charcter devices. (Bit 15=1)		;
;	  Bit 0 = 1  current sti device.	;
;	  Bit 1 = 1  current sto device.	;
;	  Bit 2 = 1  current NUL device.	;
;	  Bit 3 = 1  current Clock device.	;
;						;
;	  Bit 13 = 1 for non IBM machines.	;
;		   0 for IBM machines only.	;
;	  Bit 14 = 1 IOCTL control bit. 	;
;-----------------------------------------------+
;     Device strategy pointer.			; 1 word offset.
;-----------------------------------------------+
;     Device interrupt pointer. 		; 1 word offset.
;-----------------------------------------------+
;     Device name field.			; 8 bytes.
;	Character devices are any valid name	;
;	  left justified, in a space filled	;
;	  field.				;
;	Block devices contain # of units in	;
;	  the first byte.			;
;-----------------------------------------------+

DSKDEV: 			;Header for hard disk driver.
	DW	-1,-1		;Last device
	DW	2000H		;Is a block device, non IBM
	DW	STRATEGY
	DW	DSK_INT
DRVMAX	DB	1		;Number of Units

	SUBTTL	Dispatch tables for each device.

DSK_TBL:DW	HDINIT		;0  - Initialize Driver.
	DW	MEDIA_CHECK	;1  - Return current media code.
	DW	GET_BPB 	;2  - Get Bios Parameter Block.
	DW	CMDERR		;3  - Reserved. (currently returns error)
	DW	HDREAD		;4  - Block read.
	DW	BUS_EXIT	;5  - (Not used, return busy flag)
	DW	EXIT		;6  - Return status. (Not used)
	DW	EXIT		;7  - Flush input buffer. (Not used.)
	DW	HDWRITE 	;8  - Block write.
	DW	HDWRITE 	;9  - Block write with verify.
	DW	EXIT		;10 - Return output status.
	DW	EXIT		;11 - Flush output buffer. (Not used.)
	DW	EXIT		;12 - IO Control.

	SUBTTL	Strategy and Software Interrupt routines.

;Define offsets for io data packet

IODAT	STRUC
CMDLEN	DB	?		;LENGTH OF THIS COMMAND
UNIT	DB	?		;SUB UNIT SPECIFIER
CMD	DB	?		;COMMAND CODE
STATUS	DW	?		;STATUS
	DB	8 DUP (?)
MEDIA	DB	?		;MEDIA DESCRIPTOR
TRANS	DD	?		;TRANSFER ADDRESS
COUNT	DW	?		;COUNT OF BLOCKS OR CHARACTERS
START	DW	?		;FIRST BLOCK TO TRANSFER
IODAT	ENDS

PTRSAV	DD	0		;Strategy pointer save.
READFLAG	DB	0
DMASEG		DW	0
DMAOFF		DW	0
RECORDS		DW	0
;
; Simplistic Strategy routine for non-multi-Tasking system.
;
;   Currently just saves I/O packet pointers in PTRSAV for
;   later processing by the individual interrupt routines.
;

STRATP	PROC	FAR

STRATEGY:
	MOV	WORD PTR CS:[PTRSAV],BX
	MOV	WORD PTR CS:[PTRSAV+2],ES
	RET

STRATP	ENDP


;
; Ram memory driver interrupt routine for processing I/O packets.
;

DSK_INT:
	PUSH	SI		;Save SI from caller.
	MOV	SI,OFFSET DSK_TBL

;
; Common program for handling the simplistic I/O packet
;   processing scheme in MSDOS 2.0
;

ENTRY:	PUSH	AX		;Save all nessacary registers.
	PUSH	CX
	PUSH	DX
	PUSH	DI
	PUSH	BP
	PUSH	DS
	PUSH	ES
	PUSH	BX

	LDS	BX,CS:[PTRSAV]	;Retrieve pointer to I/O Packet.

	MOV	AL,[BX.UNIT]	;AL = Unit code.
	MOV	AH,[BX.MEDIA]	;AH = Media descriptor.
	MOV	CX,[BX.COUNT]	;CX = Contains byte/sector count.
	MOV	DX,[BX.START]	;DX = Starting Logical sector.
	XCHG	DI,AX		;Save Unit and Media Temporarily.
	MOV	AL,[BX.CMD]	;Retrieve Command type. (1 => 11)
	XOR	AH,AH		;Clear upper half of AX for calculation.
	ADD	SI,AX		;Compute entry pointer in dispatch table.
	ADD	SI,AX
	CMP	AL,11		;Verify that not more than 11 commands.
	JA	CMDERR		;Ah, well, error out.
	XCHG	AX,DI
	LES	DI,[BX.TRANS]	;DI contains addess of Transfer address.
				;ES contains segment.
	PUSH	CS
	POP	DS		;Data segment same as Code segment.
	JMP	[SI]		;Perform I/O packet command.

	SUBTTL	Common error and exit points.

BUS_EXIT:			;Device busy exit.
	MOV	AH,00000011B	;Set busy and done bits.
	JMP	SHORT EXIT1

CMDERR: MOV	AL,3		;Set unknown command error #.

;
;  Common error processing routine.
;   AL contains actual error code.
;
;   Error # 0 = Write Protect violation.
;	    1 = Unkown unit.
;	    2 = Drive not ready.
;	    3 = Unknown command in I/O packet.
;	    4 = CRC error.
;	    5 = Bad drive request structure length.
;	    6 = Seek error.
;	    7 = Unknown media discovered.
;	    8 = Sector not found.
;	    9 = Printer out of paper.
;	   10 = Write fault.
;	   11 = Read fault.
;	   12 = General failure.
;

ERR_EXIT:
	MOV	AH,10000001B	;Set error and done bits.
	STC			;Set carry bit also.
	JMP	SHORT EXIT1	;Quick way out.

EXITP	PROC	FAR		;Normal exit for device drivers.
EXIT:
	MOV	AH,00000001B	;Set done bit for MSDOS.
EXIT1:	LDS	BX,CS:[PTRSAV]
	MOV	[BX.STATUS],AX	;Save operation compete and status.

	POP	BX		;Restore registers.
	POP	ES
	POP	DS
	POP	BP
	POP	DI
	POP	DX
	POP	CX
	POP	AX
	POP	SI
	RET				;RESTORE REGS AND RETURN
EXITP	ENDP


;VARIABLE DRIVE PARAMETERS
;Reserved tracks is tne number of tracks to ignore on the disk drive. 
;Normally only 40 Mbyte drives require a value greater than 0. The value
;for number of sectors per allocation unit must yield a number for allocation
;units of less than 4096. 4096 is the maximum number that may be represented
;by a 12 bit value. The number of fat sectors is computed as follows:
;
; (number_of_sectors_on_the_drive/sectors_per_allocation_unit*1.5)/256 
; 
;This is for 256 byte per sector drives. One allocation unit is the minimun
;ammount of space a file may be allocated.

	IF	USER_DEFINED		;USER MUST FILL IN THIS TABLE
HEADS		EQU	8		;NUMBER OF HEADS THE SELECTED DRIVE
					;HAS
SPT		EQU	32*HEADS	;TOTAL NUMBER OF SECTORS ON TRACK
TRACKS		EQU	256		;TOTAL NUMBER OF TRACKS ON DRIVE
RESERVED_TRACKS	EQU	256		;HOW MANY TRACKS TO IGNORE
FAT_SECTORS	EQU	24		;SEE NOTE ABOVE FOR CALCULATION
ALLOC_SECTORS	EQU	16		;ALLOCATION UNITS MUST BE < 4090
STEP_RATE	EQU	4		;STEP RATE IN MS * 2
PRECOMP_VALUE	EQU	20H		;TRACK/4 TO START PRECOMP AT
	ENDIF

;10 and 20 Mbyte drives would use no reserrved tracks. The current
;limitation for MS-DOS is a drive with 64K sectors, so a 40 Mbyte 
;QUANTUM must be broken into 2 locical drives. To support a 40 Mbyte
;unit, 2 drivers are created and linked in at boot time, one for the 
;first 64k sectors and a second for last 64k sectors. The following
;table is a list of recomended values for use with the different
;diskdrives we are currently supporting:
;
;Unit         10MBYTE     20MBYTE	40MBYTE(1)	40MBYTE(2)
;
;ALLOC_SECTORS	  8	    16		   16		   16  
;SPT		 64	   128		  256	  	  256 
;HEADS		  2	     4		    8		    8	    	 
;TRACKS		512	   512		  256		  256 
;FAT_SECTORS	 24	    24		   24		   24
;RESERVED_TRACKS  0 	     0		    0		  256

	IF	QUANTUM_2010
HEADS		EQU	2
SPT		EQU	32*HEADS
TRACKS		EQU	512
RESERVED_TRACKS	EQU	0
FAT_SECTORS	EQU	24		;NUMBER OF 256 BYTE ALLOCATION SECTORS
ALLOC_SECTORS	EQU	8
STEP_RATE	EQU	4H		;2MS STEP RATE FOR RECAL
PRECOMP_VALUE	EQU	256/4
	ENDIF
	IF	QUANTUM_2020 OR QUANTUM_520 ;20 MBYTE QUANTUM DRIVES
HEADS		EQU	4
SPT		EQU	32*HEADS
TRACKS		EQU	512
RESERVED_TRACKS	EQU	0
FAT_SECTORS	EQU	24		;NUMBER OF 256 BYTE ALLOCATION SECTORS
ALLOC_SECTORS	EQU	16		;16 SECTORS PER ALLOCATION UNIT
STEP_RATE	EQU	4H		;2MS STEP RATE FOR RECAL
PRECOMP_VALUE	EQU	256/4
	ENDIF
	IF	QUANTUM_2040_FIRST OR QUANTUM_540_FIRST
HEADS		EQU	8
SPT		EQU	32*HEADS
TRACKS		EQU	256		;ALL QUANTUM HAVE 512 TRACKS
RESERVED_TRACKS	EQU	0		;NO RESERVED TRACTS ON FIRST SECTION
FAT_SECTORS	EQU	24		;NUMBER OF 256 BYTE ALLOCATION SECTORS
ALLOC_SECTORS	EQU	16		;16 SECTORS PER ALLOCATION UNIT
STEP_RATE	EQU	4H		;2MS STEP RATE FOR RECAL
PRECOMP_VALUE	EQU	256/4
	ENDIF
	IF	QUANTUM_2040_SECOND OR QUANTUM_540_SECOND
HEADS		EQU	8
SPT		EQU	32*HEADS
TRACKS		EQU	256		;TELL DOS ABOUT 256 OF 512 SECTORS
RESERVED_TRACKS	EQU	256		;IGNORE THE FIRST 256 TRACKS
FAT_SECTORS	EQU	24		;NUMBER OF 256 BYTE ALLOCATION SECTORS
ALLOC_SECTORS	EQU	16		;16 SECTORS PER ALLOCATION UNIT
STEP_RATE	EQU	4H		;2 MS STEP RATE FOR RECAL
PRECOMP_VALUE	EQU	256/4
	ENDIF
	IF	SHUGART_SA706		;SHUGART 5 MBYTE FORMATED
HEADS		EQU	2
SPT		EQU	32*HEADS
TRACKS		EQU	320
RESERVED_TRACKS	EQU	0
FAT_SECTORS	EQU	15		;NUMBER OF 256 BYTE ALLOCATION SECTORS
ALLOC_SECTORS	EQU	8
STEP_RATE	EQU	6		;3 MS STEP RATE FOR RECAL
PRECOMP_VALUE	EQU	160/4
	ENDIF
	IF	SHUGART_SA712		;SHUGART 10 MBYTE FORMATED
HEADS		EQU	4
SPT		EQU	32*HEADS
TRACKS		EQU	320
RESERVED_TRACKS	EQU	0
FAT_SECTORS	EQU	15
ALLOC_SECTORS	EQU	16
STEP_RATE	EQU	6		;3 MS STEP RATE FOR RECAL
PRECOMP_VALUE	EQU	160/4
	ENDIF
	IF	SHUGART_SA1004		;SHUGART 10 MBYTE FORMATED
HEADS		EQU	8
SPT		EQU	32*HEADS
TRACKS		EQU	256
RESERVED_TRACKS	EQU	0
FAT_SECTORS	EQU	24
ALLOC_SECTORS	EQU	8
STEP_RATE	EQU	4		;3 MS STEP RATE FOR RECAL
PRECOMP_VALUE	EQU	128/4
	ENDIF

HDDRIVE	LABEL	BYTE
SECSIZE DW	256		;Sector size in bytes.			(dpb)
ALLOC	DB	ALLOC_SECTORS	;Number of sectors per alloc. block.	(dpb)
RESSEC	DW	0		;Reserved sectors.			(dpb)
FATS	DB	2		;Number of FAT's.			(dpb)
MAXDIR	DW	256		;Number of root directory entries.	(dpb)
SECTORS DW	(SPT*TRACKS)-1	;Number of sectors per drive    	(dpb)
MEDIAID DB	0FFH		;Media byte ID. 			(dpb)
FATSEC	DW	FAT_SECTORS	;Number of FAT Sectors. 		(dpb)

INITTAB DW	OFFSET HDDRIVE

	SUBTTL	Media check routine

;******************************************************************
; HARD DISK READ AND WRITE ROUTINES
;********************************************************************

	IF	THUNDER
HD_BASE		EQU	10H
	ENDIF
	IF	NOT THUNDER
HD_BASE		EQU	90H
	ENDIF

DATAREG		EQU	HD_BASE + 00H
ERRORREG	EQU	HD_BASE + 01H
PRECOMP		EQU	HD_BASE + 01H
SECTCNTREG	EQU	HD_BASE + 02H
SECTREG		EQU	HD_BASE + 03H
CYLL		EQU	HD_BASE + 04H
CYLH		EQU	HD_BASE + 05H
SDH		EQU	HD_BASE + 06H
CMNDREG		EQU	HD_BASE + 07H
STATUSREG	EQU	HD_BASE + 07H
HDWTCMND	EQU	30H
HDRDCMND	EQU	20H
RECAL_CMND	EQU	10H + STEP_RATE
SEEK_CMND	EQU	70H

MEDIA_CHECK:
;*****************************************************************
;
; Media check routine.
; On entry:
;	AL = memory driver unit number.
;	AH = media byte
; On exit:
;
;	[MEDIA FLAG] = -1 (FF hex) if disk is changed.
;	[MEDIA FLAG] = 0 if don't know.
;	[MEDIA FLAG] = 1 if not changed.
;
;
	LDS	BX,CS:[PTRSAV]
	MOV	BYTE PTR [BX.TRANS],1
	JMP	EXIT

GET_BPB:
	SUBTTL	Build and return Bios Parameter Block for a diskette.

;
; Build Bios Parameter Blocks.
;
;	On entry:  ES:BX contains the address of a scratch sector buffer.
;		   AL = Unit number.
;		   AH = Current media byte.
;
;	On exit:   Return a DWORD pointer to the associated BPB
;		   in the Request packet.
;

	MOV	SI,OFFSET HDDRIVE
	LDS	BX,[PTRSAV]
	MOV	WORD PTR [BX.COUNT],SI
	MOV	WORD PTR [BX.COUNT+2],CS		;SEGMENT FOR BPB
	JMP	EXIT

HDREAD:
;ON ENTRY
;	AL = DRIVE NUMBER
;	AH = MEDIA BYTE
;	CX = NUMBER OF SECTORS TO READ
;	DX = LOGICAL RECORD NUMBER
;	ES = TRANSFER SEGMENT
;	DI = TRANSFER OFFSET
;
	MOV	READFLAG,TRUE
	MOV	RECORDS,0		;NUMBER OR RECORDS TRANSFERED
	JMP	SHORT HDDISK
HDWRITE:
	MOV	READFLAG,FALSE
	MOV	RECORDS,0		;NUMBER OF RECORDS ALREADY TRANSFERED
HDDISK:
	PUSH	AX
	PUSH	DI
	PUSH	CX
	PUSH	DX
	PUSH	ES
	MOV	DMASEG,ES
	MOV	DMAOFF,DI
	MOV	AX,CS
	MOV	ES,AX
HARDDISK:
	MOV	AX,DX		;RECORD TO AX FOR DIVIDE
	MOV	DX,0
	MOV	BX,SPT
	DIV	BX
	ADD	AX,RESERVED_TRACKS 
	OUT	CYLL,AL 
	PUSH	BX
	POP	BX
	MOV	AL,AH
	OUT	CYLH,AL 
	MOV	AL,1FH		;REMOVE 5BIT SECTOR ID
	AND	AL,DL
	PUSH	BX
	POP	BX
	OUT	SECTREG,AL 
	MOV	AL,0E0H		;GET BITS 5,6 AND 7 FOR HEAD INFO
	AND	AL,DL
	MOV	CL,5
	SHR	AL,CL		;MOV THEM TO CORRECT LOCATION IN BYTE
	PUSH	BX
	POP	BX
	OUT	SDH,AL 
	TEST	READFLAG,TRUE
	JZ	WRITEHD
	MOV	AL,HDRDCMND
	PUSH	BX
	POP	BX
	OUT	CMNDREG,AL 
	CALL	WAITHD
	IN	AL,STATUSREG
	TEST	AL,01H
	JNZ	HDERROR
	MOV	DI,DMAOFF
	MOV	CX,256
	PUSH	ES
	MOV	ES,DMASEG
HDRDLOOP:
	IN	AL,DATAREG
	STOSB
	LOOP	HDRDLOOP
	POP	ES
	JMP	HDCOMMON
WRITEHD:
	MOV	AL,HDWTCMND
	PUSH	BX
	POP	BX
	OUT	CMNDREG,AL 
	MOV	CX,256
	PUSH	DS
	MOV	SI,DMAOFF
	MOV	DS,DMASEG
HDWTLOOP:
	LODSB
	OUT	DATAREG,AL 
	LOOP	HDWTLOOP
	POP	DS
	CALL	WAITHD
	IN	AL,STATUSREG
	TEST	AL,01H
	JNZ	HDERROR
HDCOMMON:
	POP	ES
	POP	DX
	POP	CX
	POP	DI
	POP	AX
	DEC	CX
	JZ	HDRET
	INC	DX	;NEXT RECORD
	ADD	DI,256	;NEW DMA ADDRES
	JMP	HDDISK	;DO AGAIN
HDERROR:
	POP	ES
	POP	DX
	POP	CX
	POP	DI
	POP	AX
	MOV	AL,12
	MOV	CX,RECORDS
	LDS	BX,CS:[PTRSAV]
	MOV	[BX.COUNT],CX
	JMP	ERR_EXIT
HDRET:
	XOR	AL,AL	;NO ERRORS
	MOV	CX,RECORDS
	LDS	BX,CS:[PTRSAV]
	MOV	[BX.COUNT],CX		;RECORDS TRANSFERED
	JMP	EXIT

WAITHD:
	IN	AL,STATUSREG
	TEST	AL,80H
	JNZ	WAITHD
	RET
HDINIT:
	IF	NOT(QUANTUM_540_SECOND OR QUANTUM_2040_SECOND)
	MOV	AL,PRECOMP_VALUE
	OUT	PRECOMP,AL
	MOV	AL,0
	PUSH	BX
	POP	BX
	OUT	SDH,AL 
	PUSH	BX
	POP	BX
	OUT	CYLL,AL
	PUSH	BX
	POP	BX
	OUT	CYLH,AL
	MOV	AL,SEEK_CMND
	PUSH	BX
	POP	BX
	OUT	CMNDREG,AL
WAITRECAL:
	IN	AL,STATUSREG
	TEST	AL,80H		;BUSY
	JNZ	WAITRECAL
	MOV	AL,SEEK_CMND	;NOW SET TO BUFFERED SEEK MODE
	OUT	CMNDREG,AL
	ENDIF
	MOV	AL,[DRVMAX] 
	MOV	SI,OFFSET INITTAB 
	LDS	BX,[PTRSAV] 
	MOV	WORD PTR [BX.0EH],OFFSET HDINIT
	MOV	WORD PTR [BX.0EH + 2],CS
	MOV	[BX.MEDIA],AL
	MOV	[BX.COUNT],SI
	MOV	[BX.COUNT+2],CS
	JMP	EXIT

CODE	ENDS

	END
