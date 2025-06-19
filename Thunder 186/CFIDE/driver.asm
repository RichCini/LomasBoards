       name    cfdriver
        page    60,132
	title 	CFDRIVER CF-IDE Device Driver
; The driver command-code routines are stubs only and have
; no effect but to return a nonerror "done" status.
;
; Compile with MASM:
;	masm /la /Zd driver.asm,driver.com,,driver.lst
;	link driver,driver,driver;
;	exe2com	driver.exe driver.sys
;
; Alternatively, add the "/tiny" flag on the link and
; the third step shouldn't be needed.
;
; disk geometry
; CHS = 7745/16/63 = 7806960 LBA @ 512b/sector = 4GB
;
; NOTE: Under emulation, the I/O instructions may barf. Parallels
; crashes the VM.
;
; The HDISK driver for the Gazelle (MS-DSO 2.0) supports only
; requests 0-9 which is the minimum requirement for a block
; driver. Unsure if we need to support/map D-F
;
;  Values for command code:
;    * 00h INIT
;    * 01h MEDIA CHECK (block devices)
;    * 02h BUILD BPB (block devices)
;    * 04h INPUT
;    * 08h OUTPUT
;    * 09h OUTPUT WITH VERIFY
;	3,5,6,7 are invalud
;      0Dh (DOS 3+) DEVICE OPEN
;      0Eh (DOS 3+) DEVICE CLOSE
;      0Fh (DOS 3+) REMOVABLE MEDIA (block devices)
;    (* minimum requirement)
;
;
;****************************************************************
;*      INSTRUCTING THE ASSEMBLER                               *
;****************************************************************
_TEXT   segment para public 'CODE'
driver	proc	far
        assume cs:_TEXT,ds:_TEXT,es:_TEXT

;----- Version related
VOL_NAME	equ	'LDP_T186_D1'	; 11 bytes volumn label
VER_NUM		equ	'1.0'		; Version number
RELEASE_NUM	equ	'0', '1'	; Release number
MIN_DOS		equ	3		; minumum DOS version

INCLUDE	CFIDE.ASM			; CF_IDE includes
;INCLUDE	STRUC24.ASM
INCLUDE REQHDR.ASM			; request header structures

MaxCmd	EQU	9			; maximum allowed command code (can be less)
					; 12 for MS-DOS 2
					; 16 for MS-DOS 3.0-3.1
					; 24 for MS-DOS 3.2-3.3
CR      equ     0dh
LF      equ     0ah
EOS     equ     '$'			; end of string
EOM	equ	CR,LF,EOS
BELL	equ	7

;----- INT values
DOS		equ	21h             ; DOS function rq interrupt
DOS_PRNMSG	equ	09h             ; Output string($)
DOS_PRNCHAR	equ	02h             ; Output char
;DOS_EXIT        equ     4ch             ; Exit to caller
;DOS_GETLOL      equ     52h             ; Get list of list
;DOS_GETVER      equ     30h             ; Get DOS version
;DOS_SETVECTOR   equ     25h             ; Set vector
DOS_FLUSH	equ 	0dh             ; Reset disk

;----- device request   command
DEV_RQ          equ     es:[bx]         ; device request header
DR0_INIT        equ     00h             ; initialize
DR1_MEDIACHK    equ     01h             ; media check
DR2_BUILDBPB    equ     02h             ; build BPB
DR4_INPUT       equ     04h             ; input/read
DR8_OUTPUT      equ     08h             ; output/write
DR9_OUTPUTV     equ     09h             ; output verify/write
DR_MAXNUM       equ     09h             ; max request number

