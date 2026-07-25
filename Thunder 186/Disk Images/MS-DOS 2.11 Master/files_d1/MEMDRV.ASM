	TITLE	MEMORY DRIVE for LDP/256K RAM
PAGE	88,116
MDSK_SIZE	EQU	256	;NUMBER OF 1K BLOCKS
MDSK_BASE	EQU	8000H	;PARAGRAPH BASE ADDRESS OF MEMORY TO
				;BE USED AS MEMDRIVE

;The above equates can be changed match your system requirements.
;There must be a break in memory between system program memory
;and the MEMDRIVE in order that the system won't user the MEMDRIVE
;as program memory. The last 16 K bytes of memory are for the 
;LIGHTNING ONE monitor, which limits the size of the MEMDRIVE to 496
;K bytes of memory. If 2 256K boards are used PHANTOM must be enabled
;on the highest one.


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
	DW	2000H		;Is a block device
	DW	STRATEGY
	DW	DSK_INT
MEMMAX	DB	1		;Number of Units

	SUBTTL	Dispatch tables for each device.

DSK_TBL:DW	DSK_INI 	;0  - Initialize Driver.
	DW	MEDIAC		;1  - Return current media code.
	DW	GET_BPB 	;2  - Get Bios Parameter Block.
	DW	CMDERR		;3  - Reserved. (currently returns error)
	DW	DSK_READ 	;4  - Block read.
	DW	EXIT		;5  - (Not used, return busy flag)
	DW	EXIT		;6  - Return status. (Not used)
	DW	EXIT		;7  - Flush input buffer. (Not used.)
	DW	DSK_WRITE 	;8  - Block write.
	DW	DSK_WRITE 	;9  - Block write with verify.
	DW	EXIT		;10 - Return output status.
	DW	EXIT		;11 - Flush output buffer. (Not used.)
	DW	EXIT		;12 - IO Control.

;Define offsets for io data packet

CMDLEN	=	0		;LENGTH OF THIS COMMAND
UNIT	=	1		;SUB UNIT SPECIFIER
CMDC	=	2		;COMMAND CODE
STATUS	=	3		;STATUS
MEDIA	=	13		;MEDIA DESCRIPTOR
TRANS	=	14		;TRANSFER ADDRESS
COUNT	=	18		;COUNT OF BLOCKS OR CHARACTERS
START	=	20		;FIRST BLOCK TO TRANSFER

PTRSAV	DD	0		;Strategy pointer save.

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
; Common program for handling the simplistic I/O packet
;   processing scheme in MSDOS 2.0
;
DSK_INT:
	PUSH	SI 
	PUSH	AX		;Save all nessacary registers.
	PUSH	CX
	PUSH	DX
	PUSH	DI
	PUSH	BP
	PUSH	DS
	PUSH	ES
	PUSH	BX

	LDS	BX,CS:[PTRSAV]	;Retrieve pointer to I/O Packet.

	MOV	AL,BYTE PTR [BX.UNIT]	;AL = Unit code.
	MOV	AH,BYTE PTR [BX.MEDIA]	;AH = Media descriptor.
	MOV	CX,WORD PTR [BX.COUNT]	;CX = Contains byte/sector count.
	MOV	DX,WORD PTR [BX.START]	;DX = Starting Logical sector.
	PUSH	AX			;Save Unit and Media Temporarily.
	MOV	AL,BYTE PTR[BX.CMDC]	;Retrieve Command type. (1 => 11)
	CMP	AL,11			;Comand in range?
	JA	CMDERR			;If bad command take jump
	CBW				;Extend to word
	SHL	AX,1			;Make a word index for jmp table
	MOV	SI,OFFSET DSK_TBL	;Get jump table offset
	ADD	SI,AX			;Index into the table
	POP	AX			;Get unit and media back
	LES	DI,DWORD PTR [BX.TRANS]	;DI contains addess of Transfer address.
					;ES contains segment.
	PUSH	CS
	POP	DS			;Data segment same as Code segment.
	JMP	[SI]			;Perform I/O packet command.


CMDERR:	POP	AX			;CLEAR STACK
	MOV	AL,3			;Set unknown command error #.

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

EXIT:	MOV	AH,00000001B	;Set done bit for MSDOS.
EXIT1:	LDS	BX,CS:[PTRSAV]
	MOV	WORD PTR [BX.STATUS],AX	;Save operation compete and status.
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


