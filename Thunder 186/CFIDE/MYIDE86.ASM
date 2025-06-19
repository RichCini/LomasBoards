;
; Test Program to interact with the CPM3 type BIOS for the S100Computers IDE intreface board
;==============================================================================
;
;	V1.7	3/1/2010	;Removed Z80 Code (so it can be translated to 8086 code later)
;	V2.0	1/23/2011	;Updated to accomidate two CF cards (Master/Slave) & better menu options
;				;note I still have more work to do with this but what is here seem OK.
;	V2.1	2/5/2011	;Menu driven, and added code to copy & restore disk data from another
				;"backup" partition on disk
;	V2.2	2/13/2011	;Added Sec++ & Sec--
;	V2.3	2/15/2011	;Re-did drive initilization (Pulse CF cards twice on reset line)
;	V2.4	2/16/2011	;Correct small error for end of drive track check
;	V2.5	3/14/2011	;Added BOOT CPM option, cleaned up some areas.
;	V2.6	3/15/2011	;Re-dis reset line pulse. Correct CPM boot to Track 0 sector 1
;	V2.7	4/26/2011	;Add code for two drive system	
;	V2.8	4/27/2011	;Format sectors with E5's and warn "formatting CURRENT drive".
;	V2.9	3/28/2011	;Fixed initilization hanging if no drive present in drive #0 or #1 positions
;	V2.91	12/23/2017	;Fixed (double shifting) error in ZBITS
;	v2.91a	12/19/2024	RAC -- converted for use with the Lomas T186

;	For all versions assemble to a binary file with the excellent/free MSDOS/FreeDOS, NASM.EXE Assembler
;	compile with nasm -o prg.com -l prg.lst prg.asm


;Ports for 8255 chip. Change these to specify where your 8255 is addressed,
;The first three control which 8255 ports have the control signals,
;upper and lower data bytes.  The last one (IDEportCtrl), is for mode setting for the
;8255 to configure its actual I/O ports (A,B & C).  
;
;Note most drives these days dont use the old Head,Track, Sector terminology. Instead
;we use "Logical Block Addressing" or LBA. This is what we use below. LBA treats the drive
; as one continous set of sectors, 0,1,2,3,... 3124,....etc.  However as seen below we need to 
;convert this LBA to heads,tracks and sectors to be compatible with CPM & MSDOS.

;NOTE: If you have only one drive/CF card, be sure it is in drive #0 (LHS of board). The IDE hardware gets 
;confused if there is only a drive in slot #1.

;-------------- S100Computers IDE BOARD PORT ASSIGNMENTS  (30-34H)

;Ports for 8255 chip. Change these to specify where the 8255 is addressed,
;and which of the 8255's ports are connected to which IDE signals.
;The first three control which 8255 ports have the IDE control signals,
;upper and lower data bytes.  The forth one is for mode setting for the
;8255 to configure its ports, which must correspond to the way that
;the first three lines define which ports are connected.

IDEportA	EQU	030H		;lower 8 bits of IDE interface
IDEportB	EQU	031H		;upper 8 bits of IDE interface
IDEportC	EQU	032H		;control lines for IDE interface
IDECtrlPort	EQU	033H		;8255 configuration port
IDEDrivePort	EQU	034H		;To select the 1st or 2nd CF card/drive

IDE_Reset_Delay	EQU	020H		;Time delay for reset/initilization (~66 uS, with 8MHz 8086, 1 I/O wait state)

READcfg8255	EQU	10010010b	;Set 8255 IDEportC out, IDEportA/B input
WRITEcfg8255	EQU	10000000b	;Set all three 8255 ports output

;IDE control lines for use with IDEportC.  

IDEa0line	EQU	01H		;direct from 8255 to IDE interface
IDEa1line	EQU	02H		;direct from 8255 to IDE interface
IDEa2line	EQU	04H		;direct from 8255 to IDE interface
IDEcs0line	EQU	08H		;inverter between 8255 and IDE interface
IDEcs1line	EQU	10H		;inverter between 8255 and IDE interface
IDEwrline	EQU	20H		;inverter between 8255 and IDE interface
IDErdline	EQU	40H		;inverter between 8255 and IDE interface
IDErstline	EQU	80H		;inverter between 8255 and IDE interface
;
;Symbolic constants for the IDE Drive registers, this makes the
;code more readable than always specifying the address pins

REGdata		EQU	IDEcs0line
REGerr		EQU	IDEcs0line + IDEa0line
REGseccnt	EQU	IDEcs0line + IDEa1line
REGsector	EQU	IDEcs0line + IDEa1line + IDEa0line
REGcylinderLSB	EQU	IDEcs0line + IDEa2line
REGcylinderMSB	EQU	IDEcs0line + IDEa2line + IDEa0line
REGshd		EQU	IDEcs0line + IDEa2line + IDEa1line	;(0EH)
REGcommand	EQU	IDEcs0line + IDEa2line + IDEa1line + IDEa0line	;(0FH)
REGstatus	EQU	IDEcs0line + IDEa2line + IDEa1line + IDEa0line
REGcontrol	EQU	IDEcs1line + IDEa2line + IDEa1line
REGastatus	EQU	IDEcs1line + IDEa2line + IDEa1line + IDEa0line

;IDE Command Constants.  These should never change.

COMMANDrecal	EQU	10H
COMMANDread	EQU	20H
COMMANDwrite	EQU	30H
COMMANDinit	EQU	91H
COMMANDid	EQU	0ECH
COMMANDspindown EQU	0E0H
COMMANDspinup	EQU	0E1H
;
; IDE Status Register:
;  bit 7: Busy	1=busy, 0=not busy
;  bit 6: Ready 1=ready for command, 0=not ready yet
;  bit 5: DF	1=fault occured on the IDE drive
;  bit 4: DSC	1=seek complete
;  bit 3: DRQ	1=data request ready, 0=not ready to xfer yet
;  bit 2: CORR	1=correctable error occured
;  bit 1: IDX	vendor specific
;  bit 0: ERR	1=error occured

MAXSEC		EQU	3DH		;Sectors per track for CF my Memory drive, Kingston CF 8G. (CPM format, 0-3CH)
					;translates to LBA format of 1 to 3D sectors, for a total of 61 sectors/track.
					;This CF card actully has 3F sectors/track. Will use 3D for my CPM86 system because
					;my Seagate drive has 3D sectors/track. Don't want different CPM86.SYS files around
					;so this program will also work with a Seagate 6531 IDE drive