;----- device driver error code
DER_NOERR       equ     0000h           ; no error
DER_DONE	equ	0100h		; completed
DER_BUSY	equ	0200h		; busy
DEV_ERROR       equ     8000h           ; error bit
DER_PROTECT     equ     8000h           ; write-protect violation
DER_UKUNIT      equ     8001h           ; unknown unit
DER_NOTREADY    equ     8002h           ; drive not ready
DER_UKCMD       equ     8003h           ; unknown command
DER_CRC         equ     8004h           ; CRC error
DER_BADLEN      equ     8005h           ; bad drive request structure length
DER_SEEKERR     equ     8006h           ; seek error
DER_UKMEDIA     equ     8007h           ; unknown media
DER_MISSEC      equ     8008h           ; sector not found
DER_OUTPAPER    equ     8009h           ; printer out of paper
DER_WRFAULT     equ     800Ah           ; write fault
DER_RDFAULT     equ     800Bh           ; read fault
DER_GENERAL     equ     800Ch           ; general failure
DER_DISCHG      equ     800Fh           ; invalid disk change

					;Meanings for disk status (as returned by IBM BIOS ROM)
seekerr		equ     40h		;seek failed
hdwerr		equ     20h		;controller chip failed
crcerr		equ     10h		;crc error
dmaerr		equ     09h		;DMA across 64k boundary
wpterr		equ     03h		;write protected disk
rnferr		equ     04h		;sector not found

;****************************************************************
;*      MACROS (borrowed from flashdsk.asm)			*
;****************************************************************
DOSINT	macro                   	; DOS interrupt
		int DOS
	endm

CALLDOS	macro SubFunc           	; DOS function call
		mov ah, SubFunc
		DOSINT
	endm

CALLDOSX	macro SubFuncx          ; DOS function call via AX
		mov ax, SubFuncx
		DOSINT
	endm

CALLDOS2 	macro SubFunc,AL_val    ; DOS function call with al
		mov ax, SubFunc*256+Al_val
		DOSINT
	endm

PRINTMSG	macro sMsg              ; Print message use DOS DX
		mov dx, offset sMsg
		mov ah, DOS_PRNMSG
		DOSINT
	endm

PRINTMSGDX	macro			; Print message use DOS
		mov ah, DOS_PRNMSG
		DOSINT
	endm

PRINTERRMSG	macro sErr              ; Print error message
		PRINTMSG  msg_error
		PRINTMSG  msg_errcode
		PRINTMSG  sErr
	endm    

;****************************************************************
;*	MAIN PROCEDURE CODE					*
;****************************************************************
begin:
start_address	equ	$

;****************************************************************
;*      DEVICE HEADER REQUIRED BY DOS                           *
;****************************************************************
next_dev	dd	-1		;no device driver after this 
attribute	dw	0000000000000000b
strategy	dw	Strat		;address of strategy routine
interrupt	dw	Intr		;address if interrupt routine
dev_name	db	1		; one device
		db	'LDPIDE'	; 6-byte driver name
disknum		db	'X'		; assigned drive letter from Init
DEV_HEAD_LEN    equ     $ - next_dev

;****************************************************************
;*      WORK SPACE FOR OUR DEVICE DRIVER                        *
;****************************************************************
		even
RHPtr 		dd 	? 		; *far to request header

;----- Disk params for dummy boot record
; Standard IBM Type 3 30mb hard drive (32mb max under MSDOS 3.x)
NHEADS		EQU	6		; Number of heads
NSECT		EQU	17		; Number of sectors per track
NTRACKS		EQU	615		; Number of cylinders
DIRENT		EQU	512		; root dir directory count
ALLOCSIZ	EQU	4
FATSIZ		EQU	6
DEF_SEC_SIZE	equ	512 		; Driver sector size
DRV_MEDIA	equ	0f8h		; media descriptor byte F8=hard disk
NFATS 		equ	2		; number of FATs
RSVDSEC		equ	1		; number of reserved sectors
TOTALSEC	equ	((NTRACKS*NHEADS)-(FATSIZ+RSVDSEC))*NSECT	; should be F493

;CHS = 7745/16/63 = 7806960 LBA @ 512b/sector = 4GB
; PC/MS-DOS maximum size for DOS 3.3 is 32mb partition
; The nearest standard IBM type is:
; Type 3: 615 cylinders, 6 heads, 17 sectors/track (32,117,760 bytes or 30Mb)
; In-memory boot sector layout
boot_rec	equ	$
		db	3 dup (0)	; no boot jump
                db      'LDP  1.0'	; 8 byte vendor ID