MEMDRV	LABEL	BYTE
SECSIZ	DW	128		;Sector size on diskette
ALLOC	DB	4		;Number of sectors per alloc. block.	(dpb)
RESSEC	DW	0		;Reserved sectors.			(dpb)
FATS	DB	1		;Number of FAT's.			(dpb)
MAXDIR	DW	32		;Number of root directory entries.	(dpb)
SECTORS DW	8*MDSK_SIZE	;Number of sectors per diskette.	(dpb)
MEDIAID DB	0FFH		;Media byte ID. 			(dpb)
FATSEC	DW	(3*MDSK_SIZE)/128	;Number of FAT Sectors. 		(dpb)


INITTAB DW	OFFSET MEMDRV 


	SUBTTL	Media check routine

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

MEDIAC: LDS	BX,CS:[PTRSAV]
	MOV	BYTE PTR [BX.TRANS],1
	JMP	EXIT

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

GET_BPB:
	MOV	SI,OFFSET MEMDRV 
	LDS	BX,CS:[PTRSAV]
	MOV	WORD PTR [BX.COUNT],SI
	MOV	WORD PTR [BX.COUNT+2],CS
	JMP	EXIT

	SUBTTL	MSDOS 2.x Disk I/O drivers.

;
; Disk READ/WRITE functions.
;
; On entry:
;	AL = Disk I/O driver number
;	AH = Media byte.
;	ES = Disk transfer segment.
;	DI = Disk transfer offset in ES.
;	CX = Number of sectors to transfer
;	DX = Logical starting sector.
;
; On exit:
;	Normal exit through common exit routine.
;
;	Abnormal exit through common error routine.
;
DSK_READ:
	MOV	AX,DX		;MAKE SEGMENT ADDRESS FOR MEMDISK 
	SHL	AX,1
	SHL	AX,1
	SHL	AX,1
	ADD	AX,MDSK_BASE	;ADD BASE SEGMENT OFFSET
	MOV	DX,AX		;SAVE FOR LATER
	MOV	AX,CX		;COMPUTE NUBER OF WORDS TO MOV
	MOV	CX,64		;64 WORDS PER SECTOR
	PUSH	DX		;SAVE EXTENSION
	MUL	CX
	MOV	CX,AX		;SAVE REPITITION COUNT
	POP	DX		;RESTORE IT
	MOV	DS,DX		; SET MDISK ADDRESABILITY
	MOV	SI,0		;ALWAYS 0 OFFSET TO START
	REP	MOVSW		;MOV AS WORDS FOR FASTEST EXECUTION
	MOV	AL,0		;INDICATE NO ERROR
	CLC
	JMP	EXIT		;ALL DONE

DSK_WRITE:
	MOV	AX,DX
	SHL	AX,1
	SHL	AX,1
	SHL	AX,1
	ADD	AX,MDSK_BASE
	MOV	DX,AX
	MOV	AX,CX
	MOV	CX,64
	PUSH	DX
	MUL	CX
	MOV	CX,AX
	POP	DX
	MOV	AX,ES		;SAVE SOURCE ADDRESS SEG
	MOV	DS,AX		;SET SOURCE ADDRESABILITY
	MOV	ES,DX		;SET DESTINATION ADDRESABILITY
	MOV	SI,DI		;GET SOURCE OFFSET
	MOV	DI,0		;DESTINIATION ALWAYS 0
	REP	MOVSW
	MOV	AL,0
	CLC			;NO ERRORS
	JMP	EXIT


DSK_INI:
	MOV	AX,MDSK_BASE 
	MOV	ES,AX			;CLEAR ALLOCATION TABLE
	MOV	AX,0
	MOV	DI,AX
	MOV	CX,128*11		;NUMBER OF ALLOCATION UNITS 
	REP	STOSB
	MOV	CX,8*128		;DIRRECTORY AREA
	MOV	AL,0E5H			;BLANK FORMAT
	REP	STOSB
	MOV	WORD PTR ES:[0],0FFFFH
	MOV	BYTE PTR ES:[2],0FFH
	LDS	BX,CS:[PTRSAV]
	MOV	BYTE PTR [BX.MEDIA],1
	MOV	WORD PTR [BX.TRANS],OFFSET DSK_INI
	MOV	WORD PTR [BX.TRANS+2],CS
	MOV	WORD PTR [BX.COUNT],OFFSET INITTAB
	MOV	WORD PTR [BX.COUNT+2],CS
	JMP	EXIT

CODE	ENDS

	END