DOS_MAXSEC	EQU	3FH		;For MS-DOS BIOS Setting "Hard Disk" to Custom type (CF Card, 63 Sectors/track)
DOS_MAXHEADS	EQU	10H		;16 head(s)
DOS_MAXCYL_L	EQU	0FFH		;Low Byte maximum cylinder (sent via INT 13H's in CH)
DOS_MAXCYL	EQU	1024		;Max cylinders
DOS_MAXSEC_CYL	EQU	0FFH		;3FH, maximum sector number (bits 5-0)+ two Cyl High Bits (Sectors numbered 1....x)

				;Equates for display on SD Systems Video Board (Used In CPM Debugging mode only)
;SCROLL		EQU	01H	;Set scrool direction UP.
LF		EQU	0AH
CR		EQU	0DH
BS		EQU	08H	;Back space (required for sector display)
BELL		EQU	07H
SPACE		EQU	20H
;QUIT		EQU	11H	;Turns off any screen enhancements (flashing, underline etc).
;NO$ENHANCEMENT	EQU	17H	;Turns off whatever is on
;FAST		EQU	10H	;High speed scrool
;TAB		EQU	09H	;TAB ACROSS (8 SPACES FOR SD-BOARD)
ESC		EQU	1BH
;CLEAR		EQU	1CH	;SD Systems Video Board, Clear to EOL. (Use 80 spaces if EOL not available
				;on other video cards)
				
;SEC$SIZE	EQU	512	;Assume sector size as 512. (Not tested for other sizes)
;MAXSEC		EQU	3DH	;Sectors per track for CF my Memory drive, Kingston CF 8G. (For CPM format, 0-3CH)
				;This translates to LBA format of 1 to 3D sectors, for a total of 61 sectors/track.
				;This CF card actully has 3F sectors/track. Will use 3D for my CPM3 system because
				;my Seagate drive has 3D sectors/track. Don't want different CPM3.SYS files around
				;so this program as is will also work with a Seagate 6531 IDE drive

;MAXTRK		EQU	0FFH	;CPM3 allows up to 8MG so 0-256 "tracks"
;BUFFER$ORG	EQU	4000H	;<----- Will place all sector data here

;CPM$BOOT$COUNT	EQU	12		;Allow up to 12 CPM sectors for CPMLDR
;CPMLDR$ADDRESS	EQU	BUFFER$ORG	;We cannot load the CPMLDR at 100H in RAM since this is where this program resides

;RDCON		EQU	1	;For CP/M I/O
;WRCON		EQU	2
;RESET$DISK	EQU	0DH	;Reset all CPM disks
;PRINT		EQU	9
;CONST		EQU	11	;CONSOLE STAT
;BDOS		EQU	5

TRUE		equ	1
FALSE		equ	TRUE-TRUE 

;CPM		EQU	TRUE	;TRUE if output via CPM, FALSE if direct to hardware
;DEBUG		EQU	TRUE
;CPM$TRANSLATE	EQU	TRUE	;Translate Trk,Sec,Head to CPM TRACK# & SEC# on display



;--------------------------------------------------------------------------------------------
		CPU 186		;No 80286/386 opcodes
;		[BITS 16]				

SECTION	.text 

	org	100H

begin:
	push	cs
	pop	ds
	mov	bx,SIGNON		;Signon notice
	call	PRINT_STRING		;Note up to now stack was not used.
	JMP	OVER$TBL
	
				;COMMAND BRANCH TABLE
IDE_TABLE:
	DW  SET_DRIVE_A		; "A"  Select Drive A
	DW  SET_DRIVE_B		; "B"  Select Drive B
	DW  ERROR		; "C"  LOAD CPM (If present)
	DW  DISPLAY		; "D"  Sector contents display:- ON/OFF
	DW  RAMCLEAR		; "E"  Clear RAM buffer
	DW  FORMAT		; "F"  Format current disk
	DW  ERROR		; "G"  Restore backup
	DW  ERROR		; "H"  Backup partition
	DW  NEXT_SECT		; "I"  Next Sector
	DW  PREV_SECT		; "J"  Previous sector
	DW  IDE_LOOP		; "K"  
	DW  SET_LBA		; "L"  Set LBA value (Set Track,sector)  
	DW  ERROR		; "M"  
	DW  SPINDOWN		; "N"  Power down hard disk command
	DW  DRIVE_ID		; "O"  Show current Drive ID
	DW  ERROR		; "P"
	DW  ERROR		; "Q"  
	DW  READ_SEC		; "R"  Read sector to data buffer
	DW  SEQ_SEC_RD		; "S"  Sequental sec read and display contents
	DW  ERROR		; "T"  
	DW  SPINUP		; "U"  Power up hard disk command
	DW  N_RD_SEC		; "V"  Read N sectors
	DW  WRITE_SEC		; "W"  Write data buffer to current sector
	DW  N_WR_SEC		; "X"  Write N sectors
	DW  COPY_AB		; "Y"  Copy Drive A to Drive B
	DW  VERIFY_AB		; "Z"  Verify Drive A:= Drive B:

OVER$TBL:				
	MOV	BP,DISPLAY_FLAG		;Do we have detail sector data display flag on or off
	MOV	AL,0FFH			;Set default to detailed sector display
	MOV	[BP],AL	

	MOV	BX,IDE_HARDWARE		;"Initilizing IDE Drive hardware"
	CALL	PRINT_STRING
	
	CALL	CLEAR$ID$BUFFER		;Clear ID Buffer

	CALL	SET_DRIVE_A		;Select the first Drive/CF card
	CALL	IDEinit			;Initialize the board and drive #0. If there is no drive abort
	JZ	INIT1_OK
	
	MOV	BX,INIT_1_ERROR
	CALL	PRINT_STRING
ABORT:
; exit the program
	mov	ax,4c00h
	int	21H

INIT1_OK:
	CALL	CLEAR$ID$BUFFER		;Clear ID Buffer

	CALL	SET_DRIVE_B		;Select the second Drive/CF card (Do not mess with CPM Drive 0)
	CALL	IDEinit			;Initialize drive #1. If there is no drive abort
	JZ	INIT2_OK
	
	CALL	CLEAR$ID$BUFFER		;Clear ID Buffer
	
	MOV	BX,INIT_2_ERROR		;Warn second IDE drive did not initilize
	CALL	PRINT_STRING		;Since first drive was OK we will still go to INIT2_OK

 INIT2_OK:
	CALL	SET_DRIVE_A		;Back to first drive/CF Card

	CALL	DRIVE_ID		;Get the drive 0 ID info. If there is no drive just abort
	JZ	INIT3_OK
	
	MOV	BX,BAD_DRIVE		;"Error obtaining the Drive ID"
	CALL	PRINT_STRING
	JMP	ABORT

INIT3_OK:				;Check we have a valid IDE drive 
	MOV	BP,(IDE_Buffer+12)	;Note always SS: = CS:
	MOV	AX,[BP]
	OR	AX,AX			;If there are zero sectors then something wrong
	JNZ	INIT4_OK

	MOV	BX,BAD_DRIVE		;"Error obtaining first Drive ID"
	CALL	PRINT_STRING
	JMP	ABORT
	
INIT4_OK:
	MOV	BP,RAM_DMA		;Set default position will be first sector block
	MOV	word[BP],IDE_Buffer	;DMA always initially to IDE_Buffer, 
	
	MOV	BP,RAM_SEC
	MOV	word[BP],0H		;Sec 0
	MOV	BP,RAM_TRK
	MOV	word[BP],0H		;Track 0
					
	CALL	IDEinit			;For some reason this need to be here after getting the drive ID.
					;otherewise sector #'s are off by one! (Probably because on non-LBA reads)
	CALL	WR_LBA			;Update LBA on "1st" drive

;------------- MAIN IDE DRIVE DIAGNOSTIC MENU ---------------------------	
	
IDE_LOOP:
	MOV	AX,CS			;Just in case somehow they changed somewhere below
	MOV	DS,AX
	MOV	ES,AX
	
	MOV	BX,IDE_SIGNON0		;List IDE command options
	CALL	PRINT_STRING

	MOV	BP,CURRENT_IDE_DRIVE
	MOV	AL,[BP]
	OR	AL,AL
	JNZ	SIGN_B
	MOV	BX,CURRENT_MSG_A
	JMP	IDE_LOOP0
SIGN_B:	MOV	BX,CURRENT_MSG_B
IDE_LOOP0:
	CALL	PRINT_STRING
	
	MOV	BX,IDE_SIGNON4		;List IDE command options
	CALL	PRINT_STRING
	
	MOV	BP,DISPLAY_FLAG		;Do we have detail sector data display flag ON or OFF
	MOV	AL,[BP]			;NZ = on 
	OR	AL,AL
	JNZ	IDE_LOOP1
	MOV	BX,IDE_SIGNON1		;"ON"
	JMP	IDE_LOOP2
IDE_LOOP1:
	MOV	BX,IDE_SIGNON2		;"OFF"
IDE_LOOP2:
	CALL	PRINT_STRING
	MOV	BX,IDE_SIGNON3		;List IDE command options
	CALL	PRINT_STRING
	
	CALL	DISPLAY_POSITION	;Display current Track,sector,head#

	CALL	CRLF
	MOV	BX,IDE_MENU		;Enter a command 
	CALL	PRINT_STRING

	call	CICO			;Get a command from Console
	mov	ah,0
	CMP	AL,ESC			;Abort if ESC
	JNZ	NOT_ESC
	JMP	ABORT			;Back to start of Monitor

NOT_ESC:cmp	al,'A'			;Find meuu option from table
	jb	IDE_LOOP		;must be A to Z
	cmp	al,'Z'
	jg	IDE_LOOP
	sub	al,'A'			;calculate offset
	shl	al,1			;X 2
	add	ax,IDE_TABLE		;Note DS:=CS:
	mov	bx,ax			
	CALL	CRLF
	mov	ax,[cs:bx]		;get location of routine CS:[BX]
	call	ax			;<----------- This is the IDE Menu CMD call
	jmp	IDE_LOOP		;finished 

ERROR:	mov	bx,ERR_MSG	;CMD error msg
	CALL	PRINT_STRING
	JMP	IDE_LOOP

;             INDIVIDUAL IDE DRIVE MENU COMMANDS 

;---------------Select Drive/CF card ------------------------------------------
SET_DRIVE_A:				;Select First Drive
	MOV	AL,0
SELECT_DRIVE:
	MOV	BP,CURRENT_IDE_DRIVE
	MOV	[BP],AL
	OUT	IDEDrivePort,AL		;Select Drive 0 or 1
	RET	

SET_DRIVE_B:				;Select Drive 1
	MOV	AL,1
	JMP	SELECT_DRIVE


;---------------- Do the IDEntify drive command, and display the IDE_Buffer ------------
DRIVE_ID:
	CALL	IDEwaitnotbusy
	JNB	L_5
	XOR	AX,AX
	DEC	AX			;NZ if error
	RET				;If Busy return NZ
	
L_5:	MOV	DH,COMMANDid
	MOV	DL,REGcommand
	CALL	IDEwr8D			;issue the command
	
	CALL	IDEwaitdrq		;Wait for Busy=0, DRQ=1
	JNB	L_6	
	JMP	SHOWerrors
	
L_6:	MOV	CH,0			;256 words
	MOV	BP,IDE_Buffer		;Store data here (remember CS: = SS:)
	CALL	MoreRD16		;Get 256 words of data from REGdata port to ss:[BP]


	MOV	BX,msgmdl		;print the drive's model number
	CALL	PRINT_STRING
	MOV	BP,(IDE_Buffer + 54)
	MOV	CH,10			;Character count in words
	CALL	Print_ID_Info		;Print [HL], [B] X 2 characters
	CALL	CRLF
					; print the drive's serial number
	MOV	BX,msgsn
	CALL	PRINT_STRING
	MOV	BP,(IDE_Buffer + 20)
	MOV	CH,5			;Character count in words
	CALL	Print_ID_Info
	CALL	CRLF
					;PRINT_STRING the drive's firmware revision string
	MOV	BX,msgrev
	CALL	PRINT_STRING
	MOV	BP,(IDE_Buffer + 46)
	MOV	CH,2
	CALL	Print_ID_Info		;Character count in words
	CALL	CRLF
					;print the drive's cylinder, head, and sector specs
	MOV	BX,msgcy
	CALL	PRINT_STRING
	MOV	BP,(IDE_Buffer + 2)
	CALL	Print_ID_HEX
	MOV	BX,msghd
	CALL	PRINT_STRING
	MOV	BP,(IDE_Buffer + 6)
	CALL	Print_ID_HEX
	MOV	BX,msgsc
	CALL	PRINT_STRING
	MOV	BP,(IDE_Buffer + 12)	;Sectors/track
	CALL	Print_ID_HEX
	CALL	CRLF
	XOR	AX,AX			;Ret Z
	RET


; Print a string located [BP] (Used only by the above DISK ID routine)
Print_ID_Info:
	MOV	CL,[BP+1]		;Text is low byte high byte format
	CALL	CO
	MOV	CL,[BP]
	CALL	CO
	INC	BP
	INC	BP
	DEC	CH
	JNZ	Print_ID_Info
	RET

; Print a 16 bit number, located [BP] (Used only by the above DISK ID routine)
; (Note Special Low Byte First. Used only for Drive ID)

Print_ID_HEX:
	MOV	AL,[BP+1]		;Index to high byte first
	CALL	AL_HEXOUT
	MOV	AL,[BP]			;Now low byte
	CALL	AL_HEXOUT
	RET

;-------------- Read the current selected sector (based on LBA) to the IDE Buffer
READ_SEC:
	MOV	AX,CS
	MOV	DS,AX
	MOV	BP,RAM_DMA
	MOV	word [BP],IDE_Buffer  ;DMA initially to IDE_Buffer

	CALL	READSECTOR
	
	JZ	Main1B
	CALL	CRLF			;Here if there was a problem
	RET

Main1B:	MOV	BX,msgrd		;Sector read OK
	CALL	PRINT_STRING

	MOV	BP,DISPLAY_FLAG		;Do we have detail sector data display flag on or off
	MOV	AL,[BP]			;NZ = on 
	OR	AL,AL
	JNZ	SHOW_SEC_RDATA
	RET

SHOW_SEC_RDATA:	
	MOV	BP,RAM_DMA
	MOV	word [BP],IDE_Buffer	;DMA initially to IDE_Buffer
	CALL	DISPLAY_SEC
	MOV	BX,CR_To_Continue 
	CALL	PRINT_STRING
	CALL	CI
	RET
	


;----------------- Write the current selected sector (based on LBA) from the IDE Buffer
WRITE_SEC:
	MOV	AX,CS
	MOV	DS,AX
	MOV	BX,CONFIRM_WR_MSG	;Are you sure?
	CALL	PRINT_STRING
	CALL	CICO
	CMP	AL,'Y'
	JZ	WR_SEC_OK1
	CALL	CRLF			;Here if there was a problem
	RET
 
WR_SEC_OK1:
	MOV	BP,RAM_DMA
	MOV	word [BP],IDE_Buffer	;DMA initially to IDE_Buffer

	CALL	WRITESECTOR		;Will write whatever is in the IDE_Buffer
	
	JZ	Main2B
	CALL	CRLF			;Here if there was a problem
	RET

Main2B:	MOV	BX,msgrd		;Sector written OK
	CALL	PRINT_STRING

	MOV	BP,DISPLAY_FLAG		;Do we have detail sector data display flag on or off
	MOV	AL,[BP]			;NZ = on 
	OR	AL,AL
	JNZ	SHOW_SEC_WDATA
	RET


SHOW_SEC_WDATA:	
	MOV	BP,RAM_DMA
	MOV	word [BP],IDE_Buffer	;DMA initially to IDE_Buffer
	CALL	DISPLAY_SEC
	MOV	BX,CR_To_Continue 
	CALL	PRINT_STRING
	CALL	CI
	RET


;---------------------  Set a new LBA value from imputted Track/Sec info. Send to drive
SET_LBA:MOV	AX,CS
	MOV	DS,AX
	MOV	BX,SET_LBA_MSG		;Set new LBA and send to drive
	CALL	PRINT_STRING
	CALL	GEN_HEX32_LBA		;Get new CPM style Track & Sector number and put them in RAM at RAM_SEC & RAM_TRK 
	JB	main3b			;Ret C set if abort/error
	CALL	WR_LBA			;Update LBA on drive
main3b:	CALL	CRLF
	RET


;---------------------- Toggle detailed sector display on/off
DISPLAY:
	MOV	AX,CS
	MOV	DS,AX
	MOV	BP,DISPLAY_FLAG	;Do we have detail sector data display flag on or off
	MOV	AL,[BP]			;NZ = on 
	NOT	AL
	MOV	[BP],AL
	RET


;--------------------- Point current sector to next sector
NEXT_SECT:
	CALL	GET_NEXT_SECT
	JNZ	AT_END
	RET
AT_END:
	MOV	BX,AT_END_MSG		;Tell us we are at end of disk
	CALL	PRINT_STRING
	RET

;--------------------- Point current sector to previous sector
PREV_SECT:
	CALL	GET_PREV_SECT
	JNZ	AT_START
	RET
AT_START:
	MOV	BX,AT_START_MSG		;Tell us we are at start of disk
	CALL	PRINT_STRING
	RET

	
;--------------------- Sequentially read sectors from disk starting at current LBA position
SEQ_SEC_RD:
	MOV	AX,CS
	MOV	DS,AX
	CALL	IDEwaitnotbusy	
	JNB	MORE_SEC	
	JMP	SHOWerrors

MORE_SEC:
	CALL	CRLF
	MOV	BP,RAM_DMA		;Set DMA initially to IDE_Buffer
	
	MOV	CL,'<'
	CALL	CO
	MOV	AX,BP
	CALL	AX_HEXOUT
	
	MOV	word [BP],IDE_Buffer  
	MOV	CL,'.'
	CALL	CO
	MOV	AX,[BP]
	CALL	AX_HEXOUT
	MOV	CL,'>'
	CALL	CO
	
	CALL	READSECTOR		;If there are errors they will show up in READSECTOR
	JZ	SEQOK

	MOV	BX,CONTINUE_MSG		;If an error ask if we wish to continue
	CALL	PRINT_STRING
	CALL	CICO
	CMP	AL,ESC			;Abort if ESC
	JNZ	SEQOK
	RET

SEQOK:	CALL	DISPLAY_POSITION	;Display current Track,sector,head#
	
	MOV	BP,DISPLAY_FLAG		;Do we have detail sector data display flag on or off
	MOV	AL,[BP]			;NZ = on 
	OR	AL,AL
	JZ	MORES2
	MOV	BP,RAM_DMA		;Point DMA to IDE_Buffer again
	MOV	word [BP],IDE_Buffer  
	CALL	DISPLAY_SEC

MORES2:	CALL	CSTS			;Any keyboard character will stop display
	JZ	NO_WAIT			
	CALL	CI			
	MOV	BX,CONTINUE_MSG
	CALL	PRINT_STRING
	CALL	CI
	CMP	AL,ESC
	JNZ	NO_WAIT
	RET				;Bug, is returning to monitor, must be a stack problem!
NO_WAIT:CALL	GET_NEXT_SECT		;Point LBA to next sector
	JZ	MORE_SEC		;Note will go to last sec on disk unless stopped
	RET


;--------------- Read N Sectors to disk
;Note unlike the normal sector read, this routine increments the DMA address after each sector read
 
N_RD_SEC:			
	MOV	AX,CS
	MOV	DS,AX
	MOV	BX,READN_MSG
	CALL	PRINT_STRING
	CALL	GET2DIGITS		;Hex to AL
	
	MOV	BP,SECTOR_COUNT		;store sector count
	MOV	[BP],AL

	MOV	BP,RAM_DMA_STORE
	MOV	word [BP],IDE_Buffer	;DMA_STORE initially to IDE_Buffer

NextRSec:	
	MOV	BX, READN_S_MSG
	CALL	PRINT_STRING
	CALL	WR_LBA			;Update LBA on drive
	CALL	DISPLAY_POSITION	;Display current Track,sector,head#
	
	MOV	BP,RAM_DMA_STORE
	MOV	AX,[BP]			;Get last value of DMA address	
	MOV	BP,RAM_DMA
	MOV	[BP],AX			;Store it in DMA address	


	CALL	READSECTOR		;Actully, Sector/track values are already updated

	MOV	BP,RAM_DMA
	MOV	AX,[BP]			;Store it in DMA_STORE address	
	MOV	BP,RAM_DMA_STORE
	MOV	[BP],AX		

	MOV	BP,SECTOR_COUNT
	MOV	AL,[BP]
	DEC	AL
	MOV	[BP],AL
	JNZ	NEXT_SEC_NRD
	RET
NEXT_SEC_NRD:
	CALL	GET_NEXT_SECT		
	JZ	NextRSec
	MOV	BX,AT_END_MSG		;Tell us we are at end of disk
	CALL	PRINT_STRING
	RET




;------------------ Write N Sectors to disk
;Note unlike the normal sector write routine, this routine incriments the DMA address after each write.

N_WR_SEC:			
	MOV	AX,CS
	MOV	DS,AX
	MOV	BX,CONFIRM_WR_MSG	;Are you sure?
	CALL	PRINT_STRING
	CALL	CICO
	CMP	AL,'Y'
	JZ	WR_SEC_OK2
	CALL	CRLF			;Here if there was a problem
	RET
 
WR_SEC_OK2:
	MOV	BX,WRITEN_MSG
	CALL	PRINT_STRING
	CALL	GET2DIGITS		;Hex to AL
	
	MOV	BP,SECTOR_COUNT		;store sector count
	MOV	[BP],AL

	MOV	BP,RAM_DMA_STORE
	MOV	word [BP],IDE_Buffer	;DMA_STORE initially to IDE_Buffer

NextWSec:	
	MOV	BX, WRITEN_S_MSG
	CALL	PRINT_STRING
	CALL	WR_LBA			;Update LBA on drive
	CALL	DISPLAY_POSITION	;Display current Track,sector,head#
	
	MOV	BP,RAM_DMA_STORE
	MOV	AX,[BP]			;Get last value of DMA address	
	MOV	BP,RAM_DMA
	MOV	[BP],AX			;Store it in DMA address	

	CALL	WRITESECTOR		;Actully, Sector/track values are already updated

	MOV	BP,RAM_DMA
	MOV	AX,[BP]			;Store it in DMA_STORE address	
	MOV	BP,RAM_DMA_STORE
	MOV	[BP],AX		

	MOV	BP,SECTOR_COUNT
	MOV	AL,[BP]
	DEC	AL
	MOV	[BP],AL
	JNZ	NEXT_SEC_NWR
	RET
NEXT_SEC_NWR:
	CALL	GET_NEXT_SECT		
	JZ	NextWSec
	MOV	BX,AT_END_MSG		;Tell us we are at end of disk
	CALL	PRINT_STRING
	RET


;-------------- Format current disk
FORMAT:	
	MOV	AX,CS
	MOV	DS,AX
	MOV	BP,CURRENT_IDE_DRIVE
	MOV	AL,[BP]
	OR	AL,AL
	JNZ	FORM_B
	MOV	BX,FORMAT_MSG_A
	JMP	FORM_X
FORM_B:	MOV	BX,FORMAT_MSG_B
FORM_X: CALL	PRINT_STRING
	MOV	BX, CONFIRM_WR_MSG	;Are you sure?
	CALL	PRINT_STRING
	CALL	CICO
	CMP	AL,'Y'
	JZ	FORMAT_OK	
	RET
	
FORMAT_OK:
	MOV	AX,0			;Back to CPM sector 0
	MOV	BP,RAM_SEC		;Get Current Sector
	MOV	[BP],AX			;0 to CPM Sectors
	
	MOV	BP,RAM_TRK		;And track
	MOV	[BP],AX

	MOV	AX,0E5E5H		;First set Sector pattern to E5's
	CALL	RAM_FILL
	CALL	CRLF

NEXT_FORMAT:
	MOV	BP, RAM_DMA		;Point DMA to the area
	MOV	word [BP],IDE_Buffer
	
	CALL	WRITESECTOR		;Will return error if there was one
	JZ	NEXTF1			;Z means the sector write was OK
	
	MOV	BX,FORMAT_ERR		;Indicate an error
	CALL	PRINT_STRING
	CALL	SHOW_TRACK_SEC		;Show current location of error
	CALL	CRLF
	JMP	FNEXTSEC3

NEXTF1:	MOV	BP,RAM_SEC		;Get Current Sector
	MOV	AX,[BP]
	OR	AX,AX			;At start of each track give an update
	JNZ	FNEXTSEC2
	
	CALL	SHOW_TRACK

FNEXTSEC2:
	CALL	CSTS			;Any keyboard character will stop display
	JZ	FNEXTSEC1
	CALL	CI			;Flush character
FNEXTSEC3:	
	MOV	BX,CONTINUE_MSG
	CALL	PRINT_STRING
	CALL	CICO
	CMP	AL,ESC
	JNZ	FNEXTSEC1
F_DONE:	MOV	AL,0			;Login drive A:
	CALL	SELECT_DRIVE
	MOV	BP,CURRENT_IDE_DRIVE
	MOV	[BP],AL
	RET

FNEXTSEC1:	
	CALL	GET_NEXT_SECT
	JZ	NEXT_FORMAT
	MOV	BX,AT_END_MSG		;Tell us we are at end of disk
	CALL	PRINT_STRING
	JMP	F_DONE

;---------------- Copy Drive A: to Drive B:  ------------------------------
COPY_AB:			
	MOV	AX,CS
	MOV	DS,AX
	MOV	BX,DiskCopyMsg
	CALL	PRINT_STRING
	CALL	CICO
	CMP	AL,'Y'
	JZ	COPY_AB1
	JMP	C_DONE
	
COPY_AB1:	
	MOV	BP, RAM_SEC		;Start with CPM sector 0
	MOV	AX,0
	MOV	[BP],AX
	MOV	BP,RAM_TRK		;Start with CPM Track 0
	MOV	AX,0
	MOV	[BP],AX			;High & Low Track to 0
	CALL	CRLF
	CALL	CRLF
	
NextDCopy:	
	MOV	AL,0			;Login drive A:
	CALL	SELECT_DRIVE

	CALL	WR_LBA			;Update LBA on "A:" drive

	MOV	BP,RAM_DMA
	MOV	word [BP],IDE_Buffer	;DMA initially to IDE_Buffer
	
	CALL	READSECTOR		;Get sector data from A: drive to buffer
	
	MOV	AL,1			;Login drive B:
	CALL	SELECT_DRIVE
	
	CALL	WR_LBA			;Update LBA on "B:" drive
	
	MOV	BP,RAM_DMA
	MOV	word [BP],IDE_Buffer	;DMA initially to IDE_Buffer
	
	CALL	WRITESECTOR		;Write buffer data to sector on B: drive
	JZ	COPY_OK1

	MOV	BX,COPY_ERR		;Indicate an error
	CALL	PRINT_STRING
	CALL	SHOW_TRACK_SEC		;Show current location of error
	CALL	CRLF
	JMP	COPY_OK3

COPY_OK1:
	MOV	BP,RAM_SEC		;Get Current Sector
	MOV	AX,[BP]
	OR	AX,AX			;At start of each track give an update
	JNZ	COPY_OK2
	
	CALL	SHOW_TRACK
	
COPY_OK2:
	CALL	CSTS			;Any keyboard character will stop display
	JZ	C_NEXTSEC1
	CALL	CI			;Flush character
COPY_OK3:
	MOV	BX,CONTINUE_MSG
	CALL	PRINT_STRING
	CALL	CICO
	CMP	AL,ESC
	JNZ	C_NEXTSEC1
C_DONE:	MOV	AL,0			;Login drive A:
	CALL	SELECT_DRIVE
	MOV	BP,CURRENT_IDE_DRIVE
	MOV	[BP],AL
	RET
	
C_NEXTSEC1:
	CALL	GET_NEXT_SECT		;Update to next sector/track
	JNZ	C_NEXTSEC2
	JMP	NextDCopy

C_NEXTSEC2:	
	MOV	BX,CopyDone		;Tell us we are all done.
	CALL	PRINT_STRING
	JMP	C_DONE
	
	
;-------------- Verify Drive A: = B: ------------------------------
VERIFY_AB:		
	MOV	AX,CS
	MOV	DS,AX
	MOV	BX,DiskVerifyMsg
	CALL	PRINT_STRING
	
	MOV	BP,RAM_SEC		;Start with CPM sector 0
	MOV	AX,0
	MOV	[BP],AX
	MOV	BP,RAM_TRK		;Start with CPM Track 0
	MOV	AX,0
	MOV	[BP],AX			;High & Low Track to 0
	
	CALL	CRLF
	CALL	CRLF
	
NextVCopy:
	MOV	AL,0			;Login drive A:
	CALL	SELECT_DRIVE

	CALL	WR_LBA			;Update LBA on "A:" drive

	MOV	BP,RAM_DMA
	MOV	word [BP],IDE_Buffer	;DMA initially to IDE_Buffer
	
	CALL	READSECTOR		;Get sector data from A: drive to buffer

	MOV	AL,1			;Login drive B:
	CALL	SELECT_DRIVE
	
	CALL	WR_LBA			;Update LBA on "B:" drive
	
	MOV	BP,RAM_DMA
	MOV	word [BP],IDE_Buffer2	;DMA initially to IDE_Buffer2
	
	CALL	READSECTOR

	MOV	DI,IDE_Buffer2
	MOV	SI,IDE_Buffer
	MOV	CX,512			;Length of sector in words

NEXT_CMP:
	MOV	AL, [SS:DI]		;Note we have to use SS:
	CMP	AL, [SS:SI]
	JNZ	VER_ERROR
	INC	DI
	INC	SI
	LOOP	NEXT_CMP		;CX will contain count of words done so far, (0 if done OK)
	JMP	VERIFY_OK

VER_ERROR:
	MOV	BX,VERIFY_ERR		;Indicate an error
	CALL	PRINT_STRING
	CALL	SHOW_TRACK_SEC		;Show current location of error
	MOV	BX,DRIVE1_MSG		;'  Drive A',CR,LF
	CALL	PRINT_STRING

	MOV	SI,IDE_Buffer
	MOV	CX,512			;Length of sector in words
VER_SOURCE:	
	MOV	AL, [SS:SI]		;Note we have to use SS:
	CALL	AL_HEXOUT
	INC	SI
	LOOP	VER_SOURCE
	CALL	CRLF
	CALL	SHOW_TRACK_SEC		;Show current location of error
	MOV	BX,DRIVE2_MSG		;'  Drive B',CR,LF
	CALL	PRINT_STRING

	MOV	SI,IDE_Buffer2
	MOV	CX,512			;Length of sector in words
VER_DEST:	
	MOV	AL, [SS:DI]		;Note we have to use SS:
	CALL	AL_HEXOUT
	INC	DI
	LOOP	VER_DEST
	CALL	CRLF
	JMP	VERIFYT			;Do not ask for a continue message here. Just continue
					;If you want it change to VERIFYT1
VERIFY_OK:
	MOV	BP,RAM_SEC		;Get Current Sector
	MOV	AX,[BP]
	OR	AX,AX			;At start of each track give an update
	JNZ	VERIFYT
	
	CALL	SHOW_TRACK

VERIFYT:CALL	CSTS			;Any keyboard character will stop display
	JZ	V_NEXTSEC1
	CALL	CI			;Flush character
VERIFYT1:
	MOV	BX,CONTINUE_MSG
	CALL	PRINT_STRING
	CALL	CICO
	CMP	AL,ESC
	JNZ	V_NEXTSEC1
	JMP	V_NEXTSEC3
V_NEXTSEC1:
	CALL	GET_NEXT_SECT		;Update to next sector/track
	JNZ	V_NEXTSEC2
	JMP	NextVCopy
V_NEXTSEC2:	
	MOV	BX,VerifyDone		;Tell us we are all done.
	CALL	PRINT_STRING
V_NEXTSEC3:
	MOV	AL,0			;Login drive A:
	CALL	SELECT_DRIVE
	MOV	BP,CURRENT_IDE_DRIVE
	MOV	[BP],AL
	RET



	
;------------------ Fill RAM buffer with 0's	

RAMCLEAR:
	MOV	AX,CS
	MOV	DS,AX
	MOV	AX,0
RAM_FILL:				
	MOV	BP,IDE_Buffer	
	MOV	CX,256			;512 bytes total
CLEAR1:	MOV	[BP],AX			;Note this will be SS:BP
	INC	BP
	INC	BP
	LOOP	CLEAR1 

	MOV     BX,FILL_MSG	
	CALL	PRINT_STRING
	RET


;----------------  Power up a Hard Disk

SPINUP:	MOV	DH,COMMANDspinup
spup2:	MOV	DL,REGcommand
	CALL	IDEwr8D
	CALL	IDEwaitnotbusy
	JNB	L_7	
	JMP	SHOWerrors
L_7:	OR	AL,AL			;Clear carry
	RET

	
;-------------------- Tell the Hard disk to power down

SPINDOWN:
	CALL	IDEwaitnotbusy
	JNB	L_8	
	JMP	SHOWerrors
L_8:	MOV	DH,COMMANDspindown
	JMP	spup2


;-------------------- Back to parent 8086 Monitor commands
QUIT_IDE:
	mov	ax,4c00h
	int	21H

;==================== Support Routines FOR IDE MODULE ==================================

;Generate an LBA sector number with data input from CPM style Track# & Sector#

GEN_HEX32_LBA:
	MOV	BX,ENTERRAM_SECL	;Enter sector number, low
	CALL	PRINT_STRING
	CALL	GET2DIGITS		;Get 8 bit value (2 digits) to AL. (BX, CX & DX Unchanged)
	MOV	BP,RAM_SEC
	MOV	[BP],AL			;Note: no check that data is < MAXSEC
	CALL	CRLF

	MOV	BX,ENTERRAM_TRKL	;Enter low byte track number
	CALL	PRINT_STRING
	CALL	GET2DIGITS		;Get 8 bit value (2 digits) to AL. (BX, CX & DX Unchanged)
	MOV	BP,RAM_TRK
	MOV	[BP],AL
	CALL	CRLF

	MOV	BX,ENTERRAM_TRKH	;Enter high byte track number
	CALL	PRINT_STRING
	CALL	GET2DIGITS		;Get 8 bit value (2 digits) to AL. (BX, CX & DX Unchanged)
	MOV	BP,RAM_TRK+1
	MOV	[BP],AL
	XOR	AL,AL
	OR	AL,AL			;To return NC
	RET


DISPLAY_POSITION:			;Display current track,sector & head position
	MOV	BX,msgCPMTRK		;Display in LBA format
	CALL	PRINT_STRING		;---- CPM FORMAT ----
	MOV	BP,RAM_TRK+1
	MOV	AL,[BP]			;High TRK byte
	CALL	AL_HEXOUT
	DEC	BP
	MOV	AL,[BP]			;Low TRK byte
	CALL	AL_HEXOUT

	MOV	BX,msgCPMSEC
	CALL	PRINT_STRING		;SEC = (16 bits)
	MOV	BP,RAM_SEC+1		;High Sec
	MOV	AL,[BP] 	
	CALL	AL_HEXOUT
	DEC	BP
	MOV	AL,[BP]			;Low sec
	CALL	AL_HEXOUT

					;---- LBA FORMAT ----
	MOV	BX,msgLBA
	CALL	PRINT_STRING		;(LBA = 00 (<-- Old "Heads" = 0 for these drives).
	
	MOV	BP,RAM_DRIVE_TRK+1	;High "cylinder" byte
	MOV	AL,[BP]
	CALL	AL_HEXOUT
	DEC	BP
	MOV	AL,[BP]			;Low "cylinder" byte
	CALL	AL_HEXOUT

	MOV	BP,RAM_DRIVE_SEC
	MOV	AL,[BP]
	CALL	AL_HEXOUT
	MOV	BX,MSGBracket		;)$
	CALL	PRINT_STRING
	RET

SHOW_TRACK_SEC:				;Display current (CPM) track,sector
	MOV	BX,msgCPMTRK	
	CALL	PRINT_STRING		;---- CPM FORMAT ----
	MOV	BP,RAM_TRK+1
	MOV	AL,[BP]			;High TRK byte
	CALL	AL_HEXOUT
	DEC	BP
	MOV	AL,[BP]			;Low TRK byte
	CALL	AL_HEXOUT
	MOV	BX,msgCPMSEC
	CALL	PRINT_STRING			
	
	MOV	BP,RAM_SEC		;Low Sec (Only)
	MOV	AX,[BP] 	
	CALL	AL_HEXOUT
	MOV	BX,H_Msg
	CALL	PRINT_STRING
	RET

SHOW_TRACK:
	MOV	BX,msgCPMTRK	
	CALL	PRINT_STRING		;---- CPM FORMAT ----
	MOV	BP,RAM_TRK+1
	MOV	AL,[BP]			;High TRK byte
	CALL	AL_HEXOUT
	MOV	BP,RAM_TRK
	MOV	AL,[BP]			;Low TRK byte
	CALL	AL_HEXOUT
	MOV	BX,OK_CR_MSG	
	CALL	PRINT_STRING		;---- CPM FORMAT ----
	RET


DISPLAY_SEC:				;Print a DISPLAY_SEC of the data in the 512 byte IDE_Buffer (RAM_DMA)
	CALL	CRLF			;Note written so it can be easily converted to a "normal: DS: based" routine
	MOV	BP,RAM_DMA		;Get Current DMA Address
	MOV	SI,[BP]			;Both DS:DI & SI point to buffer
	MOV	DI,SI
	MOV	DH,32			;print 32 lines
	
SF172:	CALL	CRLF
	call	SHOW_ADDRESS_SS		;Show SS:SI
	mov	cx,2			;send 2 spaces
	call	TABS
	MOV	DL,16			;32 characters across
SF175:	MOV	AL,[SS:SI]
	CALL	AL_HEXOUT		;Display A on CRT/LCD
	MOV	AL,'~'
	CALL	CO
	INC	SI
	DEC	DL
	JNZ	SF175

	mov	cx,3			;first send 3 spaces
	call	TABS
	
	MOV	DL,16			;24 across again
Sloop2:	mov	al,[SS:DI]		
	and	al,7fh
	cmp	al,' '			;filter out control characters
	jnc	Sloop3
Sloop4:	mov	al,'.'
Sloop3:	cmp	al,'~'
	jnc	Sloop4
	mov	cl,al
	call	CO
	INC	DI
	DEC	DL
	JNZ	Sloop2
	DEC	DH
	JNZ	SF172			;--DH has total byte count
	CALL	CRLF
	ret



;Point to next sector.  Ret Z if all OK	NZ if at end of disk
GET_NEXT_SECT:	
	MOV	BP,RAM_SEC		;Get Current Sector
	MOV	AX,[BP]
	INC	AX
	MOV	[BP],AX			;0 to MAXSEC CPM Sectors
	CMP	AX,MAXSEC-1		;Assumes < 255 sec /track
	JNZ	NEXT_SEC_DONE
	
	MOV	AX,0			;Back to CPM sector 0
	MOV	[BP],AX
	
	MOV	BP,RAM_TRK		;Bump to next track
	MOV	AX,[BP]
	INC	AX
	CMP	AX,100H			;Tracks 0-0FFH only
	JZ	AT_DISK_END
	MOV	[BP],AX
NEXT_SEC_DONE:
	CALL	WR_LBA			;Update the LBC pointer
	XOR	AX,AX
	RET				;Ret z if all OK
AT_DISK_END:
	XOR	AX,AX
	DEC	AX
	RET	
	


;Point to previous sector.  Ret Z if all OK	
GET_PREV_SECT:	
	MOV	BP,RAM_SEC		;Get Current Sector
	MOV	AX,[BP]
	CMP	AX,0
	JZ	PREVIOUS_TRACK
	DEC	AX
	MOV	[BP],AX			;0 to MAXSEC CPM Sectors
	JMP	PREVIOUS_SEC_DONE

PREVIOUS_TRACK:	
	MOV	AX,MAXSEC-1		;Back to CPM last sector on previous track
	MOV	[BP],AX
	
	MOV	BP,RAM_TRK		;Bump to next track
	MOV	AX,[BP]
	CMP	AX,0			;If On track 0 already then problem
	JNZ	AT_00
	DEC	AX
	MOV	[BP],AX
PREVIOUS_SEC_DONE:
	CALL	WR_LBA			;Update the LBC pointer
	XOR	AX,AX			;Return Z if all OK
	RET
AT_00:	MOV	BX,ATHOME_MSG
	CALL	PRINT_STRING
	XOR	AX,AX
	DEC	ax			;NZ if problem
	RET

;
SHOWerrors:
	CALL	CRLF
	MOV	DL,REGstatus		;Get status in status register
	CALL	IDErd8D
	MOV	AL,DH
	AND	AL,1H
	JNZ	MoreError		;Go to  REGerr register for more info
					;All OK if 01000000
					
	PUSHF				;<<< Save for return below
	AND	AL,80H
	JZ	NOT7
	MOV	BX,DRIVE_BUSY		;Drive Busy (bit 7) stuck high.   Status = 
	CALL	PRINT_STRING
	JMP	DONEERR
	
NOT7:	AND	AL,40H
	JNZ	NOT6
	MOV	BX,DRIVE_NOT_READY	;Drive Not Ready (bit 6) stuck low.  Status = 
	CALL	PRINT_STRING
	JMP	DONEERR
	
NOT6:	AND	AL,20H
	JNZ	NOT5
	MOV	BX,DRIVE_WR_FAULT	;Drive write fault.    Status =
	CALL	PRINT_STRING
	JMP	DONEERR
	
NOT5:	MOV	BX,UNKNOWN_ERROR
	CALL	PRINT_STRING
	JMP	DONEERR

MoreError:				;Get here if bit 0 of the status register indicted a problem
	MOV	DL,REGerr		;Get error code in REGerr
	CALL	IDErd8D
	MOV	AL,DH
	PUSHF				;<<<< Save flags for below

	AND	AL,10H
	JZ	NOTE4
	MOV	BX,SEC_NOT_FOUND
	CALL	PRINT_STRING
	JMP	DONEERR

NOTE4:	AND	AL,80H
	JZ	NOTE7
	MOV	BX,BAD_BLOCK
	CALL	PRINT_STRING
	JMP	DONEERR

NOTE7:	AND	AL,40H
	JZ	NOTE6
	MOV	BX,UNRECOVER_ERR
	CALL	PRINT_STRING
	JMP	DONEERR

NOTE6:	AND	AL,4H
	JZ	NOTE2
	MOV	BX,INVALID_CMD
	CALL	PRINT_STRING
	JMP	DONEERR

NOTE2:	AND	AL,2H
	JZ	NOTE1
	MOV	BX,TRK0_ERR
	CALL	PRINT_STRING
	JMP	DONEERR

NOTE1:	MOV	BX,UNKNOWN_ERROR1
	CALL	PRINT_STRING
	JMP	DONEERR

DONEERR:POPF				;>>>>> get back flags
	PUSH	AX
	CALL	AL_BINOUT		;Show error bit pattern
	CALL	CRLF
	POP	AX
	XCHG	AL,AH
	OR	AL,AL			;Set Z flag
	STC				;Set Carry flag
	RET


;================================================================================================
; IDE Drive BIOS Routines written in a format that can be used with CPM86 (Note MSDOS/DOS has its own 
; modules see further below. However instead of using DS:[BX] (as we do in the CPM86 BIOS), throughout we 
; will use SS:[BP] so the the buffers can reside at the top segment of available RAM. 
; Normally this will be D000:E000H  (below the ROM) but the monitor will not assume that there is a 
; full 1MG address space avalable and may put them lower.  See monitor initilization code at start.
;================================================================================================

IDEinit:				;Initilze the 8255 and drive then do a hard reset on the drive, 
					;By default the drive will come up initilized in LBA mode.
	MOV	AL,READcfg8255		;10010010b
	OUT	IDECtrlPort,AL		;Config 8255 chip, READ mode
	
	MOV	AL,IDErstline
	OUT	IDEportC,AL		;Hard reset the disk drive
	
	MOV	CH,IDE_Reset_Delay	;;Time delay for reset/initilization (~66 uS, with 8MHz 8086, 1 I/O wait state)
ResetDelay:
	DEC	CH
	JNZ	ResetDelay		;Delay (IDE reset pulse width)
	XOR	AL,AL
	OUT	IDEportC,AL		;No IDE control lines asserted

	CALL	DELAY_SHORT		;Allow time for CF/Drive to recover
	
	MOV	DH,11100000b		;Data for IDE SDH reg (512bytes, LBA mode,single drive,head 0000)
;	MOV	DH,10100000b		;For Trk,Sec,head (non LBA) use 10100000 (This is the mode we use for MSDOS)
					;Note. Cannot get LBA mode to work with an old Seagate Medalist 6531 drive.
					;have to use the non-LBA mode. (Common for old hard disks).
	MOV	DL,REGshd		;00001110,(0EH) for CS0,A2,A1,  
	CALL	IDEwr8D			;Write byte to select the MASTER device



	MOV	CH,03H			;<<< May need to adjust delay time
WaitInit:
	MOV	DL,REGstatus		;Get status after initilization
	CALL	IDErd8D			;Check Status (info in [DH])
	MOV	AL,DH
	AND	AL,80H
	JZ	DoneInit		;Return if ready bit is zero
	CALL	DELAY_LONG		;Long delay, drive has to get up to speed
	DEC	CH
	JNZ	WaitInit
	XOR	AL,AL
	DEC	AL
	RET				;Return NZ. Well check for errors when we get back
DoneInit:
	RET				;Return Z indicating all is well


DELAY_LONG:				;Long delay (Seconds) for hard disk to get up to speed
	PUSH	CX
	PUSH	DX
	MOV	CX,0FFFFH
DELAY2:	MOV	DH,2			;May need to adjust delay time to allow cold drive to
DELAY1:	DEC	DH			;to speed
	JNZ	DELAY1
	DEC	CX
	JNZ	DELAY2
	POP	DX
	POP	CX
	RET
	
	
DELAY_SHORT: 
	MOV	AX,8000H		;DELAY ~32 MS (DOES NOT SEEM TO BE CRITICAL)
DELAY3:	DEC	AX
	JNZ     DELAY3 
	RET
	
	
					;Read a sector, specified by the 4 bytes in LBA
					;Z on success, NZ call error routine if problem
READSECTOR:
	CALL	WR_LBA			;Tell which sector we want to read from.
					;Note: Translate first in case of an error otherewise we 
					;will get stuck on bad sector 
	CALL	IDEwaitnotbusy		;make sure drive is ready
	JNB	L_19	
	JMP	SHOWerrors		;Returned with NZ set if error
	
L_19:	MOV	DH,COMMANDread
	MOV	DL,REGcommand
	CALL	IDEwr8D			;Send sec read command to drive.
	CALL	IDEwaitdrq		;wait until it's got the data
	JNB	L_20	
	JMP	SHOWerrors

L_20:	MOV	BP,RAM_DMA		;Get Current DMA Address at SS:RAM_DMA
	MOV	AX,[BP]			;Note SS: is assumed here
	MOV	BP,AX
	MOV	CH,0			;Read 512 bytes to [HL] (256X2 bytes)

MoreRD16:
	MOV	AL,REGdata		;REG regsiter address
	OUT	IDEportC,AL
	
	OR	AL,IDErdline		;08H+40H, Pulse RD line
	OUT	IDEportC,AL
	
	IN	AL,IDEportA		;Read the lower byte first 
	MOV	[BP],AL	
	INC	BP
	IN	AL,IDEportB		;THEN read the upper byte
	MOV	[BP],AL
	INC	BP
	
	MOV	AL,REGdata		;Deassert RD line
	OUT	IDEportC,AL
	DEC	CH
	JNZ	MoreRD16
	
	MOV	DL,REGstatus
	CALL	IDErd8D
	MOV	AL,DH
	AND	AL,1H
	JZ	L_21	
	CALL	SHOWerrors		;If error display status
L_21:	RET


					;Write a sector, specified by the 3 bytes in LBA (_ IX+0)",
					;Z on success, NZ to error routine if problem
WRITESECTOR:
	CALL	WR_LBA			;Tell which sector we want to read from.
					;Note: Translate first in case of an error otherewise we 
					;will get stuck on bad sector 
	CALL	IDEwaitnotbusy		;make sure drive is ready
	JNB	L_22	
	JMP	SHOWerrors
	
L_22:	MOV	DH,COMMANDwrite
	MOV	DL,REGcommand
	CALL	IDEwr8D			;tell drive to write a sector
	CALL	IDEwaitdrq		;wait unit it wants the data
	JNB	L_23	
	JMP	SHOWerrors
	
L_23:	MOV	BP, RAM_DMA		;Get Current DMA Address
	MOV	AX,[BP]
	MOV	BP,AX
	MOV	CH,0			;256X2 bytes
	
	MOV	AL,WRITEcfg8255
	OUT	IDECtrlPort,AL
	
WRSEC1_IDE:
	MOV	AL,[BP]
	INC	BP
	OUT	IDEportA,AL		;Write the lower byte first 
	MOV	AL,[BP]	
	INC	BP
	OUT	IDEportB,AL		;THEN High byte on B

	MOV	AL,REGdata
	PUSH	AX
	OUT	IDEportC,AL		;Send write command
	OR	AL,IDEwrline		;Send WR pulse
	OUT	IDEportC,AL
	POP	AX
	OUT	IDEportC,AL		;Send write command
	DEC	CH
	JNZ	WRSEC1_IDE
	
	MOV	AL,READcfg8255		;Set 8255 back to read mode
	OUT	IDECtrlPort,AL
	
	MOV	DL,REGstatus
	CALL	IDErd8D
	MOV	AL,DH
	AND	AL,1H
	JZ	L_24	
	CALL	SHOWerrors		;If error display status
L_24:	RET

				
WR_LBA:					;Write the logical block address to the drive's registers
					;Note we do not need to set the upper nibble of the LBA
					;It will always be 0 for these small CPM drives (so no High Cylinder
					;numbers etc).
	MOV	BP,RAM_SEC
	MOV	AX,[BP]			;LBA mode, Low sectors go directly 
	INC	AX			;Sectors are numbered 1 -- MAXSEC (even in LBA mode)
	MOV	BP,RAM_DRIVE_SEC
	MOV	[BP],AL			;For Diagnostic Diaplay Only
	MOV	DH,AL
	MOV	DL,REGsector		;Send info to drive
	CALL	IDEwr8D			;Write to 8255 A Register
					;Note: For drive we will have 0 - MAXSEC sectors only
					
	MOV	BP,RAM_TRK
	MOV	AX,[BP]
	MOV	BP,RAM_DRIVE_TRK				
	MOV	[BP],AL
	MOV	DH,AL			;Send Low TRK#
	MOV	DL,REGcylinderLSB
	CALL	IDEwr8D			;Write to 8255 A Register
	
	MOV	BP,RAM_DRIVE_TRK+1
	MOV	[BP],AH
	MOV	DH,AH			;Send High TRK#
	MOV	DL,REGcylinderMSB
	CALL	IDEwr8D			;Send High TRK# (in DH) to IDE Drive
	CALL	IDEwr8D_X		;Special write to 8255 B Register (Not A) to update LED HEX Display 
					;High 8 bits ignored by IDE drive
	
	MOV	DH,1			;For CPM, one sector at a time
	MOV	DL,REGseccnt
	CALL	IDEwr8D			;Write to 8255 A Register
	RET
 	
						;Special version for MS-DOS system BIOS (see IBM BIOS Section)
DOS_WR_LBA:					;This will display Head, Cylinder and Sector on the LED HEX display
						;instead of LBA sector numbers.
	MOV	DH,[CURRENT_HEAD]		;OR in head info to lower 4 bits
	AND	DH,0FH				;Just in case
	OR	DH,10100000B			;Set to >>>>> NON-LBA mode <<<<<
	MOV	DL,REGshd			;Send "Head #" (in DH) to IDE drive
	CALL	IDEwr8D				

	MOV	DH,[CURRENT_TRACK_HIGH]		;Send High TRK#
	MOV	DL,REGcylinderMSB
	CALL	IDEwr8D				;Send High TRK# (in DH) to IDE Drive

	MOV	DH,[CURRENT_HEAD]		;Get head info to lower 8 bits of the special
	AND	DH,0FH				;top two LED HEX displays. 
	SHL	DH,1				;These 8 (high) data lines are ignored by the IDE drive
	SHL	DH,1
	SHL	DH,1
	SHL	DH,1
	OR	DH,[CURRENT_TRACK_HIGH]		;Will display  the Head in top nibble and the two bits of the HIGH bits 
	MOV	DL,REGcylinderMSB		;of the high cylinder in the low nibble.
	CALL	IDEwr8D_X			;Special output to 8255 B Register (Not A) to update LED HEX Display ONLY
						
	MOV	DH,[CURRENT_TRACK]		;Get low Track # 
	MOV	DL,REGcylinderLSB		;Send Low TRK# (in DH)
	CALL	IDEwr8D				;Special write to 8255 B Register (Not A) 
	
	MOV	DH,[CURRENT_SECTOR]		;Bits 0-5 only  (currently 1-17)
	MOV	DL,REGsector			;Send "Sector#" 
	CALL	IDEwr8D				;Write to 8255 A Register

	MOV	DH,[SECTORS_TO_DO]		;# of CONTIGOUS sectors to send
	MOV	DL,REGseccnt
	CALL	IDEwr8D				;Write to 8255 A Register
	RET



IDEwaitnotbusy:				;Drive READY if 01000000
	MOV	CH,0FFH
	MOV	AH,0FFH			;Delay, must be above 80H for 4MHz Z80. Leave longer for slower drives
	PUSH	BX			;AH is not changed in IDErd8D below
MoreWait:
	MOV	DL,REGstatus		;wait for RDY bit to be set
	CALL	IDErd8D			;Note AH or CH are unchanged
	MOV	AL,DH
	AND	AL,11000000B
	XOR	AL,01000000B
	JZ	DONE_NOT_BUSY
	DEC	CH
	JNZ	MoreWait
	DEC	AH
	JNZ	MoreWait
	STC				;Set carry to indicate an error
	POP	BX
	RET
DONE_NOT_BUSY:
	OR	AL,AL			;Clear carry it indicate no error
	POP	BX
	RET
	
	
					;Wait for the drive to be ready to transfer data.
IDEwaitdrq:				;Returns the drive's status in Acc
	MOV	CH,0FFH
	MOV	AL,0FFH			;Delay, must be above 80H for 4MHz Z80. Leave longer for slower drives
	PUSH	BX
MoreDRQ:
	MOV	DL,REGstatus		;wait for DRQ bit to be set
	CALL	IDErd8D			;Note AH or CH are unchanged
	MOV	AL,DH
	AND	AL,10001000B
	CMP	AL,00001000B
	JZ	DoneDRQ
	DEC	CH
	JNZ	MoreDRQ
	DEC	AH
	JNZ	MoreDRQ
	STC				;Set carry to indicate error
	POP	BX
	RET
DoneDRQ:
	OR	AL,AL			;Clear carry
	POP	BX
	RET
	
	
CLEAR$ID$BUFFER:			;Clear the ID Buffer area
	MOV	AX,2020H		;Clear to spaces
	MOV	BP,IDE_Buffer		;Remember CS: = SS
	MOV	CX,256			;512 bytes total
CLEAR2:	MOV	[BP],AX			;Note this will be SS:[BP]
	INC	BP
	INC	BP
	LOOP	CLEAR2 

	MOV	AX,0H			;Put in 0's for cylinder,heads,sectors etc
	MOV	BP,IDE_Buffer	
	MOV	CX,7			;14 bytes total
CLEAR3:	MOV	[BP],AX			;Note this will be SS:[BP]
	INC	BP
	INC	BP
	LOOP	CLEAR3 
	RET
	


;------------------------------------------------------------------
; Low Level 8 bit R/W to the drive controller.  These are the routines that talk
; directly to the drive controller registers, via the 8255 chip.  
; Note the 16 bit Sector I/O to the drive is done directly 
; in the routines READSECTOR & WRITESECTOR for speed reasons.

IDErd8D:				;READ 8 bits from IDE register @ [DL], return info in [DH]
	MOV	AL,DL			;select IDE register
	OUT	IDEportC,AL		;drive address onto control lines
	
	OR	AL,IDErdline		;RD pulse pin (40H)
	OUT	IDEportC,AL		;Assert read pin
	
	IN	AL,IDEportA
	MOV	DH,AL			;return with data in [DH]
	
	MOV	AL,DL			;<---Ken Robbins suggestion
	OUT	IDEportC,AL		;Drive address onto control lines

	XOR	AL,AL			
	OUT	IDEportC,AL		;Zero all port C lines
	RET


IDEwr8D:				;WRITE Data in [DH] to IDE register @ [DL]
	MOV	AL,WRITEcfg8255		;Set 8255 to write mode
	OUT	IDECtrlPort,AL
	
	MOV	AL,DH			;Get data put it in 8255 A port
	OUT	IDEportA,AL
	
	MOV	AL,DL			;select IDE register
	OUT	IDEportC,AL
	
	OR	AL,IDEwrline		;lower WR line
	OUT	IDEportC,AL
	
	MOV	AL,DL			;<-- Ken Robbins suggestion, raise WR line
	OUT	IDEportC,AL		;deassert RD pin

	XOR	AL,AL			;Deselect all lines including WR line
	OUT	IDEportC,AL
	
	MOV	AL,READcfg8255		;Config 8255 chip, read mode on return
	OUT	IDECtrlPort,AL
	RET


IDEwr8D_X:				;WRITE Data in [DH] to IDE register @ [DL]
	MOV	AL,WRITEcfg8255		;Set 8255 to write mode
	OUT	IDECtrlPort,AL
	
	MOV	AL,DH			;Get data and put it in 8255 >>>> Port B <<<< 
	OUT	IDEportB,AL
	
	MOV	AL,DL			;select IDE register
	OUT	IDEportC,AL
	
	OR	AL,IDEwrline		;lower WR line
	OUT	IDEportC,AL
	
	MOV	AL,DL			;<-- Ken Robbins suggestion, raise WR line
	OUT	IDEportC,AL		;Deassert RD pin

	XOR	AL,AL			;Deselect all lines including WR line
	OUT	IDEportC,AL
	
	MOV	AL,READcfg8255		;Config 8255 chip, read mode on return
	OUT	IDECtrlPort,AL
	RET


;	BX_HEXOUT			;bx output as 4 hex digits
BX_HEXOUT:				;No registers altered	
	push	ax
	mov	al,bh
	call	AL_HEXOUT
	mov	al,bl
	call	AL_HEXOUT
	pop	ax
	ret


;	AX_HEXOUT			;output the 4 hex digits in [AX]
AX_HEXOUT:				;No registers altered	
	PUSH	AX
	MOV	AL,AH
	CALL	AL_HEXOUT
	POP	AX
	CALL	AL_HEXOUT
	RET



;	AL_HEXOUT			;output the 2 hex digits in [AL]
AL_HEXOUT:				;No registers altered (except AL)
	push	cx
	push	ax
	mov	cl,4			;first isolate low nibble
	shr	al,cl
	call	hexdigout
	pop	ax
	call	hexdigout		;get upper nibble
	pop	cx
	ret

hexdigout: 
	and	al,0fh			;convert nibble to ascii
	add	al,90h
	daa
	adc	al,40h
	daa
	mov	cl,al
	call	CO
	ret

;   ROUTINE TO PRINT A STRING   CS:BX = START OF STRING  $ or 0 = FINISH
PRINT_STRING:	
	push	cx
print1:	mov	al,[CS:bx]		;Note this routine does NOT assume DS = CS here.
	inc	bx			;By using the CS over-ride we will always have
	cmp	al,'$'			;a valid pointer to messages at the end of this monitor
	jz	print2
	cmp	AL,0			;Also terminate with 0's
	JZ	print2
	mov	cl,al
	call	CO
	jmp	print1
print2:	pop	cx
	ret

	;	SIMPLE SEND CRLF
CRLF:	
	mov	bx,CRLFSTR
	call	PRINT_STRING
	ret

;	PRINT A BLANK SPACE
BLANK:	push	cx
	mov	cx,1
	call	TABS
	pop	cx
	ret


;	TABS				;[cx] = number of spaces
TABS:	push	cx
	mov	cl,' '
	call	CO
	pop	cx
	loop	TABS
	ret

;<<<<<<<<<<<<<<<<<<<<<< MAIN CONSOL OUTPUT ROUTINE >>>>>>>>>>>>>>>>>>>>>>>>>
CO:	
	push	dx
	mov	dl,cl
	mov	ah,2		; direct output
	int	21H
	pop	dx
	ret

DELAY:	DEC	AL			;GENERAL COUNT DOWN TIME DELAY
	JNZ	LX4	
	RET				;LENGTH SET IN [A]
LX4:	PUSH	AX
	MOV	AL,05H
MORE:	DEC	AL
	PUSH	AX
	XOR	AL,AL
MORE2:	DEC	AL
	JNZ	MORE2
	POP	AX
	JNZ	MORE
	POP	AX
	JMP	DELAY

;<<<<<<<<<<<<<<<<<< MAIN CONSOL STATUS ROUTINE >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
CSTS:	
	mov	ah,0bh
	int	21h	
	RET		; 0= no char; FF=something


;<<<<<<<<<<<<<<<<<<<< MAIN CONSOL INPUT ROUTINE >>>>>>>>>>>>>>>>>>>>
CI:	
	mov	ah,8		; blocks waiting for character
	int 	21H
	AND	AL,7FH
	RET

;<<<<<<<<<<<<<<< CONSOLE INPUT WITH ECHO ON CONSOLE + LC->UC  <<<<<<<<<<<<
CICO:	CALL	CI			;Char -> AL
	AND	AL,7FH
	JZ	BAD_CHAR		;No Nulls
	CMP	AL,','			;Allow "," character
	JZ	CIC1
	CMP	AL,CR			;ACCEPT ONLY CR,LF,SP
	JZ	CIC1
	CMP	AL,LF
	JZ	CIC1
	CMP	AL,SPACE
	JZ	CIC1
	CMP	AL,ESC			;Also ESC
	JZ	CIC1

	CMP	AL,'0'
	JB	BAD_CHAR
	CMP	AL,':'			;Allow 0-9
	JB	CIC1
	CMP	AL,'A'
	JB	BAD_CHAR		;do not allow : to @
	CMP	AL,'['			;Is upper case A to Z
	JB	CIC1
	CMP	AL,'a'
	JB	BAD_CHAR
	CMP	AL,'{'
	JB	UPPER_CASE
	JMP	BAD_CHAR
UPPER_CASE:
	AND	AL,5FH			;THIS CONVERTS ALL LC->UC
CIC1:	PUSH	AX
	PUSH	CX
	MOV	CL,AL
	CALL	CO			;DISPLAY ON CONSOLE
	POP	CX
	POP	AX
	RET
;
BAD_CHAR:
	MOV	AL,BELL			;SEND BELL TO INDICATE BAD DATA
	CALL	CIC1
	MOV	AL,'?'			;SEND ? TO INDICATE BAD DATA
	JMP	CIC1


;  Send to console the address SS+SI	;Used (Only) by sector display routine. CX Unchanged

SHOW_ADDRESS_SS:
	push	cx			;Same but send upper nibble of ds reg
	mov	ax,ss
	mov	cl,12
	shr	ax,cl			;Get high nibble down to AL
	call	hexdigout
	MOV	BX,SI
	call	BX_HEXOUT		;Then next 4 digits in BX
	call	BLANK
	pop	cx
	ret


;	Get 8 bit value (2 digits) to AL. (BX, CX & DX Unchanged), terminator in AH - normally 0

GET2DIGITS:
	PUSH	BX
	PUSH	CX
	mov	bx,0			;Default to 0H		

	call	CICO			;1st Console input digit to AL
	cmp	al,'0'			;alphanumeric?
	jb	bexit2
	call	HEX_check		;convert to binary and check it
	jb	err2
	add	bl,al			;Move into BX
	mov	cl,4
	shl	bx,cl			;shift in last addition to high nibble on BL
	
	push	BX			;Just in case
	call	CICO			;2nd Console input digit to AL
	pop	BX
	
	cmp	al,'0'			;alphanumeric?
	jb	bexit2
	call	HEX_check		;convert to binary and check it
	jb	err2
	add	bl,al			;Move into BX
	MOV	AL,BL
	MOV	AH,0			;Ret 0 in AH if all OK
	POP	CX
	POP	BX
	ret
	
err2:	POP	CX			;Cleanup stack
	POP	BX
	JMP	ERROR			;Then normal error exit	

bexit2:	cmp	al,' '			;save terminator, if SP,CR accept only 1 digit
	je	bgood2
	cmp	al,','
	je	bgood2
	cmp	al,CR
	je	bgood2
	cmp	al,ESC
	je	bgood2
	POP	CX			;Cleanup stack
	POP	BX
	JMP	ERROR			;Then normal error exit	
		
bgood2:	mov	ah,al			;Save SP,",' or CR in AH			
	MOV	BH,0			
	mov	cl,4
	shr	bx,cl			;shift down last addition to low nibble on BL
	MOV	AL,BL
	POP	CX
	POP	BX
	ret

;	Get (up to) 16 bit value (4 digits) to DI. Termination byte in AH

GET4DIGITS:
	PUSH	BX
	PUSH	CX
	MOV	CX,5			;4 characters mnaximum + CR			
	mov	bx,0			
loop4b:	call	CICO			;Console input to AL
	cmp	al,'0'			;alphanumeric?
	jb	bexit
	push	cx
	mov	cl,4
	shl	bx,cl			;shift in last addition
	pop	cx
	call	HEX_check		;convert [AL] to binary and check it
	jb	AddressError
	add	bl,al
	loop	loop4b
	MOV	DI,BX
	POP	CX
	POP	BX
	ret				;Will return BX = xxxxH

;	Get (up to) 20 bit parameter. 16 bit value (4 digits) to DI. 
;	If 5 digits, first digit entered to ES (BX,CX, DX unaltered)

GET5DIGITS:				;Will return ES=000xH, DI = xxxxH
	PUSH	BX
	PUSH	CX
	mov	cx,6			;Max count of 5 characters + CR				
	mov	bx,0			;So initially ES=0, see below
loopb:	call	CICO			;Console input to AL
	cmp	al,'0'			;alphanumeric?
	jb	bexit
	
	push	cx			;Save character count
	push	bx			;force the highest nibble to ds:
	and	bx,0f000h
	mov	es,bx
	pop	bx
	mov	cl,4
	shl	bx,cl			;shift in last addition
	pop	cx
	call	HEX_check		;convert to binary and check it
	jb	AddressError
	add	bl,al
	loop	loopb			;Do up to 5 characters
	
bexit:	MOV	DI,BX			;Move data to DI
	cmp	al,' '			;Terminate with a SP, "," or CR only
	je	bgood
	cmp	al,','
	je	bgood
	cmp	al,CR
	je	bgood
	jmp	ERROR
bgood:	mov	ah,al			;Save terminator
	POP	CX			;Balance up stack
	POP	BX
	ret

AddressError:
	MOV	BX,AddressErrMsg	;Range error
	CALL	PRINT_STRING
	jmp	ABORT

;	BINARY OUTPUT			;Send what is in [al] in bits
AL_BINOUT:				;No registers altered (except AL)
	push	cx
	mov	cx,8
binout1: push	cx
	shl	al,1
	jb	bout1
	mov	cl,'0'
	push	ax
	call	CO
	pop	ax
	jmp	binend
bout1:	mov	cl,'1'
	push	ax
	call	CO
	pop	ax
binend:	pop	cx
	loop	binout1
	pop	cx
	ret


;	HEXCHK				;check for a valid HEX DIGIT
HEX_check:	
	sub	al,'0'			;convert to binary if ok set carry if problem
	jb	hret
	cmp	al,0ah
	cmc	
	jnb	hret
	sub	al,7
	cmp	al,10
	jb	hret
	cmp	al,16
	cmc
hret:	ret


CRLFSTR		db	CR,LF,'$'
SIGNON		db	CR,LF,LF,'Standalone IDE Test Program for T186',CR,LF,'$'
IDE_SIGNON0	DB	CR,LF,LF,'IDE HDisk Test Menu Routines.  $'
IDE_SIGNON4	DB	'A=Select Drive A  B=Select Drive B  C=Boot CPM   D=Set Sec Display $'
IDE_SIGNON1	DB	'On',CR,LF,'$'
IDE_SIGNON2	DB      'Off',CR,LF,'$'

IDE_SIGNON3	DB	'E=Clear Sec Buff  F=Format Disk     I=Next Sec   J=Previous Sec',CR,LF
		DB	'L=Set LBA Value   N=Power Down      O=Disk ID    Q=LBA Display Test',CR,LF
		DB	'R=Read Sector     S=Seq Sec Rd      U=Power Up   V=Read N Sectors',CR,LF
		DB	'W=Write Sector    X=Write N Sectors Y=Copy A->B  Z=Verify A=B',CR,LF
		DB	'(ESC) Back to Main Menu',CR,LF
		DB	LF,'Current settings:- $'

IDE_MENU	DB	'Enter a Command:- $'
IDE_HARDWARE	DB	CR,LF,'Initilizing IDE Board, one moment please...',CR,LF,'$'
		
INIT_1_ERROR	DB	CR,LF,'Initilizing of First Drive failed. Aborting Command.',BELL,CR,LF,LF,'$'
INIT_2_ERROR	DB	CR,LF,'Initilizing of Second Drive failed. (Possibly not present).',BELL,CR,LF,LF,'$'
BAD_DRIVE:	DB	CR,LF,'First Drive ID Infornmation appears invalid. '
		DB	'(Drive possibly not present).',CR,LF
		DB	'Aborting Command.',BELL,CR,LF,LF,'$'

msgmdl		DB	CR,LF,'Drive/CF Card Information:-',CR,LF
		DB	'Model: $'
msgsn		DB	'S/N:   $'
msgrev		DB	'Rev:   $'
msgcy		DB	'Cylinders: $'
msghd		DB	', Heads: $'
msgsc		DB	', Sectors: $'
msgCPMTRK	DB	'CPM TRK = $'
msgCPMSEC	DB	' CPM SEC = $'
msgLBA		DB	'  (LBA = 00$'
MSGBracket	DB	')$'
H_Msg		DB	'H$'
H_MSG_CRLF	DB	'H',CR,LF,'$'
NotDoneYet	DB	CR,LF,'Command Not Done Yet$'
CONFIRM_WR_MSG	DB	CR,LF,LF,BELL,'Will erase data on the current drive, '
		DB	'are you sure? (Y/N)...$'
msgrd		DB	'Sector Read OK',CR,LF,'$'
msgwr		DB	'Sector Write OK',CR,LF,'$'
SET_LBA_MSG	DB	'Enter CPM style TRK & SEC values (in hex).',CR,LF,'$'
SEC_RW_ERROR	DB	'Drive Error, Status Register = $'
ERR_REG_DATA	DB	'Drive Error, Error Register = $'
ENTERRAM_SECL	DB	'Starting sector number,(xxH) = $'
ENTERRAM_HEAD	DB	'Starting HEAD number,(xxH) = $'
ENTERRAM_FTRKL	DB	'Enter Starting Track number,(xxH) = $'
ENTERRAM_TRKL	DB	'Track number (LOW byte, xxH) = $'
ENTERRAM_TRKH	DB	'Track number (HIGH byte, xxH) = $'
ENTER_HEAD	DB	'Head number (01-0f) = $'
ENTER_COUNT	DB	'Number of sectors to R/W (xxH) = $'
ENTERRAM_DMA	DB	'Enter DMA Adress (Up to 5 digits, xxxxxH) = $'
OVER_COUNT_10	DB	CR,LF,'1 & 9 sectors. Only!',CR,LF,'$'
OVER_COUNT_19	DB	CR,LF,'1 & 18 sectors. Only!',CR,LF,'$'
DRIVE_BUSY	DB	'Drive Busy (bit 7) stuck high.   Status = $'
DRIVE_NOT_READY DB	'Drive Ready (bit 6) stuck low.  Status = $'
DRIVE_WR_FAULT	DB	'Drive write fault.    Status = $'
UNKNOWN_ERROR	DB	'Unknown error in status register.   Status = $'
BAD_BLOCK	DB	'Bad Sector ID.    Error Register = $'
UNRECOVER_ERR	DB	'Uncorrectable data error.  Error Register = $'
READ_ID_ERROR	DB	'Error setting up to read Drive ID',CR,LF,'$'
SEC_NOT_FOUND	DB	'Sector not found. Error Register = $'
INVALID_CMD	DB	'Invalid Command. Error Register = $'
TRK0_ERR	DB	'Track Zero not found. Error Register = $'
UNKNOWN_ERROR1	DB	'Unknown Error. Error Register = $'
CONTINUE_MSG	DB	CR,LF,'To Abort enter ESC. Any other key to continue. $'
FORMAT_MSG_A	DB	'Fill disk sectors of Disk [A] with 0E5H$'
FORMAT_MSG_B	DB	'Fill disk sectors of Disk [B] with 0E5H$'
DRIVE1_MSG	DB	'  on Drive A',CR,LF,'$'
DRIVE2_MSG	DB	'  on Drive B',CR,LF,'$'
ATHOME_MSG	DB	CR,LF,BELL,'Already on Track 0, Sector 0$'
AT_START_MSG	DB	CR,LF,BELL,'Already at start of disk!$'
AT_END_MSG	DB	CR,LF,BELL,'At end of Disk!$'
FILL_MSG	DB	CR,LF,'Sector buffer area cleared to 0000....$'
READN_MSG	DB	CR,LF,'Read multiple sectors from current disk/CF card to RAM buffer.'
		DB	CR,LF,'How many 512 byte sectores (xx HEX):$'
WRITEN_MSG	DB	CR,LF,'Write multiple sectors RAM buffer CURRENT disk/CF card.'
		DB	CR,LF,'How many 512 byte sectores (xx HEX):$'
READN_S_MSG	DB	CR,LF,'Read Sector to RAM buffer. $'
WRITEN_S_MSG	DB	CR,LF,'Write Sector from RAM buffer. $'

DiskCopyMsg	DB	CR,LF,'Copy CPM Partition on Drive A to Drive B (Y/N)? $'
DiskVerifyMsg	DB	CR,LF,'Will verify CPM Partition on Drive A to Drive B.$'
CopyDone	DB	CR,LF,'Disk Copy Done.$'
VERIFY_ERR	DB	CR,LF,BELL,'Verify Error. $'
VerifyDone	DB	CR,LF,'Disk Verify Done.$'
CR_To_Continue	DB	CR,LF,'Hit any key to continue.$'
OK_CR_MSG	DB	' OK',CR,LF,'$'
COPY_ERR	DB	CR,LF,BELL,'Sector Copy Error.$'
CURRENT_MSG_A	DB	'   <<<<< Current Drive = [A] >>>>>',CR,LF,LF,'$'
CURRENT_MSG_B	DB	'   <<<<< Current Drive = [B] >>>>>',CR,LF,LF,'$'
FORMAT_ERR	DB	CR,LF,BELL,'Sector Format Error$'
ERR_MSG		DB	CR,LF,BELL,'Invalid Command (or code not yet done)',CR,LF,'$'
AddressErrMsg	DB	CR,LF,'Address paramater error.$'
RangeErrMsg	DB	CR,LF,'Paramater range error.$'

; -------------------------- RAM usage -----------------------------------------
RAMAREA		DB	'RAM STORE AREA->'		;useful for debugging
RAM_DRIVE_SEC	dw      0		;This area will be in top of RAM well below stack (used by IDE Board sections)
RAM_DRIVE_TRK	dw      0	
RAM_DRIVE_HEAD	dw      0
RAM_DRIVE_COUNT	dw	0	
RAM_SEC		dw      0
RAM_TRK		dw      0
RAM_DMA		dw      0
RAM_DMA_STORE	dw      0
SECTOR_COUNT	dw      0
CURRENT_IDE_DRIVE dw    0
DISPLAY_FLAG	dw      0
CURRENT_HEAD	DB	1		;On IBM PC, motor status (40:3FH)
CURRENT_DRIVE	DB	1		;On IBM PC, motor count (40:40H)
CURRENT_SECTOR	DB	1
CURRENT_TRACK	DB	1
CURRENT_TRACK_HIGH DB	1
SECTORS_TO_DO	DB      1		;Number of sectors to transfer in current operation
IDE_Buffer:	DB	0F4H				;put a HALT instruction here in case we jump to a sector in error
		times 511 db 0
IDE_Buffer2:	db	0F4h
		times 511 db 0
; stack
		times 256 db 0
STACK		DW	0H

;END