; Start with the DOS 2.0 BPB. Values match that for a Type 3 HD.
ourbpb          label   byte            ; These BPB values are arbitrary
bytes_sector    dw 	DEF_SEC_SIZE	; 00 bytes per sector 0200
sec_cluster     db	ALLOCSIZ	; 02 sectors per cluster 4
sec_reserved    dw 	RSVDSEC		; 03 reserved sector 1
num_fats        db	NFATS		; 05 number of FAT 2
root_dirs       dw	DIRENT		; 06 root dir entries 0200
;615*17 = 62730 - (num_fats*sector_fat+reserved * 17) = 62611
num_sec         dw 	TOTALSEC	; 08 number of sectors 0F493h
media_byte      db 	DRV_MEDIA	; 0a media type F8
sector_fat      dw 	03Dh		; 0b logical sectors per FAT
; DOS 3.31 BPB
		dw	NSECT		; 0d physical sectors per track
		dw      NHEADS		; 0f number of heads
		dd	011h 		; 11 special hidden sectors
		dd	0 		; 15 BigDOS num of sectors(num_sec=0)
bpb_ptr		dw	ourbpb

total		dw	?		; total transfer sector count
verify		db	0		; verify 1=yes, 0=no
start		dw	0		; starting sector number
buf_ofs		dw	?		; data transfer offset
buf_seg		dw	?		; data transfer segment

; CFIDE-specific variables
DEBUG_FLAG	db	0		; start with no logging
RAM_DRIVE_SEC	dw	0
RAM_DRIVE_TRK	dw	0	
RAM_DRIVE_HEAD	dw	0
RAM_DRIVE_COUNT	dw	0	
RAM_SEC		dw	0
RAM_TRK		dw	0
DELAYStore	dw	0
RAM_DMA		dw	0
RAM_DMA_STORE	dw	0
SECTOR_COUNT	dw	0
CURRENT_IDE_DRIVE	dw	0
DISPLAY_FLAG	dw	0

IBM_DISK_STATUS	db	0		;Returned disk status  (40:41H)
SECTORS_TO_DO	db	0		;Number of sectors to transfer in current operation
SECTORS_DONE	db	0		;Number actually transferred
SEEK_STATUS	DB	0		;Seek status  (40:3EH)
CURRENT_HEAD	DB	0		;On IBM PC, motor status (40:3FH)
CURRENT_DRIVE	DB	0		;On IBM PC, motor count (40:40H)
CURRENT_SECTOR	DB	0
CURRENT_TRACK	DB	0
CURRENT_TRACK_HIGH DB	0
DMA_OFFSET	dw	?		; DMA offset address for controller  (On PC this area is used by FDC)
DMA_SEGMENT	dw	?		; DMA segmant address for controller

CRLFSTR		db	EOM

;****************************************************************
;*      THE STRATEGY PROCEDURE                                  *
;*								*
;* Called by MS-DOS with es:bx set to the address of the 	*
;* request header.						*
;****************************************************************
Strat:	
	mov 	word ptr cs:[RHPtr],bx
	mov 	word ptr cs:[RHPtr+2],es
	ret 				; back to MS-DOS kernel

;****************************************************************
;*	THE INTERRUPT PROCEDURE  				*
;****************************************************************
;device interrupt handler - 2nd call from DOS
Intr:

; there's no stack switching but maybe not a bad idea to switch
; to a private stack. Order is important - always update SS first, 
; then SP to take advantage of the x86 deferring interrupts until 
; after SP is updated.
        cld 
	push 	ax 			;save machine state on entry
        push    bx
        push    cx
        push    dx
        push    ds
        push    es
        push    di
        push    si
        push    bp

	push 	cs 			; make local data addressable
	pop 	ds 			; by setting DS = CS
	les	bx,cs:RHPtr		; restore header pointer
;	mov	ax,word ptr cs:[RHPtr+2]	;restore ES as saved by STRATEGY call
;	mov	es,ax	
;	mov	bx,word ptr cs:[RHPtr]		;restore BX as saved by STRATEGY call

;jump to appropriate routine to process command

;	mov     al,es:[bx].rh_cmd       ; get request header header command
	mov	al,DEV_RQ.command
	cmp 	al,DR_MAXNUM 		; make sure it's legal
	jle 	Intr1 			; jump, function code is ok
	mov 	ax,DER_UKCMD 		; error bit + "unknown command" code
	jmp 	Intr2

Intr1:
	rol     al,1                    ;times 2 for index into word table
	lea     di,cmdtab               ;function (command) table address
	mov     ah,0                    ;clear hi order
	add     di,ax                   ;add the index to start of table
	jmp     word ptr[di]            ;jump indirect

; call returns with AX set to success or an error code
Intr2:	or	ax,DER_DONE		; 0100h set 'done' bit in status and
;	mov 	es:[bx].rh_status,ax 	; store status into request header
	mov	DEV_RQ.status,ax	; store status into request header

	pop 	bp 			; restore general registers
        pop     si
        pop     di
        pop     es
        pop     ds
        pop     dx
        pop     cx
        pop     bx
        pop     ax
        ret

;CMDTAB is the command table that contains the word address
;for each command. The request header will contain the
;command desired. The INTERRUPT routine will jump through an
;address corresponding to the requested command to get to
;the appropriate command processing routine.

CMDTAB	label	byte		; interrupt-routine command-code
	dw 	Init 		; 0 = initialize driver
	dw 	MediaChk 	; 1 = media check
	dw 	BuildBPB 	; 2 = build BPB
	dw 	IoctlRd 	; 3 = IOCTL read		return Bad Cmd
	dw 	Read 		; 4 = read
	dw 	NdRead 		; 5 = nondestructive read	return Device Busy
	dw 	InpStat 	; 6 = input status		return Xfer Complete
	dw 	InpFlush 	; 7 = flush input buffers	return Xfer Complete
	dw 	Write 		; 8 = write
	dw 	WriteV	 	; 9 = write with verify
; minimum number


;****************************************************************
;*	YOUR LOCAL PROCEDURES   				*
;****************************************************************
; Save data from the request header into our local data area
save	proc 	near			
;
;	called from INPUT, OUTPUT
;
	mov	ax,DEV_RQ.io_trans_seg	;save data transfer
	mov	cs:buf_seg,ax		; segment
	mov	ax,DEV_RQ.io_trans_ofs	;save data transfer 
	mov	cs:buf_ofs,ax		; offset
	mov	ax,DEV_RQ.io_start_sec	;get start sector number
	mov	cs:start,ax		; save it
	mov	ax,DEV_RQ.io_sec_cnt	;# sectors to transfer
;	mov	ah,0			;clear hi order
	mov	cs:total,ax		; save in our area
	ret				;return to caller
save	endp

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

CO:	
	push	dx
	mov	dl,cl
	CALLDOS	DOS_PRNCHAR 		; uses ax, dl
	pop	dx
	ret

;---------------Select Drive/CF card ------------------------------------------
SetDriveA:				;Select First Drive
	MOV	AL,0
	JMP	SelDrive

SetDriveB:				;Select Drive 1
	MOV	AL,1

SelDrive:
	MOV	BP,CURRENT_IDE_DRIVE
	MOV	[BP],AL
	OUT	IDEDrivePort,AL		;Select Drive 0 or 1
	RET	

;---------------Clear the ID buffer--------------------------------------------
ClearBuffer:				;Clear the ID Buffer area
	push	ax
	push	di
	push	ds
	pop	es
	mov	ax,2020H
	mov	cx,256			;512 bytes
	lea	di,IDE_Buffer
	rep	stosw
	pop	di
	pop	ax
	ret

;---------------Initialize the IDE channels------------------------------------
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

;---------------- Do the IDEntify drive command, and display the IDE_Buffer ------------
DriveID:
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

	MOV	BX,offset msgmdl		;print the drive's model number
	CALL	PRINT_STRING
	MOV	BP,(IDE_Buffer + 54)
	MOV	CH,10			;Character count in words
	CALL	Print_ID_Info		;Print [HL], [B] X 2 characters
	CALL	CRLF
					; print the drive's serial number
	MOV	BX,offset msgsn
	CALL	PRINT_STRING
	MOV	BP,(IDE_Buffer + 20)
	MOV	CH,5			;Character count in words
	CALL	Print_ID_Info
	CALL	CRLF
					;PRINT_STRING the drive's firmware revision string
	MOV	BX,offset msgrev
	CALL	PRINT_STRING
	MOV	BP,(IDE_Buffer + 46)
	MOV	CH,2
	CALL	Print_ID_Info		;Character count in words
	CALL	CRLF
					;print the drive's cylinder, head, and sector specs
	MOV	BX,offset msgcy
	CALL	PRINT_STRING
	MOV	BP,(IDE_Buffer + 2)
	CALL	Print_ID_HEX
	MOV	BX,offset msghd
	CALL	PRINT_STRING
	MOV	BP,(IDE_Buffer + 6)
	CALL	Print_ID_HEX
	MOV	BX,offset msgsc
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

;---------------Wait for Drive--------------------------------------------------	
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
	
;---------------Wait for IRQ--------------------------------------------------		
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

;------------------------------------------------------------------
; Low Level 8 bit R/W to the drive controller.  These are the routines 
; that talk directly to the drive controller registers, via the 8255 
; chip. Note the 16 bit Sector I/O to the drive is done directly 
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


; Print a string cs:bx
PRINT_STRING:
;	push	ds
;	mov	ds,cs
	push	dx
	mov 	dx,bx
	CALLDOS	DOS_PRNMSG 		; print the message ds:dx
	pop	dx
;	pop	ds
	ret

; Print a 16 bit number, located [BP] (Used only by the above DISK ID routine)
; (Note Special Low Byte First. Used only for Drive ID)

Print_ID_HEX:
	MOV	AL,[BP+1]		;Index to high byte first
	CALL	AL_HEXOUT
	MOV	AL,[BP]			;Now low byte
	CALL	AL_HEXOUT
	RET


;	SIMPLE SEND CRLF
CRLF:	
	mov	bx,offset CRLFSTR
	call	PRINT_STRING
	ret

;	Adjust DMASEG:DMAOFF via [ES:DI] so that the in DI is the
; 	smallest possible. This process is called normalization.
;	Registers:   Only ES and DI altered
DMA_ADJUST:
	MOV	ES,[DMA_SEGMENT]
	MOV	DI,[DMA_OFFSET]	

	PUSH	AX
	PUSH	DI
	SHR	DI,1			; Get paragraph to low 12 bits
	SHR	DI,1			; Shift 0's in at hi 4 bits
	SHR	DI,1
	SHR	DI,1
	MOV	AX,ES			; Get segment to Bx
	ADD	AX,DI			; Add in segment skew
	MOV	ES,AX			; Restore dma segment
	POP	DI			; Get back original offset
	AND	DI,0FH			; Only need within paragraph

	MOV	[DMA_SEGMENT],ES
	MOV	[DMA_OFFSET],DI		;<<< Later use LES (or for Sec Write LDS)
	POP	AX
	RET

;-------------------- READ HARD DISK DISK SECTORS -----------------------------------
; Called with:
;	AX= starting sector
;	CX= sector count
;	es:di (buf_seg:buf_ofs) is the destination address
;
; Returns:
;	CX= sectors actually read
;	AX= error code
;
; Registers:
;	All
;
HDISK_READ:
;N_RD_SEC:			
	MOV	BP,SECTOR_COUNT		;store sector count
	MOV	[BP],CX

	MOV	BP,RAM_DMA_STORE
	MOV	word [BP],IDE_Buffer	;DMA_STORE initially to IDE_Buffer

NextRSec:	
	CALL	WR_LBA			;Update LBA on drive
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
; maybe copy data to memory at this point?

	CALL	GET_NEXT_SECT		
	JZ	NextRSec

	mov	ax,DER_NOERR			;0
	ret

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


;-------------------- WRITE HARD DISK DISK SECTORS ----------------------------------
; Called with:
;	AX= starting sector
;	CX= sector count
;	es:di (buf_seg:buf_ofs) is the source address
;
; Returns:
;	CX= sectors actually read
;	AX= error code
;
; Registers:
;	All
;
HDISK_WRITE:
;N_WR_SEC:			
	
	MOV	BP,SECTOR_COUNT		;store sector count
	MOV	[BP],CX

	MOV	BP,RAM_DMA_STORE
	MOV	word [BP],IDE_Buffer	;DMA_STORE initially to IDE_Buffer

NextWSec:	
	CALL	WR_LBA			;Update LBA on drive
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
	mov	ax,DER_NOERR			;0
	ret


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


SHOWerrors:
	mov	ax,DER_GENERAL
	ret

;Write the logical block address to the drive's registers
WR_LBA:			
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


;****************************************************************
;*	DOS COMMAND PROCESSING					*
;****************************************************************
; Command-code routines are called by the interrupt routine
; via the dispatch table with ES:DI pointing to the request
; header. Each routine should return AX = 0 if function was
; completed successfully or AX = (8000h + error code) if
; function failed. AX is ORed into the return status.
;
; The caller (Interrupt routine) applies the COMPLETED bit 
; before returning to MS-DOS.
;
;---------------Individual Functions------------------------------------------
;
;	Function 0 is Initialize, done below the break address
;
;----------------------------------------------------------------------------
; Media Check				function 1 = media check
;----------------------------------------------------------------------------
MediaChk 	proc 	near 	

	mov     DEV_RQ.mdc_status,1	; mark disk not changed
	mov     ax,DER_NOERR		;0
	ret

MediaChk 	endp

;----------------------------------------------------------------------------
; Get BPB				function 2 = get BPB
;----------------------------------------------------------------------------
BuildBPB 	proc 	near 

	mov	cs:start,0			;boot record = sector 0
	mov	cs:total,1			;1 sector
	mov	DEV_RQ.bpb_media,DRV_MEDIA	; media byte
	mov     DEV_RQ.bpb_bpb_ofs,offset ourbpb	; the offset
	mov     DEV_RQ.bpb_bpb_seg,cs			; in our CS
	mov     word ptr DEV_RQ.bpb_trans_ofs,1		; first FAT sector	
	mov	ax,DER_NOERR			;0
	ret

BuildBPB 	endp


;----------------------------------------------------------------------------
; IOCTL Read				function 3 = IOCTL read
;----------------------------------------------------------------------------
IoctlRd	 	proc 	near 

	mov	ax,DER_UKCMD				; unknown command
	ret

IoctlRd 	endp



;----------------------------------------------------------------------------
; Read Sectors				function 4 = read (input)
;----------------------------------------------------------------------------
; IN:
; 	sector number:	_start (AX) = io_start_sec
; 	sector count:	_count (CX) = io_sec_cnt
;	DTA: 		buf_seg:buf:ofs = io_trans
; OUT:
; 	sectors actually read:		_count (CX)
;	error code:			AX = DER_NOERR if no error
; REG: 
;----------------------------------------------------------------------------
Read 	proc 	near 

	call	save			; save RH data rh4=rh8
; buf_seg:buf_off contains the destination address from io_trans
	mov	es,cs:buf_seg		; set destination seg & ofs
	mov	di,cs:buf_ofs		; to es:di

; since the drive is less than 32MB, there shouldn't be any
; overflow as it's less than 64k sectors.
	mov	ax,di			; get offset 
	add	ax,cx			; add transfer length
	jnc	input1			; overflow?
	mov	ax,0ffffh		; yes - use max transfer
	sub	ax,di			; subtract offset from max
	mov	cx,ax			; new transfer count

; get bytes from the drive. CX already set
input1:	
	mov	ax,total		; sector count
	call	HDISK_READ		; this returns the right error value
	les	bx,cs:RHPtr
	ret

Read	endp


;----------------------------------------------------------------------------
; Nondestructive Read			function 5 = nondestructive read
;----------------------------------------------------------------------------
NdRead 	proc 	near 

	mov	ax,DER_BUSY		; busy error
	ret

NdRead 	endp

;----------------------------------------------------------------------------
; Input Status				function 6 = input status
;----------------------------------------------------------------------------
InpStat 	proc 	near

	mov	ax,DER_NOERR		; no errors; signal complete
	ret

InpStat 	endp

;----------------------------------------------------------------------------
; Flush Input Buffers			function 7 = flush input buffers
;----------------------------------------------------------------------------
InpFlush 	proc 	near 

	mov	ax,DER_NOERR		; no errors; signal complete
	ret

InpFlush 	endp

;----------------------------------------------------------------------------
; Write Sectors				function 8 = write (output)
;----------------------------------------------------------------------------
; IN:
;   AX=start sector number
;   CX=sector count
; OUT:                        
;   CX=sector actually written
;   AX=error code, DER_NOERR=no error
; REG:
;----------------------------------------------------------------------------
Write 	proc 	near 

	call	save			; save RH data
	push	ds			;move to 
	pop	es			; es
	mov	di,si			;same for di
	mov	ds,cs:DMA_SEGMENT	;ds:si points to source
	mov	si,cs:DMA_OFFSET	; data in DOS

;	Output the data to the drive
	call	HDISK_WRITE

	les	bx,cs:RHPtr
	cmp	cs:verify,0		;do we verify write?
	jz	out1			;no
	mov	cs:verify,0		;reset verify indicator
	jmp	Read			;read those sectors back in
out1:	
	les	bx,cs:RHPtr		; restore request header again
	mov	ax,DER_NOERR		; no errors; signal complete
	ret

Write	endp


;----------------------------------------------------------------------------
; Write Sectors	w/verify		function 9 = write (with verify)
;----------------------------------------------------------------------------
; IN:
;   AX=start sector number
;   CX=sector count
; OUT:                        
;   CX=sector actually written
;   AX=error code, DER_NOERR=no error
; REG:
;----------------------------------------------------------------------------
WriteV 	proc 	near 

	mov	cs:verify,1
	jmp	Write
	
WriteV	endp


;****************************************************************
;*	MESSAGES						*
;****************************************************************
; CFIDE messages
msgmdl		DB	CR,LF,'Drive/CF Card Information:-',CR,LF
		DB	'Model: $'
msgsn		DB	'S/N:   $'
msgrev		DB	'Rev:   $'
msgcy		DB	'Cylinders: $'
msghd		DB	', Heads: $'
msgsc		DB	', Sectors: $'
msgLBA		DB	'  (LBA = 00$'
MSGBracket	DB	')$'
CYL_MSG		DB	'H Cyl=$'
HD_MSG		DB	'   Head=$'
BRAC1_MSG	DB	'H ($'
OF_MSG		DB	'H of $'
BRAC2_MSG	DB	'H)',CR,LF,'$'
TRACK_MSG	DB	'H   Track = $'
SEC_MSG		DB	'H   Sector = $'
HREAD_ERR_MSG	DB	CR,LF,BELL,'HDisk Multi-Sector Read Error.$'
HWRITE_ERR_MSG	DB	CR,LF,BELL,'HDisk Multi-Sector Write Error.$'

;----- Normal message
msg_init        db      'Initilizing IDE hardware...', EOM
msg_checkpoint	db	'Checkpoint', EOM
msg_endinit     db      'Finished.', EOM
msg_error       db      'Error found!', BELL, EOM
msg_errcode     db      'Error message: ', EOS
msg_disk1       db      'Driver installed as drive '
msg_disknum     db      '?'				; this holds assigned drive letter
                db      ':', EOM
msg_readonly    db      'Device is readonly', EOM
msg_writable    db      'Device is writable', EOM
;----- Error message                        
em_badinita	db	'Unable to initialize drive A',EOM
em_badinitb	db	'Unable to initialize drive B',EOM
em_badid	db	'Error obtaining drive ID', EOM


;****************************************************************
;*	BUFFERS							*
;****************************************************************
IDE_Buffer:	db	512 dup (' ')	;512 Byte buffer for IDE Sector R/W
IDE_Buffer2:	db	512 dup (0)	;512 Byte buffer for IDE Sector Verify


;****************************************************************
;*	END OF PROGRAM	- Initialization			*
;****************************************************************
; Everything below here is discarded after init is complete
end_of_program:

; org to paragraph boundry
	if	($-start_address) mod 16
	org	($-start_address)+16-(($-start_address) mod 16)
	endif

; INIT called with es:di pointing to the request header
Init 	proc 	near 			; function 0 = initialize driver

	call	signon			; let everyone know we're here

	mov 	DEV_RQ.init_num_unit,1 			; number of drive units
	mov 	DEV_RQ.init_free1_ofs,offset Init	; set address of free memory
	mov 	DEV_RQ.init_free1_seg,cs		; above driver (break address)
	mov	DEV_RQ.init_bpb_ofs,offset bpb_ptr	; return offset
	mov	DEV_RQ.init_bpb_seg,cs			; return offset
	mov     al, DEV_RQ.init_drv_num 		; Get drive num...
	add     al, 'A'					; ...and convert to ASCII
	mov     [msg_disknum], al			; save it into string
	mov     [disknum], al

; The following calls access I/O ports which are eaten by Parallels. Need to
; test on alternative emulators or move to real hardware.
	PRINTMSG	msg_init 	; initializing...
; start drive A
	call	ClearBuffer
	call	SetDriveA		; select second drive on IDE card which is the MSDOS card
	call	IDEinit			; go initialize it
	JZ	INIT1_OK		; ok?
	mov	dx,offset em_badinita
	jmp	InitFail		; no, exit

; start drive B
INIT1_OK:
	call	ClearBuffer
	call	SetDriveB		; select second drive on IDE card which is the MSDOS card
	call	IDEinit			; go initialize it
	JZ	INIT2_OK		; ok?
	mov	dx,offset em_badinitb
	jmp	InitFail		; no, exit

; dump card info
INIT2_OK:
	call	ClearBuffer
	call	SetDriveA
	call	DriveID
	jz	INIT3_OK
	mov	dx,offset em_badid	;  unable to get drive ID bytes
	jmp	InitFail

INIT3_OK:				;Check we have a valid IDE drive 
	MOV	BP,(IDE_Buffer+12)	;Note always SS: = CS:
	MOV	AX,[BP]
	OR	AX,AX			;If there are zero sectors then something wrong
	jnz	INIT4_OK
	mov	dx,offset em_badid	;  unable to get drive ID bytes

INIT4_OK:
	MOV	BP,RAM_DMA		;Set default position will be first sector block
	MOV	word[BP],IDE_Buffer	;DMA always initially to IDE_Buffer, 
	
	MOV	BP,RAM_SEC
	MOV	word[BP],0H		;Sec 0
	MOV	BP,RAM_TRK
	MOV	word[BP],0H		;Track 0

	call	SetDriveB		; this is the MSDOS drive on the CF card
	CALL	IDEinit			;For some reason this need to be here after getting the drive ID.
					;otherewise sector #'s are off by one! (Probably because on non-LBA reads)
	CALL	WR_LBA			;Update LBA on "1st" drive
	mov     [SEEK_STATUS],0		;show good seek status
        mov     [IBM_DISK_STATUS],0	;and good disk status
 	jmp	InitExOK

InitFail:
	PRINTMSGDX
	mov     [IBM_DISK_STATUS],seekerr
	mov	ax,DER_NOTREADY			; assume drive not ready error
	jmp	InitExit

InitExOK:
	xor 	ax,ax 			; return success
InitExit:
	ret

Init 	endp


signon	proc	near
	mov 	ax,cs 			; convert load address to ASCII
	mov 	bx,offset DHaddr
	call 	hexasc
	mov	ah,9
	mov	dx,offset Ident
	int	21H
	ret
signon	endp

; used specifically for overwriting chars in a string
hexasc  proc    near
        push    cx
        push    dx
        mov     dx,4
hexasc1:
        mov     cx,4
        rol     ax,cl
        mov     cx,ax
        and     cx,0fh
        add     cx,'0'
        cmp     cx,'9'
        jbe     hexasc2
        add     cx,'A'-'9'-1
hexasc2:
        mov     [bx],cl
        inc     bx
        dec     dx
        jnz     hexasc1
        pop     dx
        pop     cx
        ret
hexasc  endp

Ident	db      CR,LF,LF
	db      'Lomas CFIDE System Driver 1.0', CR,LF
        db      'Device driver header at '
DHaddr	db      'XXXX:0000', CR,LF,LF,EOS

driver	endp
_TEXT	ends
        end	begin