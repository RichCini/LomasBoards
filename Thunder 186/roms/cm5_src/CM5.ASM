TITLE LDP THUNDER REV 1.0 10/21/85 Color Magic ROM
PAGE  59,132
;option M510	; Assume MASM 5.1 if using MASM 6.11

;
; This is an IBM/PC-compatible BIOS ROM for installation in 
; the Thunder 186 single-board computer when used with the
; Color Magic CGA video board. By default, the Thunder 186
; comes with a conventional monitor ROM -- I would guess that
; this ROM was included with the purchase of the Color Magic,
; possibly as an extra-cost option since the Color Magic
; could be used in any other PC-capable S100 setup.
;

; NOTE: The Ampro LittleBoard 186 can boot from the SCSI channel
;	so this might be an option... 
;
; There is a system equates file referenced from the monitor and
; several hardware-specific files for initializing the 80186 and
; as the includes for the storage hardware. These have been 
; partially re-created.
;
; general items:
;	tmr0 = serial 0 clock
;	tmr1 = serial 1 clock
;	UCS = ROM @ FE000
;	LCS = 256k RAM
;	DRQ0 = bus DMA0
;	DRQ1 = floppy DRQ and bus DMA1
;	INT0 = bus VI0			} need to verify
;	INT1 = bus VI2/VI3		}
;	INT2 = bus VI4			}
;	INT3 = bus VI6/VI7 and RX1/RX2	}
;	NMI = parity fail (unused with SRAM) and bus NMI
;
; There are several references to ports D0-D6 which are 
; not documented. This could be the 8255 (config switches
; and printer port). Since the CM5 ROM is for the Color
; Magic, I doubt the baud rate switches would be important.
;
; SCSI IRQ 3, port 310h, D8000h
;
; The last byte has to be patched with DEBUG as follows
;
;   FFFF 00.xx          ( avoid ER_BIOS on bootstrap ) --------------------
;									  |
;									  |
; where "xx" results in a zero checksum for the whole BIOS rom, for ex 	  |
;                                                                         |
;               masm BIOS;              ( Assemble BIOS source code)      |
;               link BIOS;              ( Link the BIOS object code)      |
;               debug BIOS.EXE          ( Exe2bin  BIOS binary code)      |
;               -nBIOS.BIN              ( Name of the output binary)      |
;               -eCS:1FFF               ( Opens BIOS checksum  byte)      |
;;  ------->    .DC                     ( Force ROM checksum = zero) <-----
;;              -rBX                    ( Opens hi order byte count)
;;              :0                      (  ... must be 0 bytes long)
;;              -rCX                    ( Opens lo order byte count)
;;              :2000                   (  ... BIOS 2000 bytes long)
;;              -wCS:0	                ( Output to BIOS.BIN   file)
;;              -q


;===============================================================================
;  Defines
FALSE		equ	0
TRUE		equ	0ffh
DEBUGF		equ	TRUE		; allows marco expansion
ROMSEARCH	equ	TRUE		; set true to include expansion ROM search

; System compilation options
WD100X		equ	FALSE
CIA_HDO		equ	FALSE		;Control-it-all HD options installed
CIA		equ	CIA_HDO
SCSI		equ	TRUE
HDO		equ	TRUE		;hard disk option; indicate either CIA or SCSI

IF	SCSI
	scsi_options	equ	00100000b	;indicate that SCSI is present
ELSE
	scsi_options	equ	00000000b	;indicate no SCSI is present
ENDIF


;===============================================================================
;  Constants
include "T186.ASM"		; system equates
include "CM5D.ASM"		; ColorMagic-specific ports/data

Int00v		equ	0			; (0000:0000=0CA60h)  0 DIV/0
Int01v		equ	4			; (0000:0004=0F4h)    1 SST
Int06v		equ	18h			; (0000:0018=0CA60h)  6 invalid opcode
Int08v		equ	20h			; (0000:0020=0FEA5h)  8 Timer hardware IRQ
Int09v		equ	24h			; (0000:0024=0E987h)  9 Keyboard IRQ
Int0Bv		equ	2Ch			; (0000:002C=0CE80h) 0B serial 2 IRQ
Int0Cv		equ	30h			; (0000:0030=0CE80h) 0C serial 1 IRQ
Int0Dv		equ	34h			; (0000:0034=3ADBh)  0D hard disk IRQ
Int10v		equ	40h			; (0000:0040=0EEh)   10 video
Int11v		equ	44h			; (0000:0044=0CB20h) 11 equipment
Int12v		equ	48h			; (0000:0048=0CB40h) 12 memory size
Int13v		equ	4Ch			; (0000:004C=0CF60h) 13 diskette/HD I/O
Int14v		equ	50h			; (0000:0050=0CB80h) 14 serial
Int15v		equ	54h			; (0000:0054=0CBA0h) 15 system services
Int16v		equ	58h			; (0000:0058=0CFC0h) 16 keyboard
Int17v		equ	5Ch			; (0000:005C=0CBC0h) 17 printer
Int18v		equ	60h			; (0000:0060=0CD00h) 18 Basic ROM
Int19v		equ	64h			; (0000:0064=0CC60h) 19 IPL
Int1Av		equ	68h			; (0000:0068=0CBE0h) 1A TOD
Int1Bv		equ	6Ch			; (0000:006C=0D1C0h) 1B Keyboard BREAK addr
Int1Cv		equ	70h			; (0000:0070=0CC00h) 1C user timer
Int1Dv		equ	74h			; (0000:0074=0C958h) 1D 6845 video init
Int1Ev		equ	78h			; (0000:0078=0CA60h) 1E DPB
Int1Fv		equ	7Ch			; (0000:007C=5E9h)   1F video graphic table

IPLLOC		equ	7C00h			;*(0000:7C00=0)	boot location
data_49e	equ	0			;*(1000:0000=75h)
data_50e	equ	3FEh			;*(1040:03FE=3)	COM1 block? Count?
; Outside of ROM address; likely just 8K address increments
data_121e	equ	2000h			;*(A.2000=0)
data_122e	equ	2001h			;*(A.2001=0)
; Also odd location.
;data_123e	equ	49h			; (C000:0049=0) ds:49 is CRT mode

; The Lomas BIOS doesn't produce error codes, but these might be useful.
ER_BIOS equ     01h             ; Bad ROM bios checksum, patch last byte
ER_RAM  equ     02h             ; Bad RAM in main memory, replace
ER_CRT  equ     04h             ; Bad RAM in video card, replace
ER_MEM  equ     10h             ; Bad RAM in vector area, replace
ER_ROM  equ     20h             ; Bad ROM in expansion area, bad checksum

LF      equ     0Ah
CR      equ     0Dh

;===============================================================================
;  Compiler directives
;
ifndef DEBUGF
.SALL                                           ; Suppress Macro Expansions
endif
.LFCOND                                         ; List  False  Conditionals
.186
ASSUME  DS:data, SS:code, CS:code, ES:code


;===============================================================================
;  Data segment - BIOS Data Segment
;
data	segment at 40H				; IBM compatible data structures
rs232_port_1	dw	4 dup (?)		; (0040:0000=3F8h)
prn_port_1	dw	4 dup (?)		; (0040:0008=378h)
equip_bits	dw	?			; (0040:0010=4467h)
mfg_test	db	?			; 0012
main_ram_size	dw	?			; (0040:0013=280h)
scratch1	db	? 			; scratch pad
		db	?
;---------------[Keyboard data area]------------;
keybd_flags_1	db	?			; (0040:0017=0)
;------ SHIFT FLAG EQUATES WITHIN KB_FLAG
INS_STATE	EQU	80H			; INSERT STATE IS ACTIVE
CAPS_STATE	EQU	40H			; CAPS LOCK STATE HAS BEEN TOGGLED
NUM_STATE	EQU	20H			; NUM LOCK STATE HAS BEEN TOGGLED
SCROLL_STATE	EQU	10H			; SCROLL LOCK STATE HAS BEEN TOGGLED
ALT_SHIFT	EQU	08H			; ALTERNATE SHIFT KEY DEPRESSED
CTL_SHIFT	EQU	04H			; CONTROL SHIFT KEY DEPRESSED
LEFT_SHIFT	EQU	02H			; LEFT SHIFT KEY DEPRESSED
RIGHT_SHIFT	EQU	01H			; RIGHT SHIFT KEY DEPRESSED
keybd_flags_2	db	?			; (0040:0018=0)
INS_SHIFT	EQU	80H			; INSERT KEY IS DEPRESSED
CAPS_SHIFT	EQU	40H			; CAPS LOCK KEY IS DEPRESSED
NUM_SHIFT	EQU	20H			; NUM LOCK KEY IS DEPRESSED
SCROLL_SHIFT	EQU	10H			; SCROLL LOCK KEY IS DEPRESSED
HOLD_STATE	EQU	08H			; SUSPEND KEY HAS BEEN TOGGLED
keybd_alt_num	db	?			; (0040:0019=0)
keybd_q_head	dw	?			; (0040:001A=30h)
keybd_q_tail	dw	?			; (0040:001C=30h)
keybd_buff	dw	16 dup (?)		; 001E
;------ HEAD = TAIL INDICATES THAT THE BUFFER IS EMPTY
NUM_KEY 	EQU	69			; SCAN CODE FOR NUMBER LOCK
SCROLL_KEY	EQU	70			; SCROLL LOCK KEY
ALT_KEY 	EQU	56			; ALTERNATE SHIFT KEY SCAN CODE
CTL_KEY 	EQU	29			; SCAN CODE FOR CONTROL KEY
CAPS_KEY	EQU	58			; SCAN CODE FOR SHIFT LOCK
LEFT_KEY	EQU	42			; SCAN CODE FOR LEFT SHIFT
RIGHT_KEY	EQU	54			; SCAN CODE FOR RIGHT SHIFT
INS_KEY 	EQU	82			; SCAN CODE FOR INSERT KEY
DEL_KEY 	EQU	83			; SCAN CODE FOR DELETE KEY
;---------------[Diskette data area]------------;
dsk_recal_stat	db	?			; (0040:003E=0)
dsk_motor_stat	db	?			; (0040:003F=0)
dsk_motor_tmr	db	?			; (0040:0040=0)
dsk_ret_code	db	?			; (0040:0041=0)
nec_stat	db	7 dup (?)		; (0040:0042=0)	NEC status 7 bytes
;---------------[Video display area]------------;
video_mode	db	?			; (0040:0049=3)
video_columns	dw	?			; (0040:004A=50h)
video_buf_siz	dw	?			; (0040:004C=1000h)
video_segment	dw	?			; (0040:004E=0)
vid_curs_pos0	dw	8 dup (?)		; (0040:0050=184Fh)
vid_curs_mode	dw	?			; (0040:0060=2000h)
video_page	db	?			; (0040:0062=0)
video_port	dw	?			; (0040:0063=3D4h)
video_mode_reg	db	?			; (0040:0065=29h)
video_color	db	?			; (0040:0066=30h)
;---------------[Used to setup ROM]-------------;
gen_io_ptr	dw	?,?			; (0040:0067=0) ; Eprom base Offset,Segment
gen_int_occured	db	?			; (0040:006B=0) ; Last spurious interrupt IRQ
;---------------[Timer data area]---------------;
timer_low	dw	?			; (0040:006C=696Fh)
timer_hi	dw	?			; (0040:006E=16h)
timer_rolled	db	?			; (0040:0070=0)
;---------------[System data area]--------------;
signbit		db      ?		; 40:71 ; Sign bit set if break
warmboot	dw      ?		; 40:72 ; Warm boot if 1234h value
;---------------[Hard disk scratchpad]----------;
HD		db	4 dup (0)  	; 40:74 ; scratch pad area
;---------------[Timout areas/PRT/LPT]----------;
lptto		db      4 dup(?)        ; 40:78 ; Ticks for LPT 1-4 timeouts
comto 		db      4 dup(?)        ; 40:7C ; Ticks for COM 1-4 timeouts
;---------------[Keyboard buf start/nd]---------;
; 	dw      ?               ; 40:80         ; Contains 1Eh, buffer start
;	dw      ?               ; 40:82         ; Contains 3Eh, buffer end
;
; SCSI -- might not be needed if using card with option ROM because work space
; would be allocated from there. This table is 25 bytes (19h) long.
IF	SCSI
	COMMAND_TABLE	dw	?		;command offset pointer
	CMND_PTR	dw	?		;segment of commands
	CMND_SEG	dw	?		;segment of commands
	TRANS_CNT	dw	?		;will read 512 bytes
	SDMA_OFF	dw	?		;buffer pointer
	SDMA_SEG	dw	?		;segment of buffer pointer
	SCSI_STATUS_IN	db	?		;status in
	SCSI_STATUS_OUT	db	?		;status out
	SCSI_MSG_IN	db	?		;received message
	SCSI_MSG_OUT	db	?		;send message
	SCSI_MSG_FLAG	db	?		;send message flag

	READ_WRITE_BLOCK	db	?	;read command for 8425
	SCSI_CMND_CNT		db	?	;number of byte in the command
	SCSI_CMND		db	?	;read command
	BLOCK_HIGH		db	?	;msb of 21 bit block address, low 5 bits of byte
	BLOCK_MIDDLE		db	?	;middle bbyte of address
	BLOCK_LOW		db	?	;low byte of address
	SCOUNT			db	?	;number of blocks to read, 0 =256
	CONTROL_BYTE		db	?	;control byte is always 0
ENDIF

data	ends

;===============================================================================
;  D O S   D A T A   S E G M E N T
;===============================================================================
; probably not needed for the Lomas but might be used for hard disk
; sector data.
dosdir  SEGMENT at 50h                          ; Boot disk directory from IPL
xerox   label   byte                            ;  0 if Print Screen idle
                                                ;  1 if PrtSc xeroxing screen
                                                ;255 if PrtSc error in xerox
                                                ;  ...non-grafix PrtSc in bios
        db      200h dup(?)                     ; PC-DOS bootstrap procedure
                                                ;  ...IO.SYS buffers the
                                                ;  ...directory of the boot
                                                ;  ...device here at IPL time
                                                ;  ...when locating the guts
                                                ;  ...of the operating system
                                                ;  ...filename "MSDOS.SYS"
dosdir  ends


;===============================================================================
;  I O . S Y S   D A T A   S E G M E N T  (IO.SYS initial load segment)
;===============================================================================
;dosseg  SEGMENT at 70h                          ; "Kernel" of PC-DOS op sys

;IO.SYS driver/bootstrap code loaded by the boot block to       CONTIGUOUS<---
;	70:0 Usually loads the first 3 sectors of IO.SYS.		     |
;MSDOS.SYS operating system kernel immediately follows IO.SYS and            |
;	doesn`t have to be contiguous. The DOS operating system		     |
;	binary image is loaded by transient code in IO.SYS.	             |
;dosseg  ends                                    ;                            |


;===============================================================================
;  I P L   D A T A   S E G M E N T  (loaded with bootstrap code from MBR)
;===============================================================================
;iplseg  SEGMENT at 0h                           ; Segment for boot block      |
;The following boot block is loaded with 512 bytes on the first sector of     |
;the bootable device by code resident in the ROM-resident bios.  Control is   |
;then transferred to the first word 0000:7C00 of the disk-resident bootstrap  |
;        ORG     07C00h                          ;  ..offset for boot block    |
;boot    db      200h dup(?)                     ;  ..start disk resident boot--
;iplseg  ends


;===============================================================================
;  C O D E   S E G M E N T  (BIOS code segment)
;===============================================================================
code    SEGMENT

entry   macro   x
        pad     =BANNER - $ + x	; - 0E000h
        if pad LT 0
        .err
        %out    'No room for ENTRY point'
        endif
        if pad GT 0
        db      pad DUP(0)
        endif
endm

jmpf    macro   x,y
        db      0EAh;
        dw      y,x
endm


; this code sits at F:E000
	org	0		; zero-start ROM
banner: 	db	"LDP THUNDER REV 1.0 10/21/85"
;	IF	SCSI
;		db	"-S"
;	ENDIF
		db	0ah, 0dh, 0

; Continues from CPU initialization code at 1C00h that initializes the 80186
; internal registers. The expansion ROM call has to occur after the hardware
; initializes but before video.
COLD2:
        	cli
 		mov	ax,8000h 		; send EOI twice
 		mov	dx,0FF22h		; PCRBASE+ICR+EOIREG
 		out	dx,ax			; port 0FF22h ??I/O Non-standard
 		mov	ax,8000h
 		mov	dx,0FF22h		; PCRBASE+ICR+EOIREG
 		out	dx,ax			; port 0FF22h ??I/O Non-standard

; test first 64k of RAM
 		cld				; Clear direction
 		xor	bx,bx			; Zero register
 		mov	ds,bx
 		mov	es,bx
 		mov	ax,5555h
loc_3:						;  xref A.0056
 		mov	cx,8000h
 		mov	si,bx
 		mov	di,bx
 		rep	stosw			; Rep when cx >0 Store ax to es:[di]
 		mov	cx,8000h
 		repe	scasw			; Rep zf=1+cx >0 Scan es:[di] for ax
 		jcxz	loc_4			; Jump if cx=0
 		mov	dx,66h
 		jmp	DynHalt			; (0597) memory test error?

loc_4:						;  xref A.0046
		cmp	ax,0AAAAh
 		je	loc_5			; Jump if equal
 		mov	ax,0AAAAh
 		jmp	short loc_3		; (0038)

; this clears 64k of RAM.
loc_5:						;  xref A.0051
 		mov	ax,0
 		mov	cx,8000h
 		mov	di,ax
 		rep	stosw			; Rep when cx >0 Store ax to es:[di]

; grab DIV/0 and SST vectors
 		mov	ax,offset INT00HANDLER	;113h
 		mov	ds:Int00v,ax		; (0000:0000=0CA60h)
 		mov	ds:Int00v+2,cs		; (0000:0002=0F000h)
 		mov	si,Int00v		; (0000:0000=60h)
 		mov	di,Int01v		; (0000:0004=0F4h)

;fill interrupt table with default vector pointing to INT00
 		mov	cx,1FEh
 		rep	movsw			; Rep when cx >0 Mov [si] to es:[di]

; set invalid opcode handler
 		mov	ax,offset INT06HANDLER	;0E0h
 		mov	ds:Int06v,ax		; (0000:0018=0CA60h)
 		mov	ds:Int06v+2,cs		; (0000:001A=0F000h)

; do main ROM checksum. It's odd that if the checksum fails, it
; continues booting anyway. In the IBM PC, the PC halts.
 		cli				; Disable interrupts
 		mov	ax,30h
 		mov	ss,ax
 		mov	sp,100h
 		call	sub_32			; (0FB1)
 		call	DoChecksum		; (0140)
 		jz	loc_6			; Jump if zero
 		mov	si,offset msg1		; (A.00C9='ROM checksum fai')
 		call	prtzstr			; (05E5)
; display boot message and assign key vectors. In the IBM PC,
; the video sign-on is the last thing done after it passes
; all hardware tests and all subsystems are initialized. In the Lomas
; the sign-on message is printed before much of that is done, and
; no hardware tests, other than memory, are performed.
loc_6:						;  xref A.0090
 		mov	si,offset banner	; (A.0000=4Ch)
 		call	prtzstr			; (05E5)
 		call	sub_7			; (0473) vectors 18, 19, 15, 1B, 11 and 1C
 		call	sub_8			; (04B5) vectors 0C, 08, 1A and timers
 		call	sub_2			; (01BF) ram sizing
 		call	sub_28			; (0AD4) vectors 16, 0D, 09 keyboard
 		call	sub_11			; (05F6) vectos 13, 0B, 1E
;*****
; This might be a good place to put the expansion ROM code. But, we may want
;	to swap the position of the disk reset with the two other vector traps
;	although a regular SCSI card is unlikely to trap serial/parallel ports.
;	Since the LomasSCSI has 4 serial ports, unsure if this is important.
;		call	EXPROM
;*****
 		mov	ah,0
 		int	13h			; Disk  dl=drive ?  ah=func 00h
 						;  reset disk, al=return status
 		call	sub_4			; (02BC) vector 14 serial 0
 		call	sub_3			; (0224) vector 17 printer
; re-send EOIs
 		mov	ax,8000h
 		mov	dx,0FF22h		;PCRBASE+ICR+EOIREG
 		out	dx,ax			; port 0FF22h ??I/O Non-standard
 		mov	ax,8000h
 		mov	dx,0FF22h		;PCRBASE+ICR+EOIREG
 		out	dx,ax			; port 0FF22h ??I/O Non-standard
 		sti				; Enable interrupts
 		jmp	SysBoot			; (0151) boot the floppy drive

msg1:		db	'ROM checksum failure', 0Ah, 0Dh, 0

 ;a.00e0
INT06HANDLER:
 		push	bp
 		mov	bp,sp
 		push	ax
 		push	bx
 		push	cx
 		push	dx
 		push	si
 		push	di
 		mov	si,offset msg2
 		call	prtzstr
data_79:
 		inc	word ptr [bp+2]
 		pop	di
 		pop	si
 		pop	dx
 		pop	cx
 		pop	bx
 		pop	AX
		pop	bp
 		iret

msg2:		db	'Bad opcode encountered', 0Ah, 0Dh,0

;a.0113
INT00HANDLER:
 		push	ax
 		push	bx
 		push	cx
 		push	dx
 		push	si
 		push	di
 		mov	si,offset msg3
 		call	prtzstr
 		pop	di
 		pop	si
 		pop	dx
 		pop	cx
 		pop	bx
 		pop	AX
 		iret
;a.0126
msg3:		db	'Bad interrupt received.', 0Ah, 0Dh,0



;===============================================================================
;                              SUBROUTINE
;
;         Called from:   A.008D
;===============================================================================
;a.0140
DoChecksum	proc	near
 		mov	bx,0			; (A.0000=4Ch)
 		mov	al,0
 		mov	cx,2000h

locloop_7:					;  xref A.014C
 		add	al,cs:[bx]
 		inc	bx
 		loop	locloop_7		; Loop if cx > 0

 		test	al,al
 		retn
DoChecksum	endp

;===============================================================================
;  Boot the Diskette
;===============================================================================
;a.0151
SysBoot:					;  xref A.00C6, 017E
 		mov	si,offset msg4		;185h	; (A.0185='Attempting to ')
 		call	prtzstr			; (05E5)
 		xor	ax,ax			; Zero register
 		mov	es,ax
 		mov	cx,4			; 4 retries

locloop_9:					;  xref A.0166
 		push	cx
 		mov	ah,0
 		int	13h			; Disk  dl=drive a  ah=func 00h
 						;  reset disk, al=return status
 		pop	cx
 		jnc	loc_10			; Jump if carry=0
 		loop	locloop_9		; Loop if cx > 0

loc_10:						;  xref A.0164
 		mov	bx,IPLLOC		; 07c00h (0000:7C00=0)
 		mov	dx,ax			; head 0, drive a
 		mov	cx,1			; cyl 0, sector 1
 		mov	al,8			; 8 sectors
 		mov	ah,2			; func 2
 		int	13h			; Disk  dl=drive a  ah=func 02h
 						;  read sectors to memory es:bx
 						;   al=#,ch=cyl,cl=sectr,dh=head
 		jnc	loc_11			; all good, jump to boot code
 		mov	cx,19h
 		call	sub_6			; (0468) delay
 		jmp	short SysBoot		; (0151)

; Jump to the loaded boot sector
loc_11:						;  xref A.0176
		jmpf	0,IPLLOC
;		db	0EAh
; 		dw	7C00h, 0

msg4:		db	'Attempting to boot from diskette.', 0Dh, 0Ah, 0

 ;a.01a9
 ; Get memory size in AX
INT12HANDLER:
        push   ds
        mov    ax,40h
        mov    ds,ax
        mov    ax,ds:main_ram_size	; 40:13 memory size in kbytes (INT 12h)
        pop    ds
        iret

 ;a.01b4
 ; get equipment list
INT11HANDLER:
        push   ds
        mov    ax,40h
        mov    ds,ax
        mov    ax,ds:equip_bits		; 40:10 equip list (INT 11h)
        pop    ds
        iret


;===============================================================================
 ;                              SUBROUTINE
 ;
 ;         Called from:   A.00A4
;===============================================================================
;a.1bf 
; this tests all RAM
sub_2		proc	near
 		cld				; Clear direction
 		push	ds
 		push	es
 		mov	ax,40h
 		mov	ds,ax
 		mov	bx,1000h
 		mov	word ptr ds:main_ram_size,40h	; (0040:0013=280h)
 		mov	ax,55AAh
 		mov	dx,0AA55h
 		mov	di,data_50e		; (1040:03FE=3)
loc_12:						;  xref A.01F2
 		mov	es,bx
 		mov	es:[di],ax
 		push	dx
 		pop	dx
 		cmp	es:[di],ax
 		jne	loc_13			; Jump if not equal
 		inc	word ptr ds:main_ram_size	; (0040:0013=280h)
 		add	bx,40h
 		cmp	bx,0B7FFh
 		jae	loc_13			; Jump if above or =
 		jmp	short loc_12		; (01D9)
loc_13:						;  xref A.01E3, 01F0
 		mov	ax,ds:main_ram_size	; (0040:0013=280h)
 		sub	ax,40h
 		mov	cx,ax
 		mov	bx,1000h
 		mov	ax,0

locloop_14:					;  xref A.0211
 		mov	di,data_49e		; (1000:0000=75h)
 		mov	es,bx
 		push	cx
 		mov	cx,200h
 		rep	stosw			; Rep when cx >0 Store ax to es:[di]
 		pop	cx
 		add	bx,40h
 		loop	locloop_14		; Loop if cx > 0

 		xor	ax,ax			; Zero register
 		mov	ds,ax
 		mov	ax,offset INT12HANDLER	;1A9h
 		mov	ds:Int12v,ax		; (0000:0048=0CB40h)
 		mov	ds:Int12v+2,cs		; (0000:004A=0F000h)
 		pop	es
 		pop	ds
 		retn
sub_2		endp


;===============================================================================
 ;                              SUBROUTINE
 ;
 ;         Called from:   A.00B4
;===============================================================================
;a.0224 
; Grab INT17 (printer) vector
sub_3		proc	near
 		push	ds
 		xor	ax,ax			; Zero register
 		mov	ds,ax
 		mov	ax,offset INT17HANDLER	;244h
 		mov	ds:Int17v,ax		; (0000:005C=0CBC0h)
 		mov	ds:Int17v+2,cs		; (0000:005E=0F000h)
 		mov	ax,40h
 		mov	ds,ax
 		mov	word ptr ds:prn_port_1,0D0h	; (0040:0008=378h)
 		pop	ds
 		mov	ah,1
 		int	17h			; Printer  dx=prn?, ah=func 01h
 						;  initialize, ah=return status
 		retn
sub_3		endp

;a.0244
; Int17 handler
INT17HANDLER:
 		sti				; Enable interrupts
 		push	ds
 		push	dx
 		push	cx
 		push	bx
 		push	si
 		mov	bx,40h
 		mov	ds,bx
 		test	ah,ah
 		jz	loc_16			; Jump if zero
 		dec	ah
 		jz	loc_19			; Jump if zero
 		dec	ah
 		jz	loc_20			; Jump if zero
loc_15:						;  xref A.0277, 02BA
 		pop	si
 		pop	bx
 		pop	cx
 		pop	dx
 		pop	ds
 		iret				; Interrupt return
loc_16:						;  xref A.0251
 		push	ax
 		mov	bl,32h			; '2'
 		xor	cx,cx			; Zero register
 		out	0D0h,al			; port 0D0h

locloop_17:					;  xref A.026E, 0272
 		in	al,0D2h			; port 0D2h
 		test	al,20h			; ' '
 		jz	loc_18			; Jump if zero
 		loop	locloop_17		; Loop if cx > 0

 		dec	bl
 		jnz	locloop_17		; Jump if not zero
 		or	ah,1
 		jmp	short loc_15		; (025B)
;a.0279		
loc_18:						;  xref A.026C
 		mov	al,1
 		out	0D6h,al			; port 0D6h
 		push	ax
 		pop	ax
 		mov	al,0
 		out	0D6h,al			; port 0D6h
 		push	ax
 		pop	ax
 		mov	al,1
 		out	0D6h,al			; port 0D6h
 		pop	ax
 		jmp	short loc_20		; (02AB)
;a.028c
loc_19:						;  xref A.0255
 		push	ax
 		mov	al,1
 		out	0D6h,al			; port 0D6h
 		push	ax
 		pop	ax
 		mov	al,3
 		out	0D6h,al			; port 0D6h
 		push	ax
 		pop	ax
 		mov	al,6
 		out	0D6h,al			; port 0D6h
 		push	ax
 		pop	ax
 		mov	al,4
 		out	0D6h,al			; port 0D6h
 		call	sub_17			; (08C3)
 		mov	al,5
 		out	0D6h,al			; port 0D6h
 		pop	ax
;a.02ab		
loc_20:						;  xref A.0259, 028A
 		push	ax
 		in	al,0D2h			; port 
 		mov	bl,10h
 		test	al,20h			; ' '
 		jz	loc_21			; Jump if zero
 		or	bl,80h
loc_21:						;  xref A.02B2
 		pop	ax
 		mov	ah,bl
 		jmp	short loc_15		; (025B)

;===============================================================================
 ;                              SUBROUTINE
 ;
 ;         Called from:   A.00B1
;===============================================================================
;a.02bc
; Grab INT14 serial vector
sub_4		proc	near
 		push	ds
 		xor	ax,ax	
 		mov	ds,ax
 		mov	ax,offset INT14HANDLER	;2E2h
 		mov	ds:Int14v,ax		; (0000:0050=0CB80h)
 		mov	ds:Int14v+2,cs		; (0000:0052=0F000h)
 		mov	ax,40h
 		mov	ds,ax
; should code bb 00 00
 		mov	bx,offset rs232_port_1		; (0040:0000=0F8h)
; sets serial ports to port 80h (com1) and 0c0h (com2)
 		mov	ax,80h
 		mov	[bx],ax
 		mov	ax,0C0h
 		add	bx,2
 		mov	[bx],ax
 		pop	ds
 		retn
sub_4		endp

;a.02e2
; Int14 Handler
INT14HANDLER:
 		push	ds
 		push	dx
 		push	si
 		push	di
 		push	bx
 		push	cx
 		mov	si,dx
 		shl	si,1			; Shift w/zeros fill
 		mov	dx,40h
 		mov	ds,dx
 		mov	dx,ds:rs232_port_1[si]	; (0040:0000=3F8h)
 		or	dx,dx			; Zero ?
 		jz	loc_24			; Jump if zero
 		or	ah,ah			; Zero ?
 		jz	loc_25			; Jump if zero
 		dec	ah
 		jnz	loc_22			; Jump if not zero
 		jmp	loc_30			; (03AB)
loc_22:						;  xref A.02FF
 		dec	ah
 		jnz	loc_23			; Jump if not zero
 		jmp	loc_35			; (03E6)
loc_23:						;  xref A.0306
 		dec	ah
 		jnz	loc_24			; Jump if not zero
 		jmp	loc_47			; (0454)
loc_24:						;  xref A.02F7, 030D, 03C5, 03DB
 						;            03E3, 0402, 041D, 0465
 		pop	cx
 		pop	bx
 		pop	di
 		pop	si
 		pop	dx
 		pop	ds
 		iret				; Interrupt return

loc_25:						;  xref A.02FB
 		push	ax
 		mov	ah,42h			; 'B'
 		mov	bl,al
 		test	bl,4
 		jz	loc_26			; Jump if zero
 		or	ah,0C0h
loc_26:						;  xref A.0321
 		or	ah,40h			; '@'
 		rol	bl,1			; Rotate
 		mov	al,30h			; '0'
 		and	al,bl
 		or	ah,al
 		rol	bl,1			; Rotate
 		mov	al,0Ch
 		and	al,bl
 		or	ah,al
 		add	dx,2
 		mov	al,0
 		mov	cx,3

;a.0341
locloop_27:					;  xref A.0345
 		out	dx,al			; port 2, DMA-1 bas&add ch 1
 		call	sub_17			; (08C3)
 		loop	locloop_27		; Loop if cx > 0

 		mov	al,40h			; '@'
 		out	dx,al			; port 2, DMA-1 bas&add ch 1
 		call	sub_17			; (08C3)
 		mov	al,ah
 		out	dx,al			; port 2, DMA-1 bas&add ch 1
 		pop	ax
 		rol	al,1			; Rotate
 		rol	al,1			; Rotate
 		rol	al,1			; Rotate
 		and	al,7
 		push	dx
 		cmp	dx,82h
 		ja	loc_28			; Jump if above
; set timer register for right UART
 		mov	dx,0FF5Ah		;PCRBASE+T1CR+TMRCA
 		jmp	short loc_29		; (0368)
loc_28:						;  xref A.035E
 		mov	dx,0FF52h		;PCRBASE+T0CR+TMRCA
loc_29:						;  xref A.0363
 		mov	ah,0
 		shl	ax,1			; Shift w/zeros fill
 		shl	ax,1			; Shift w/zeros fill
 		mov	bx,offset data_81	; (A.038B=38h)
 		add	bx,ax
 		mov	ax,cs:[bx]
 		out	dx,ax			; port 0FF52h PCRBASE+T0CR+TMRCA
 		add	dx,2			; go to count register B
 		add	bx,2
 		mov	ax,cs:[bx]
 		call	sub_17			; (08C3)
 		out	dx,ax			; port 0FF54h
 		pop	dx			; PCRBASE+T0CR+TMRCB
 		sub	dx,2			; back to CRA?
 		jmp	loc_47			; (0454)

; parameters to program internal timers? Read as words.
;a.038b
data_81:						; xref A.036E
;     		db	 38h, 02h, 38h, 02h,0A1h, 01h,0A1h
;     		db	 01h,0D0h, 00h,0D1h, 00h, 68h
;     		db	 00h, 68h, 00h, 34h, 00h, 34h
;     		db	 00h, 1Ah, 00h, 1Ah, 00h, 0Dh
;     		db	 00h, 0Dh, 00h, 06h, 00h, 07h
; 		db	 00h
		dw	0238h, 0238h, 01a1h, 01a1h
		dw	00d0h, 00d1h, 0068h, 0068h
		dw	0034h, 0034h, 001ah, 001ah
		dw	000dh, 000dh, 0006h, 0007h


loc_30:						;  xref A.0301
 		push	ax
 		add	dx,2
 		mov	al,37h			; '7'
 		out	dx,al			; port 2, DMA-1 bas&add ch 1
 		xor	cx,cx			; Zero register
 		mov	bl,4

locloop_31:					;  xref A.03BB, 03BF
 		in	al,dx			; port 2, DMA-1 bas&add ch 1
 		test	al,80h
 		jnz	loc_32			; Jump if not zero
 		loop	locloop_31		; Loop if cx > 0

 		dec	bl
 		jnz	locloop_31		; Jump if not zero
 		pop	ax
 		or	ah,80h
 		jmp	loc_24			; (0312)
loc_32:						;  xref A.03B9
 		xor	cx,cx			; Zero register
 		mov	bl,2

locloop_33:					;  xref A.03D1, 03D5
 		in	al,dx			; port 2, DMA-1 bas&add ch 1
 		test	al,1
 		jnz	loc_34			; Jump if not zero
 		loop	locloop_33		; Loop if cx > 0

 		dec	bl
 		jnz	locloop_33		; Jump if not zero
 		pop	ax
 		or	ah,80h
 		jmp	loc_24			; (0312)
loc_34:						;  xref A.03CF
 		sub	dx,2
 		pop	ax
 		out	dx,al			; port 0, DMA-1 bas&add ch 0
 		jmp	loc_24			; (0312)
loc_35:						;  xref A.0308
; 		and	byte ptr ds:[71h],7Fh	; (A.0071=0) signbit
		and	byte ptr ds:[signbit],7Fh
 		add	dx,2
 		mov	al,37h			; '7'
 		out	dx,al			; port 2, DMA-1 bas&add ch 1
 		xor	cx,cx			; Zero register
 		mov	bl,4

;a.03f5
locloop_36:					;  xref A.03FA, 03FE
 		in	al,dx			; port 2, DMA-1 bas&add ch 1
 		test	al,80h
 		jnz	loc_38			; Jump if not zero
 		loop	locloop_36		; Loop if cx > 0

 		dec	bl
 		jnz	locloop_36		; Jump if not zero
loc_37:						;  xref A.0411
 		mov	ah,80h
 		jmp	loc_24			; (0312)
loc_38:						;  xref A.03F8, 040F
 		in	al,dx			; port 2, DMA-1 bas&add ch 1
 		test	al,2
 		jnz	loc_39			; Jump if not zero
; 		test	byte ptr ds:[71h],80h	; (A.0071=0)
		test	byte ptr ds:[signbit],80h
 		jz	loc_38			; Jump if zero
 		jmp	short loc_37		; (0400)
loc_39:						;  xref A.0408
 		call	sub_5			; (0420)
 		and	ah,00011110b		;1Eh
 		sub	dx,2
 		in	al,dx			; port 0, DMA-1 bas&add ch 0
 		jmp	loc_24			; (0312)

;===============================================================================
 ;                              SUBROUTINE
 ;
 ;         Called from:   A.0413, 0458
;===============================================================================
; Tests some variable for bit flags. Maybe serial errors?
;a.0420
sub_5		proc	near
 		mov	ah,0
 		test	al,1
 		jz	loc_40			; Jump if zero
 		or	ah,20h			; ' '
loc_40:						;  xref A.0424
 		test	al,2
 		jz	loc_41			; Jump if zero
 		or	ah,1
loc_41:						;  xref A.042B
 		test	al,4
 		jz	loc_42			; Jump if zero
 		or	ah,40h			; '@'
loc_42:						;  xref A.0432
 		test	al,8
 		jz	loc_43			; Jump if zero
 		or	ah,4
loc_43:						;  xref A.0439
 		test	al,10h
 		jz	loc_44			; Jump if zero
 		or	ah,2
loc_44:						;  xref A.0440
 		test	al,20h			; ' '
 		jz	loc_45			; Jump if zero
 		or	ah,8
loc_45:						;  xref A.0447
 		test	al,40h			; '@'
 		jz	loc_ret_46		; Jump if zero
 		or	ah,10h

loc_ret_46:					;  xref A.044E
 		retn
sub_5		endp

loc_47:						;  xref A.030F, 0388
 		add	dx,2
 		in	al,dx			; port 4, DMA-1 bas&add ch 2
 		call	sub_5			; (0420)
 		and	al,80h
 		test	al,al
 		mov	al,0F0h
 		jnz	loc_48			; Jump if not zero
 		mov	al,0
loc_48:						;  xref A.0461
 		jmp	loc_24			; (0312)

;===============================================================================
 ;                              SUBROUTINE
 ;
 ;         Called from:   A.017B
;===============================================================================
;a.0468
; delay loop CX=# of msec?
sub_6		proc	near
loc_49:						;  xref A.0470
 		sti				; Enable interrupts
 		push	cx
 		xor	cx,cx			; Zero register

locloop_50:					;  xref A.046C
 		loop	locloop_50		; Loop if cx > 0

 		pop	cx
 		dec	cx
 		jnz	loc_49			; Jump if not zero
 		retn
sub_6		endp


;===============================================================================
 ;                              SUBROUTINE
 ;
 ;         Called from:   A.009E
;===============================================================================
; setup certain handlers to default to IRET and set equipment bits
;a.0473
sub_7		proc	near
 		push	ds
 		xor	ax,ax			; Zero register
 		mov	ds,ax
 		mov	ax,offset DefIRET	; default IRET 596h
 		mov	ds:Int18v,ax		; (0000:0060=0CD00h)
 		mov	ds:Int19v,ax		; (0000:0064=0CC60h)
 		mov	ds:Int18v+2,cs		; (0000:0062=0F000h)
 		mov	ds:Int19v+2,cs		; (0000:0066=0F000h)
 		mov	ds:Int15v,ax		; (0000:0054=0CBA0h)
 		mov	ds:Int15v+2,cs		; (0000:0056=0F000h)
 		mov	ds:Int1Bv,ax		; (0000:006C=0D1C0h)
 		mov	ds:Int1Bv+2,cs		; (0000:006E=0F000h)
 		mov	ds:Int1Cv,ax		; (0000:0070=0CC00h)
 		mov	ds:Int1Cv+2,cs		; (0000:0072=0F000h)

 		mov	ax,offset INT11HANDLER	; equip list 1B4h
 		mov	ds:Int11v,ax		; (0000:0044=0CB20h)
 		mov	ds:Int11v+2,cs		; (0000:0046=0F000h)
 		mov	ax,40h
 		mov	ds,ax
; equipment list - assumes:
;	01 0 0 010 0 01 10 11 0 1 = 446Dh
;	LP X G SER X FD VM KM X B
;
;	BIT 15,14 = NUMBER OF PRINTERS ATTACHED
;	BIT 13 NOT USED
;	BIT 12 = GAME I/O ATTACHED
;	BIT 11,10,9 = NUMBER OF RS232 CARDS ATTACHED
;	BIT 8 UNUSED
;	BIT 7,6 = NUMBER OF DISKETTE DRIVES
;		00=1, 01=2, 10-3, 11=4 ONLY IF BIT 0 = 1
;	BIT 5,4 = INITIAL VIDEO MODE
;			00 - UNUSED
;			01 - 40X25 BW USING COLOR CARD
;			10 - 80X25 BW USING COLOR CARD
;			11 - 80X25 BW USING BW CARD
;	BIT 3,2 = PLANAR RAM SIZE (00=16K,01=32K,10=48K,11=64K)
;	BIT 1 NOT USED
;	BIT 0 = IPL FROM DISKETTE -- THIS BIT INDICATES THAT THERE ARE DISKETTE
;		DRIVES ON THE SYSTEM
 		mov	ax,446Dh		; 01000100 / 01101101
 		mov	ds:equip_bits,ax	; (0040:0010=4467h)
 		pop	ds
 		retn
sub_7		endp


;===============================================================================
 ;                              SUBROUTINE
 ;
 ;         Called from:   A.00A1
;===============================================================================
; setup default handlers 08h, 0ch, and 1ah.
;a.04b5
sub_8		proc	near
 		push	ds
 		pushf				; Push flags
 		cli				; Disable interrupts
loc_51:
 		xor	ax,ax			; Zero register
 		mov	ds,ax
;***** Note: the following codes as B8 0511 while the original
;***** codes as B8 0513.
 		mov	ax,offset INT0CHANDLER	;513h
;*****
 		mov	ds:Int0Cv,ax		; (0000:0030=0CE80h)
 		mov	ds:Int0Cv+2,cs		; (0000:0032=0F000h)
 		mov	ax,offset INT08HANDLER	;521h
 		mov	ds:Int08v,ax		; (0000:0020=0FEA5h)
 		mov	ds:Int08v+2,cs		; (0000:0022=0F000h)
 		mov	ax,offset INT1AHANDLER	;562h
 		mov	ds:Int1Av,ax		; (0000:0068=0CBE0h)
 		mov	ds:Int1Av+2,cs		; (0000:006A=0F000h)
 		mov	ax,40h
 		mov	ds,ax
 		xor	ax,ax			; Zero register
 		mov	ds:timer_low,ax		; (0040:006C=6980h)
 		mov	ds:timer_hi,ax		; (0040:006E=16h)
 		mov	ds:timer_rolled,al	; (0040:0070=0)
 		mov	si,offset data_82	; (A.050A=36h)
 		mov	cx,3
 		mov	dx,40h

locloop_52:					;  xref A.04FE
 		lods	byte ptr cs:[si]	; String [si] to al
 		out	43h,al			; port 43h, 8253 timer control
 		lods	byte ptr cs:[si]	; String [si] to al
 		out	dx,al			; port 40h, 8253 timer 0 clock
 		lods	byte ptr cs:[si]	; String [si] to al
 		out	dx,al			; port 40h, 8253 timer 0 clock
 		inc	dx
 		loop	locloop_52		; Loop if cx > 0

 		mov	dx,0FF38h		;PCRBASE+ICR+INT0CR
 		mov	ax,0
 		out	dx,ax			; port 0FF38h ??I/O Non-standard
 		popf				; Pop flags
 		pop	ds
 		retn
sub_8		endp

; 80186 timer 0 configuration bytes
;a.050a
data_82:	db	36h, 00h, 00h, 76h,0A9h, 04h,0B6h

; a.0511
INT0CHANDLER:
 		test	ax,5004h
 		push	dx
 		mov	ax,8000h
 		mov	dx,0FF22h		;PCRBASE+ICR+EOIREG
 		out	dx,ax
 		pop	dx
 		pop	ax
 		INT	08h 
 		iret

;a.0521
INT08HANDLER:
 		push	ax
 		push	dx
 		push	ds
 		mov	ax,40h
 		mov	ds,ax
 		inc	word ptr ds:[timer_low]
 		jnz	loc_53
 		inc	word ptr ds:[timer_hi]
loc_53:
 		cmp	word ptr ds:[timer_hi],18h	; (A.006E=0BF00h)
 		jne	loc_54				; Jump if not equal
 		cmp	word ptr ds:[timer_low],0B0h	; (A.006C=0BEh)
 		jne	loc_54				; Jump if not equal
 		mov	word ptr ds:[timer_hi],0	; (A.006E=0BF00h)
 		mov	word ptr ds:[timer_low],0	; (A.006C=0BEh)
 		mov	byte ptr ds:[timer_rolled],1	; (A.0070=4)
loc_54:							;  xref A.0538, 0540
 		dec	byte ptr ds:[dsk_motor_tmr]	; (A.0040=0ABh)
 		jnz	loc_55				; Jump if not zero
 		call	sub_19				; (09AD)
loc_55:							;  xref A.0557
 		int	1Ch				; Timer break (call each 18.2ms)
 		pop	ds
 		pop	dx
 		pop	ax
 		iret				; Interrupt return

;a.0562
INT1AHANDLER:
 		push	ds
 		cli				; Disable interrupts
 		push	ax
 		mov	ax,40h
 		mov	ds,ax
 		pop	ax
 		or	ah,ah			; Zero ?
 		jz	loc_57			; Jump if zero
 		dec	ah
 		jz	loc_58			; Jump if zero
loc_56:						;  xref A.0585, 0594
 		pop	ds
 		iret				; Interrupt return

loc_57:							;  xref A.056D
 		mov	al,byte ptr ds:[timer_rolled]	; (A.0070=4)
 		mov	byte ptr ds:[timer_rolled],0	; (A.0070=4)
 		mov	cx,word ptr ds:[timer_hi]	; (A.006E=0BF00h)
 		mov	dx,word ptr ds:[timer_low]	; (A.006C=0BEh)
 		jmp	short loc_56			; (0573)
loc_58:							;  xref A.0571
 		mov	word ptr ds:[timer_low],dx	; (A.006C=0BEh)
 		mov	word ptr ds:[timer_hi],cx	; (A.006E=0BF00h)
 		mov	byte ptr ds:[timer_rolled],0	; (A.0070=4)
 		jmp	short loc_56			; (0573)
 DefIRET:	iret	

 DynHalt:					;  xref A.004B, 0598
 		cli				; Disable interrupts
 		jmp	short DynHalt		; (0597)

;a.059a
;* No entry point to code
; Doesn't seem to have an absolute reference anywhere
loc_59:
 		pushf				; Push flags
 		cli				; Disable interrupts
 		push	ds
 		mov	ax,40h
 		mov	ds,ax
 		or	dh,dh			; Zero ?
 		jz	loc_62			; Jump if zero
loc_60:						;  xref A.05AF
 		mov	bl,6
 		call	BEEP			; (05C3)

locloop_61:					;  xref A.05AB
 		loop	locloop_61		; Loop if cx > 0

 		dec	dh
 		jnz	loc_60			; Jump if not zero
loc_62:						;  xref A.05A4, 05BA
 		mov	bl,1
 		call	BEEP			; (05C3)

locloop_63:					;  xref A.05B6
 		loop	locloop_63		; Loop if cx > 0

 		dec	dl
 		jnz	loc_62			; Jump if not zero

locloop_64:					;  xref A.05BC
 		loop	locloop_64		; Loop if cx > 0


locloop_65:					;  xref A.05BE
 		loop	locloop_65		; Loop if cx > 0

 		pop	ds
 		popf				; Pop flags
 		retn

;===============================================================================
 ;                              SUBROUTINE
 ;
 ;         Called from:   A.05A8, 05B3, 16C8
;===============================================================================
;a.05c3
; should ax,cx be preserved?
BEEP		proc	near
 		mov	al,0B6h
 		out	43h,al			; port 43h, 8253 timer control
 		mov	ax,533h
 		out	42h,al			; port 42h, 8253 timer 2 spkr
 		mov	al,ah
 		out	42h,al			; port 42h, 8253 timer 2 spkr
 		in	al,61h			; port 61h, 8255 port B, read
 		mov	ah,al
 		or	al,3
 		out	61h,al			; port 61h, 8255 B - spkr, etc
 		sub	cx,cx

BEEP_1:						;  xref A.05DA, 05DE
 		loop	BEEP_1			; Loop if cx > 0
 		dec	bl
 		jnz	BEEP_1			; Jump if not zero
 		mov	al,ah
 		out	61h,al			; port 61h, 8255 B - spkr, etc
 		retn
BEEP		endp


;===============================================================================
 ;                              SUBROUTINE
 ;
 ;         Called from:   A.0095, 009B, 0154, 0BA9
;===============================================================================
;a.05e5
prtzstr		proc	near
loc_67:						;  xref A.05F3
 		mov	al,cs:[si]
 		inc	si
 		test	al,al
 		jz	loc_ret_68		; Jump if zero
 		mov	bh,0
 		mov	ah,0Eh
 		int	10h			; Video display   ah=functn 0Eh
 						;  write char al, teletype mode
 		jmp	short loc_67		; (05E5)

loc_ret_68:					;  xref A.05EB
 		retn
 prtzstr	endp


;===============================================================================
 ;                              SUBROUTINE
 ;
 ;         Called from:   A.00AA
;===============================================================================
;a.05f6
; grab disk vectors and second serial hardware IRQ
sub_11		proc	near
 		push	ds
 		xor	ax,ax			; Zero register
 		mov	ds,ax
 		mov	ax,offset INT13HANDLER	;61Bh
 		mov	ds:Int13v,ax		; (0000:004C=0CF60h)
 		mov	ds:Int13v+2,cs		; (0000:004E=0F000h)
 		mov	ax,offset INT0BHANDLER	;7E9h
 		mov	ds:Int0Bv,ax		; (0000:002C=0CE80h)
 		mov	ds:Int0Bv+2,cs		; (0000:002E=0F000h)
 		mov	ax,offset INT_1E	;0AC9h
 		mov	ds:Int1Ev,ax		; (0000:0078=0CA60h)
 		mov	word ptr ds:Int1Ev+2,cs	; (0000:007A=0F000h)
 		pop	ds
 		retn
sub_11		endp

;a.061b
; INT13 Handler
INT13HANDLER:
 		sti				; Enable interrupts
 		push	bx
 		push	cx
 		push	ds
 		push	si
 		push	di
 		push	bp
 		push	dx
 		mov	bp,sp
 		mov	si,40h
 		mov	ds,si
 		call	sub_12			; (0649)
 		mov	bx,4
 		call	GetpDPB			; (0834)
 		mov	ds:dsk_motor_tmr,ah	; (0040:0040=0)
 		mov	ah,ds:dsk_ret_code	; (0040:0041=0)
 		cmp	ah,1
 		cmc				; Complement carry
 		pop	dx
 		pop	bp
 		pop	di
 		pop	si
 		pop	ds
 		pop	cx
 		pop	bx
 		retf	2			; Return far

;===============================================================================
;                               SUBROUTINE
;
;         Called from:   A.062A
;===============================================================================
;a.0649
; setup for disk call?
sub_12		proc	near
 		mov	dh,al
 		mov	ds:gen_int_occured,al	; (0040:006B=0)
 		and	byte ptr ds:dsk_motor_stat,3Fh	; (0040:003F=0) '?'
 		mov	al,0FFh
 		mov	ds:dsk_motor_tmr,al	; (0040:0040=0)
 		or	ah,ah			; Zero ?
 		jz	loc_74			; Jump if zero
 		dec	ah
 		jnz	loc_69			; Jump if not zero
 		jmp	short loc_75		; (06BC)
 		db	90h
loc_69:						;  xref A.065E
 		mov	byte ptr ds:dsk_ret_code,0	; (0040:0041=0)
 		cmp	dl,4
 		jae	loc_73			; Jump if above or =
 		dec	ah
 		jnz	loc_70			; Jump if not zero
 		jmp	short loc_76		; (06C0)
 		db	90h
loc_70:						;  xref A.066F
 		dec	ah
 		jnz	loc_71			; Jump if not zero
 		jmp	loc_80			; (0714)
loc_71:						;  xref A.0676
 		dec	ah
 		jnz	loc_72			; Jump if not zero
 		jmp	short loc_77		; (06C7)
 		db	90h
loc_72:						;  xref A.067D
 		dec	ah
 		jnz	loc_73			; Jump if not zero
 		jmp	short loc_78		; (06CE)
 		db	90h
loc_73:						;  xref A.066B, 0684
 		mov	byte ptr ds:dsk_ret_code,1	; (0040:0041=0)
 		retn
loc_74:						;  xref A.065A
 		call	sub_23			; (0A4C)
 		call	sub_26			; (0A9E)
 		mov	ah,3
 		call	sub_13			; (0808)
 		mov	bx,1
 		call	GetpDPB			; (0834)
 		mov	bx,3
 		call	GetpDPB			; (0834)
 		mov	byte ptr ds:[dsk_ret_code],0	; (A.0041=0B9h)
 		mov	byte ptr ds:[dsk_recal_stat],0	; (A.003E=0FBh)
 		mov	byte ptr ds:[dsk_motor_stat],0	; (A.003F=0F3h)
 		call	sub_26			; (0A9E)
 		call	sub_19			; (09AD)
 		retn
loc_75:						;  xref A.0660
 		mov	al,byte ptr ds:[dsk_ret_code]	; (A.0041=0B9h)
 		retn
;a.06c0
loc_76:						;  xref A.0671, 06CC
 		call	sub_18			; (08E7)
 		mov	ah,66h			; 'f'
 		jmp	short loc_81		; (071E)
loc_77:						;  xref A.067F
 		or	byte ptr ds:dsk_motor_stat,40h	; (0040:003F=0) '@'
 		jmp	short loc_76		; (06C0)
loc_78:						;  xref A.0686
 		or	byte ptr ds:dsk_motor_stat,80h	; (0040:003F=0)
 		call	sub_18			; (08E7)
 		mov	ah,4Dh			; 'M'
 		push	ax
 		push	bx
 		push	dx
 		mov	bx,8
 		call	GetpDPB			; (0834)
 		mov	al,ah
 		xor	ah,ah			; Zero register
 		shl	ax,1			; Shift w/zeros fill
 		shl	ax,1			; Shift w/zeros fill
 		mov	dx,0FFD8h		;PCRBASE+DMA1+DMATC
 		out	dx,ax			; port 0FFD8h ??I/O Non-standard
 		pop	dx
 		pop	bx
 		pop	ax
 		jmp	short loc_81		; (071E)
loc_79:						;  xref A.075C
 		mov	bx,7
 		call	GetpDPB			; (0834)
 		mov	bx,9
 		call	GetpDPB			; (0834)
 		mov	bx,0Fh
 		call	GetpDPB			; (0834)
 		mov	ax,word ptr ds:[gen_io_ptr]	; (A.0067=8C00h)
 		mov	dx,0FFDAh		;PCRBASE+DMA1+DMACW
 		out	dx,ax			; port 0FFDAh ??I/O Non-standard
 		mov	bx,11h
 		call	GetpDPB			; (0834)
 		jmp	short loc_85		; (078F)
 		db	90h
;a.0714
loc_80:						;  xref A.0678
 		or	byte ptr ds:[dsk_motor_stat],80h	; (A.003F=0F3h)
 		call	sub_18			; (08E7)
 		mov	ah,45h			; 'E'
loc_81:						;  xref A.06C5, 06F0
 		jnc	loc_82			; Jump if carry=0
 		mov	byte ptr ds:[dsk_ret_code],9	; (A.0041=0B9h)
 		mov	al,0
 		retn
loc_82:						;  xref A.071E
 		call	sub_26			; (0A9E)
 		and	byte ptr ds:[dsk_recal_stat],7Fh	; (A.003E=0FBh)
 		push	ax
 		call	sub_20			; (09B6)
 		call	sub_24			; (0A59)
 		jc	loc_83			; Jump if carry Set
 		call	sub_15			; (0845)
;a.073c
loc_83:						;  xref A.0737
 		pop	ax
 		mov	bh,ah
 		jc	loc_86			; Jump if carry Set
 		call	sub_26			; (0A9E)
 		call	sub_13			; (0808)
 		mov	ah,[bp+1]
 		shl	ah,1			; Shift w/zeros fill
 		shl	ah,1			; Shift w/zeros fill
 		and	ah,4
 		or	ah,[bp]
 		call	sub_13			; (0808)
 		cmp	bh,4Dh			; 'M'
 		jne	loc_84			; Jump if not equal
 		jmp	short loc_79		; (06F2)
;a.075e
loc_84:						;  xref A.075A
 		mov	ah,ch
 		call	sub_13			; (0808)
 		mov	ah,[bp+1]
 		call	sub_13			; (0808)
 		mov	ah,cl
 		call	sub_13			; (0808)
 		mov	bx,7
 		call	GetpDPB			; (0834)
 		mov	ah,cl
 		mov	bx,9
 		call	GetpDPB			; (0834)
 		mov	bx,0Bh
 		call	GetpDPB			; (0834)
 		mov	ax,word ptr ds:[gen_io_ptr]	; (A.0067=8C00h)
 		mov	dx,0FFDAh		;PCRBASE+DMA1+DMACW
 		out	dx,ax			; port 0FFDAh ??I/O Non-standard
 		mov	bx,0Dh
 		call	GetpDPB			; (0834)
;a.078f
loc_85:						;  xref A.0711
 		call	sub_21			; (09BF)
loc_86:						;  xref A.073F
 		jc	loc_90			; Jump if carry Set
 		call	sub_22			; (0A08)
 		jc	loc_ret_89		; Jump if carry Set
 		cld				; Clear direction
 		mov	si,offset nec_stat		; (0040:0042=0)
 		lodsb				; String [si] to al
 		and	al,0C0h
 		jz	loc_91			; Jump if zero
 		cmp	al,40h			; '@'
 		jne	loc_87			; Jump if not equal
 		lodsb				; String [si] to al
 		shl	al,1			; Shift w/zeros fill
 		mov	ah,4
 		jc	loc_88			; Jump if carry Set
 		shl	al,1			; Shift w/zeros fill
 		shl	al,1			; Shift w/zeros fill
 		mov	ah,10h
 		jc	loc_88			; Jump if carry Set
 		shl	al,1			; Shift w/zeros fill
 		mov	ah,8
 		jc	loc_88			; Jump if carry Set
 		shl	al,1			; Shift w/zeros fill
 		shl	al,1			; Shift w/zeros fill
 		mov	ah,4
 		jc	loc_88			; Jump if carry Set
 		shl	al,1			; Shift w/zeros fill
 		mov	ah,3
 		jc	loc_88			; Jump if carry Set
 		shl	al,1			; Shift w/zeros fill
 		mov	ah,2
 		jc	loc_88			; Jump if carry Set
loc_87:						;  xref A.07A4
 		mov	ah,20h			; ' '
loc_88:						;  xref A.07AB, 07B3, 07B9, 07C1
 						;            07C7, 07CD
 		or	byte ptr ds:[dsk_ret_code],ah	; (A.0041=0B9h)
 		call	sub_27			; (0AB2)

loc_ret_89:					;  xref A.0797
 		retn
;a.07d9
loc_90:						;  xref A.0792
 		call	sub_23			; (0A4C)
 		call	sub_22			; (0A08)
 		call	sub_26			; (0A9E)
 		retn
loc_91:						;  xref A.07A0
 		call	sub_27			; (0AB2)
 		xor	ah,ah			; Zero register
 		retn
sub_12		endp

;a.07e9
; Int0B hardware IQR
INT0BHANDLER:				
 		push	ax
 		push	bx
 		push	cx
 		push	dx
 		push	ds
 		call	sub_23			; (0A4C)
 		mov	ax,40h
 		mov	ds,ax
 		or	byte ptr ds:dsk_recal_stat,80h	; (0040:003E=0)
 		mov	ax,8000h
 		mov	dx,0FF22h		;PCRBASE+ICR+EOIREG
 		out	dx,ax			; port 0FF22h ??I/O Non-standard
 		pop	ds
 		pop	dx
 		pop	cx
 		pop	bx
 		pop	ax
 		iret				; Interrupt return

;===============================================================================
 ;                              SUBROUTINE
 ;
 ;         Called from:   A.0697, 0744, 0754, 0760, 0766, 076B, 0859
 ;                             085F, 086C, 0872, 0877, 08A2, 0993, 0A63
 ;                             0A69, 0AA1
;===============================================================================
;a.0808
sub_13		proc	near
loc_92:						;  xref A.0842
 		push	dx
 		push	cx
 		mov	dx,90h
 		xor	cx,cx			; Zero register

locloop_93:					;  xref A.0814
 		in	al,dx			; port 90h ??I/O Non-standard
 		test	al,40h			; '@'
 		jz	loc_95			; Jump if zero
 		loop	locloop_93		; Loop if cx > 0

loc_94:						;  xref A.0828
 		or	byte ptr ds:[dsk_ret_code],80h	; (A.0041=0B9h)
 		pop	cx
 		pop	dx
 		stc				; Set carry flag
 		retn
loc_95:						;  xref A.0812
 		xor	cx,cx			; Zero register

locloop_96:					;  xref A.0826
 		in	al,dx			; port 0, DMA-1 bas&add ch 0
 		test	al,80h
 		jnz	loc_97			; Jump if not zero
 		loop	locloop_96		; Loop if cx > 0

 		jmp	short loc_94		; (0816)
loc_97:						;  xref A.0824
 		mov	al,ah
 		mov	dx,92h
 		out	dx,al			; port 92h ??I/O Non-standard
 		pop	cx
 		pop	dx
 		clc				; Clear carry flag
 		retn
sub_13		endp


;===============================================================================
 ;                              SUBROUTINE
 ;
 ;         Called from:   A.0630, 069D, 06A3, 06DE, 06F5, 06FB, 0701
 ;                             070E, 0771, 0779, 077F, 078C, 0884, 0979
 ;                             0ABF
;===============================================================================
; Get disk parameter table
;a.0834
GetpDPB		proc	near
 		push	ds
 		sub	ax,ax
 		mov	ds,ax
 		lds	si,dword ptr ds:Int1Ev	; (0000:0078=0CA60h) Load seg:offset p
 		shr	bx,1			; Shift w/zeros fill
 		mov	ah,[bx+si]
 		pop	ds
 		jc	loc_92			; Jump if carry Set
 		retn
GetpDPB		endp


;===============================================================================
 ;                              SUBROUTINE
 ;
 ;         Called from:   A.0739
;===============================================================================
;a.0845
sub_15		proc	near
 		push	cx
 		mov	al,1
 		mov	cl,dl
 		rol	al,cl			; Rotate
 		pop	cx
 		test	al,byte ptr ds:[dsk_recal_stat]	; (A.003E=0FBh)
 		jnz	loc_98			; Jump if not zero
 		or	byte ptr ds:[dsk_recal_stat],al	; (A.003E=0FBh)
 		mov	ah,7
 		call	sub_13			; (0808)
 		mov	ah,[bp]
 		call	sub_13			; (0808)
 		call	sub_16			; (0898)
 		jc	loc_ret_102		; Jump if carry Set
 		call	sub_26			; (0A9E)
loc_98:						;  xref A.0851
 		mov	ah,0Fh
 		call	sub_13			; (0808)
 		mov	ah,[bp]
 		call	sub_13			; (0808)
 		mov	ah,ch
 		call	sub_13			; (0808)
 		call	sub_16			; (0898)
 		pushf				; Push flags
 		call	sub_26			; (0A9E)
 		mov	bx,12h
 		call	GetpDPB			; (0834)
 		push	cx
loc_99:						;  xref A.0893
 		mov	cx,44Ch
 		or	ah,ah			; Zero ?
 		jz	loc_101			; Jump if zero

locloop_100:					;  xref A.088F
 		loop	locloop_100		; Loop if cx > 0

 		dec	ah
 		jmp	short loc_99		; (0888)
loc_101:					;  xref A.088D
 		pop	cx
 		popf				; Pop flags

loc_ret_102:					;  xref A.0865
 		retn
sub_15		endp


;===============================================================================
 ;                              SUBROUTINE
 ;
 ;         Called from:   A.0862, 087A
;===============================================================================
;a.0898
sub_16		proc	near
 		push	ax
 		push	cx
 		mov	cx,4000h

locloop_103:					;  xref A.08AE, 08B3
 		call	sub_17			; (08C3)
 		mov	ah,8
 		call	sub_13			; (0808)
 		call	sub_25			; (0A87)
 		test	al,20h			; ' '
 		jnz	loc_104			; Jump if not zero
 		cmp	al,80h
 		loopz	locloop_103		; Loop if zf=1, cx>0

 		call	sub_25			; (0A87)
 		loop	locloop_103		; Loop if cx > 0

 		call	sub_25			; (0A87)
 		stc				; Set carry flag
 		pop	cx
 		pop	ax
 		retn
loc_104:					;  xref A.08AA
 		call	sub_25			; (0A87)
 		clc				; Clear carry flag
 		pop	cx
 		pop	ax
 		retn
sub_16		endp


;===============================================================================
 ;                              SUBROUTINE
 ;
 ;         Called from:   A.02A3, 0342, 034A, 0380, 089D
;===============================================================================
;a.08c3
sub_17		proc	near
 		push	cx
 		mov	cx,100h

locloop_105:					;  xref A.08C9
 		push	ax
 		pop	ax
 		loop	locloop_105		; Loop if cx > 0

 		pop	cx
 		retn
sub_17		endp

 			                        ;* No entry point to code
 		push	ax
 		push	bx
 		push	cx
 		xor	cx,cx			; Zero register
 		mov	bx,14h

locloop_106:					;  xref A.08D9, 08DE
 		in	al,90h			; port 90h ??I/O Non-standard
 		test	al,80h
 		loopz	locloop_106		; Loop if zf=1, cx>0

 		jz	loc_107			; Jump if zero
 		dec	bx
 		jnz	locloop_106		; Jump if not zero
loc_107:					;  xref A.08DB
 		call	sub_23			; (0A4C)
 		pop	cx
 		pop	bx
 		pop	ax
 		retn

;===============================================================================
 ;                              SUBROUTINE
 ;
 ;         Called from:   A.06C0, 06D3, 0719
;===============================================================================
;a.08e7
sub_18		proc	near
 		push	ax
 		push	bx
 		push	cx
 		push	dx
 		push	si
 		push	dx
 		mov	ax,es
 		mov	cx,bx
 		rol	ax,1			; Rotate
 		rol	ax,1			; Rotate
 		rol	ax,1			; Rotate
 		rol	ax,1			; Rotate
 		mov	bx,0Fh
 		and	bx,ax
 		and	ax,0FFF0h
 		add	ax,cx
 		jnc	loc_108			; Jump if carry=0
 		inc	bx

 ; DMA1 transaction setup
 ;a.0906
loc_108:					;  xref A.0903
 		test	byte ptr ds:dsk_motor_stat,80h	; (0040:003F=0)
 		jz	loc_109		; Jump if zero
 		mov	dx,0FFD0h		;PCRBASE+DMA1+DMASP
 		out	dx,ax			; port 0FFD0h ??I/O Non-standard
 		mov	dx,0FFD2h		;PCRBASE+DMA1+DMASP1
 		mov	ax,bx
 		out	dx,ax			; port 0FFD2h ??I/O Non-standard
 		xor	ax,ax			; Zero register
 		mov	dx,0FFD6h		;PCRBASE+DMA1+DMADP1
 		out	dx,ax			; port 0FFD6h ??I/O Non-standard
 		mov	dx,0FFD4h		;PCRBASE+DMA1+DMADP
 		mov	ax,0A0h
 		out	dx,ax			; port 0FFD4h ??I/O Non-standard
 		mov	si,1786h
 		jmp	short loc_111		; (096A)
loc_109:					;  xref A.090B
 		test	byte ptr ds:dsk_motor_stat,40h	; (0040:003F=0) '@'
 		jnz	loc_110		; Jump if not zero
 		mov	dx,0FFD4h		;PCRBASE+DMA1+DMADP
 		out	dx,ax			; port 0FFD4h ??I/O Non-standard
 		mov	dx,0FFD6h		;PCRBASE+DMA1+DMADP1
 		mov	ax,bx
 		out	dx,ax			; port 0FFD6h ??I/O Non-standard
 		xor	ax,ax			; Zero register
 		mov	dx,0FFD2h		;PCRBASE+DMA1+DMASP1
 		out	dx,ax			; port 0FFD2h ??I/O Non-standard
 		mov	dx,0FFD0h		;PCRBASE+DMA1+DMASP
 		mov	ax,0A0h
 		out	dx,ax			; port 0FFD0h ??I/O Non-standard
 		mov	si,0A346h
 		jmp	short loc_111		; (096A)
;a.094c
loc_110:					;  xref A.092E
 		mov	ax,0E000h
 		mov	dx,0FFD4h		;PCRBASE+DMA1+DMADP
 		out	dx,ax			; port 0FFD4h ??I/O Non-standard
 		mov	dx,0FFD6h		;PCRBASE+DMA1+DMADP1
 		mov	ax,0Fh
 		out	dx,ax			; port 0FFD6h ??I/O Non-standard
 		xor	ax,ax			; Zero register
 		mov	dx,0FFD2h		;PCRBASE+DMA1+DMASP1
 		out	dx,ax			; port 0FFD2h ??I/O Non-standard
 		mov	dx,0FFD0h		;PCRBASE+DMA1+DMASP
 		mov	ax,0A0h
 		out	dx,ax			; port 0FFD0h ??I/O Non-standard
 		mov	si,8346h
;a.096a
loc_111:					;  xref A.0927, 094A
 		mov	ds:gen_io_ptr,si	; (0040:0067=0)
 		pop	dx
 		mov	ah,dh
 		sub	al,al
 		shr	ax,1			; Shift w/zeros fill
 		push	ax
 		mov	bx,6
 		call	GetpDPB			; (0834)
 		mov	cl,ah
 		pop	ax
 		shl	ax,cl			; Shift w/zeros fill
 		mov	dx,0FFD8h		;PCRBASE+DMA1+DMATC
 		out	dx,ax			; port 0FFD8h ??I/O Non-standard
 		clc				; Clear carry flag
 		pop	si
 		pop	dx
 		pop	cx
 		pop	bx
 		pop	ax
 		retn
sub_18		endp

;a.098c
; used in setting up DMA transactions
loc_112:
 			                        ;* No entry point to code
 		call	sub_21			; (09BF)
 		jc	loc_ret_112		; Jump if carry Set
 		mov	ah,8
 		call	sub_13			; (0808)
 		call	sub_22			; (0A08)
 		jc	loc_ret_112		; Jump if carry Set
 		mov	al,byte ptr ds:[nec_stat]	; (A.0042=0)
 		and	al,60h			; '`'
 		cmp	al,60h			; '`'
 		je	loc_113			; Jump if equal
 		clc				; Clear carry flag

loc_ret_112:					;  xref A.098F, 0999
 		retn
loc_113:					;  xref A.09A2
 		or	byte ptr ds:[dsk_ret_code],40h	; (A.0041=0B9h) '@'
 		stc				; Set carry flag
 		retn

;===============================================================================
 ;                              SUBROUTINE
 ;
 ;         Called from:   A.0559, 06B8
;===============================================================================
; since boards don't have standard PC-compatible port addresses, not sure
; what this is for.
;a.09ad
sub_19		proc	near
 		push	ax
 		push	dx
 		mov	al,5
 		out	0D6h,al			; port 0D6h
 		pop	dx
 		pop	ax
 		retn
sub_19		endp


;===============================================================================
 ;                              SUBROUTINE
 ;
 ;         Called from:   A.0731
;===============================================================================
; since boards don't have standard PC-compatible port addresses, not sure
; what this is for.
;a.09b6
sub_20		proc	near
 		push	ax
 		push	dx
 		mov	al,4
 		out	0D6h,al			; port 0D6h
 		pop	dx
 		pop	ax
 		retn
sub_20		endp


;===============================================================================
 ;                              SUBROUTINE
 ;
 ;         Called from:   A.078F, 098C
;===============================================================================
 ; Configure DMA1
 ; since boards don't have standard PC-compatible port addresses, not sure
; what this is for.
;a.09ad09bf
sub_21		proc	near
 		push	ax
 		push	bx
 		push	cx
 		push	dx
 		cli				; Disable interrupts
 		mov	ax,0
 		mov	dx,0FF36h		;PCRBASE+ICR+D1CR
 		out	dx,ax			; port 0FF36h ??I/O Non-standard
 		sti				; Enable interrupts
 		mov	dx,90h
 		mov	bl,0C0h
 		xor	cx,cx			; Zero register

locloop_114:					;  xref A.09DA, 09DE
 		test	byte ptr ds:[dsk_recal_stat],80h	; (A.003E=0FBh)
 		jnz	loc_115			; Jump if not zero
 		loop	locloop_114		; Loop if cx > 0

 		dec	bl
 		jnz	locloop_114		; Jump if not zero
 		cli				; Disable interrupts
 		call	sub_23			; (0A4C)
 		or	byte ptr ds:[dsk_ret_code],80h	; (A.0041=0B9h)
 		and	byte ptr ds:[dsk_recal_stat],7Fh	; (A.003E=0FBh)
 		mov	ax,8
 		mov	dx,0FF36h		;PCRBASE+ICR+D1CR
 		out	dx,ax			; port 0FF36h ??I/O Non-standard
 		sti				; Enable interrupts
 		stc				; Set carry flag
 		jmp	short loc_116		; (0A02)
loc_115:					;  xref A.09D8
 		cli				; Disable interrupts
 		mov	ax,8
 		mov	dx,0FF36h		;PCRBASE+ICR+D1CR
 		out	dx,ax			; port 0FF36h ??I/O Non-standard
 		clc				; Clear carry flag
loc_116:					;  xref A.09F7
 		sti				; Enable interrupts
 		pop	dx
 		pop	cx
 		pop	bx
 		pop	ax
 		retn
sub_21		endp


;===============================================================================
 ;                              SUBROUTINE
 ;
 ;         Called from:   A.0794, 07DC, 0996
;===============================================================================
; since boards don't have standard PC-compatible port addresses, not sure
; what this is for.
;a.0a08
sub_22		proc	near
 		cld				; Clear direction
 		mov	di,42h			; (A.0042=0)
 		push	cx
 		push	dx
 		push	bx
 		mov	bl,7
loc_117:					;  xref A.0A44
 		xor	cx,cx			; Zero register
 		mov	dx,90h

locloop_118:					;  xref A.0A1B
 		in	al,dx			; port 90h ??I/O Non-standard
 		test	al,80h
 		jnz	loc_120			; Jump if not zero
 		loop	locloop_118		; Loop if cx > 0

loc_119:					;  xref A.0A2C
 		stc				; Set carry flag
 		pop	bx
 		pop	dx
 		pop	cx
 		retn
loc_120:					;  xref A.0A19
 		in	al,dx			; port 0FFDAh ??I/O Non-standard
 		test	al,40h			; '@'
 		jnz	loc_122			; Jump if not zero
loc_121:					;  xref A.0A46
 		or	byte ptr ds:[dsk_ret_code],20h	; (A.0041=0B9h) ' '
 		jmp	short loc_119		; (0A1D)
loc_122:					;  xref A.0A25
 		mov	dx,92h
 		in	al,dx			; port 92h ??I/O Non-standard
 		mov	[di],al
 		inc	di
 		mov	cx,28h

;a.0a38
locloop_123:					;  xref A.0A38
 		loop	locloop_123		; Loop if cx > 0

 		mov	dx,90h
 		in	al,dx			; port 90h ??I/O Non-standard
 		test	al,10h
 		jz	loc_124			; Jump if zero
 		dec	bl
 		jnz	loc_117			; Jump if not zero
 		jmp	short loc_121		; (0A27)
loc_124:					;  xref A.0A40
 		pop	bx
 		pop	dx
 		pop	cx
 		retn
sub_22		endp


;===============================================================================
 ;                              SUBROUTINE
 ;
 ;         Called from:   A.068F, 07D9, 07EE, 08E0, 09E1
;===============================================================================
; since boards don't have standard PC-compatible port addresses, not sure
; what this is for.
;a.0a4c
sub_23		proc	near
 		push	ax
 		mov	al,0Dh
 		out	0D6h,al			; port 0D6h
 		push	ax
 		pop	ax
 		mov	al,0Ch
 		out	0D6h,al			; port 0D6h
 		pop	ax
 		retn
sub_23		endp


;===============================================================================
 ;                              SUBROUTINE
 ;
 ;         Called from:   A.0734
;===============================================================================
;a.0a59
sub_24		proc	near
 		push	ax
 		push	bx
 		push	cx
 		push	dx
 		mov	bl,4
 		xor	cx,cx			; Zero register

locloop_125:					;  xref A.0A73, 0A77
 		mov	ah,4
 		call	sub_13			; (0808)
 		mov	ah,[bp]
 		call	sub_13			; (0808)
 		call	sub_25			; (0A87)
 		test	al,20h			; ' '
 		jnz	loc_126			; Jump if not zero
 		loop	locloop_125		; Loop if cx > 0

 		dec	bl
 		jnz	locloop_125		; Jump if not zero
 		or	byte ptr ds:[dsk_ret_code],80h	; (A.0041=0B9h)
 		stc				; Set carry flag
 		jmp	short loc_127		; (0A82)
loc_126:					;  xref A.0A71
 		clc				; Clear carry flag
loc_127:					;  xref A.0A7F
 		pop	dx
 		pop	cx
 		pop	bx
 		pop	ax
 		retn
sub_24		endp


;===============================================================================
 ;                              SUBROUTINE
 ;
 ;         Called from:   A.08A5, 08B0, 08B5, 08BC, 0A6C, 0AA4, 0AAB
;===============================================================================
;a.0a87
sub_25		proc	near
 		push	dx
 		mov	dx,90h
loc_128:					;  xref A.0A8E
 		in	al,dx			; port 90h ??I/O Non-standard
 		test	al,80h
 		jz	loc_128			; Jump if zero
 		test	al,40h			; '@'
 		jz	loc_129			; Jump if zero
 		mov	dx,92h
 		in	al,dx			; port 92h ??I/O Non-standard
 		pop	dx
 		clc				; Clear carry flag
 		retn
loc_129:					;  xref A.0A92
 		pop	dx
 		stc				; Set carry flag
 		retn
sub_25		endp


;===============================================================================
 ;                              SUBROUTINE
 ;
 ;         Called from:   A.0692, 06B5, 0728, 0741, 07DF, 0867, 087E
;===============================================================================
;a.0a9e
sub_26		proc	near
 		push	ax
loc_130:					;  xref A.0AAE
 		mov	ah,8
 		call	sub_13			; (0808)
 		call	sub_25			; (0A87)
 		cmp	al,80h
 		je	loc_131			; Jump if equal
 		call	sub_25			; (0A87)
 		jmp	short loc_130		; (0A9F)
loc_131:					;  xref A.0AA9
 		pop	ax
 		retn
sub_26		endp


;===============================================================================
 ;                              SUBROUTINE
 ;
 ;         Called from:   A.07D5, 07E3
;===============================================================================
;a.0ab2
sub_27		proc	near
 		mov	al,byte ptr ds:[nec_stat+3]	; (A.0045=0AFh) part of NEC status bytes
 		cmp	al,ch
 		mov	al,byte ptr ds:[nec_stat+5]	; (A.0047=6)
 		jz	loc_132			; Jump if zero
 		mov	bx,8
 		call	GetpDPB			; (0834)
 		mov	al,ah
 		inc	al
loc_132:					;  xref A.0ABA
 		sub	al,cl
 		retn
sub_27		endp

; Diskette parameter table
;a.0ac9
INT_1E:
	db      11011111b	; specify byte 1: step rate (ms), head unload time (ms)
				; 7:4 step 0E = 4ms
				; 3:0 HUT  0F = 240ms
	db      2		; specify byte 2: head load time, non-DMA mode
				; 7:1 HLT 01=4ms
				; 0: non-DMA mode (always 0)
	db      80h		; motor turn-off delay (ticks)
	db      2		; bytes per sector (2=512)
	db      8		; sectors per track
	db      2Ah		; gap length (2A=5.25"; 1B=3.5")
	db      0FFh		; data length (ignored if BPS !=0)
	db      50h		; gap length (50=5.25"; 6C=3.5")
	db      0F6h		; format fill byte
	db      19h		; head settle time (ms)
	db      4		; motor start time (in 1/8 seconds)


;===============================================================================
 ;                              SUBROUTINE
 ;
 ;         Called from:   A.00A7
;===============================================================================
; grab keyboard vectors
;a.0ad4
sub_28		proc	near
 		push	ds
 		pushf				; Push flags
 		cli				; Disable interrupts
 		xor	ax,ax			; Zero register
 		mov	ds,ax
 		mov	ax,offset INT16HANDLER	;0B27h
 		mov	ds:Int16v,ax		; (0000:0058=0CFC0h)
 		mov	ds:Int16v+2,cs		; (0000:005A=0F000h)
 		mov	ax,offset INT0DHANDLER	;0CE4h
 		mov	ds:Int0Dv,ax		; (0000:0034=3ADBh)
 		mov	ds:Int0Dv+2,cs		; (0000:0036=17B0h)
 		mov	ax,offset INT09HANDLER	;0CF2h
 		mov	ds:Int09v,ax		; (0000:0024=0E987h)
 		mov	ds:Int09v+2,cs		; (0000:0026=0F000h)
 		mov	ax,40h
 		mov	ds,ax
 		mov	ax,1Eh
 		mov	ds:keybd_q_head,ax	; (0040:001A=30h)
 		mov	ds:keybd_q_tail,ax	; (0040:001C=30h)
 		xor	ax,ax			; Zero register
 		mov	ds:keybd_flags_1,al	; (0040:0017=0)
 		mov	ds:keybd_flags_2,al	; (0040:0018=0)
 		mov	ds:keybd_alt_num,al	; (0040:0019=0)
 		mov	dx,0FF3Ah		;PCRBASE+ICR+INT1CR
 		mov	ax,1
 		out	dx,ax			; port 0FF3Ah ??I/O Non-standard
 		mov	al,98h
 		out	63h,al			; port 63h, 8255 mode reg
 		mov	al,0C0h
 		out	61h,al			; port 61h, 8255 B - spkr, etc
 		call	sub_29			; (0B6E)
 		popf				; Pop flags
 		pop	ds
 		retn
sub_28		endp

;a.0b27
INT16HANDLER:
 		sti				; Enable interrupts
 		push	ds
 		push	bx
 		mov	bx,40h
 		mov	ds,bx
 		or	ah,ah			; Zero ?
 		jz	loc_134			; Jump if zero
 		dec	ah
 		jz	loc_135			; Jump if zero
 		dec	ah
 		jz	loc_136			; Jump if zero
 		pop	bx
 		pop	ds
 		iret				; Interrupt return
loc_134:					;  xref A.0B31, 0B49
 		sti				; Enable interrupts
 		nop
 		cli				; Disable interrupts
 		mov	bx,word ptr ds:[keybd_q_head]	; (A.001A=3538h)
 		cmp	bx,word ptr ds:[keybd_q_tail]	; (A.001C=0D0Ah)
 		je	loc_134			; Jump if equal
 		mov	ax,[bx]
 		call	sub_30			; (0BD3)
 		mov	word ptr ds:[keybd_q_head],bx	; (A.001A=3538h)
 		pop	bx
 		pop	ds
 		iret				; Interrupt return
loc_135:					;  xref A.0B35
 		cli				; Disable interrupts
 		mov	bx,word ptr ds:[keybd_q_head]	; (A.001A=3538h)
 		cmp	bx,word ptr ds:[keybd_q_tail]	; (A.001C=0D0Ah)
 		mov	ax,[bx]
 		sti				; Enable interrupts
 		pop	bx
 		pop	ds
 		retf	2			; Return far
loc_136:					;  xref A.0B39
 		mov	al,byte ptr ds:[keybd_flags_1]	; (A.0017=32h)
 		pop	bx
 		pop	ds
 		iret				; Interrupt return

;===============================================================================
 ;                              SUBROUTINE
 ;
 ;         Called from:   A.0B21
;===============================================================================
;a.0b6e
sub_29		proc	near
 		cli				; Disable interrupts
 		in	al,61h			; port 61h, 8255 port B, read
 		and	al,3Fh			; '?'
 		out	61h,al			; port 61h, 8255 B - spkr, etc
 						;  al = 0, speaker off
 		mov	cx,0A558h

locloop_137:					;  xref A.0B78
 		loop	locloop_137		; Loop if cx > 0

 		in	al,61h			; port 61h, 8255 port B, read
 		or	al,0C0h
 		out	61h,al			; port 61h, 8255 B - spkr, etc
 		and	al,3Fh			; '?'
 		or	al,40h			; '@'
 		out	61h,al			; port 61h, 8255 B - spkr, etc
 		xor	cx,cx			; Zero register
 		cli				; Disable interrupts

locloop_138:					;  xref A.0B8D
 		in	al,62h			; port 62h, 8255 C - sw2, etc.
 		test	al,10h
 		loopz	locloop_138		; Loop if zf=1, cx>0

 		jcxz	loc_139			; Jump if cx=0
 		in	al,60h			; port 60h, keybd scan or sw1
 		push	ax
 		in	al,61h			; port 61h, 8255 port B, read
 		mov	ah,al
 		or	al,80h
 		out	61h,al			; port 61h, 8255 B - spkr, etc
 		mov	al,ah
 		out	61h,al			; port 61h, 8255 B - spkr, etc
 		pop	ax
 		cmp	al,0AAh
 		jne	loc_139			; Jump if not equal
 		retn
loc_139:					;  xref A.0B8F, 0BA3
 		mov	si,offset msg5		; (A.0BBA='Keyboard reset f')
 		call	prtzstr			; (05E5)
 		in	al,61h			; port 61h, 8255 port B, read
 		mov	ah,al
 		or	al,80h
 		out	61h,al			; port 61h, 8255 B - spkr, etc
 		mov	al,ah
 		out	61h,al			; port 61h, 8255 B - spkr, etc
 		stc				; Set carry flag
 		retn
sub_29		endp

msg5:		db	'Keyboard reset failure', 0Ah, 0Dh,0


;===============================================================================
 ;                              SUBROUTINE
 ;
 ;         Called from:   A.0B4D, 0F6A
;===============================================================================
;a.0bd3
sub_30		proc	near
 		add	bx,2
 		cmp	bx,word ptr 3Eh		; 81 fb 3e 00
 		jne	loc_ret_140		; Jump if not equal
 		mov	bx,1Eh

loc_ret_140:					;  xref A.0BDA
 		retn
sub_30		endp


;a.0be0 - could be scan codes for modifier keys. Note lack of DEL key
; modifier.
; xref A.0D20
;K6
data_84:	;db	52h, 3Ah, 45h, 46h
		db	INS_KEY, CAPS_KEY, NUM_KEY, SCROLL_KEY
;		db	38h, 1Dh, 2Ah, 36h
		db	ALT_KEY, CTL_KEY, LEFT_KEY, RIGHT_KEY

; Shift mask table
;a.0be9
;K7
data_85:	;db	80h, 40h, 20h, 10h		;  xref A.0D33
		db	INS_SHIFT, CAPS_SHIFT, NUM_SHIFT, SCROLL_SHIFT
;     		db	08h, 04h, 02h, 01h	
		db	ALT_SHIFT ,CTL_SHIFT, LEFT_SHIFT, RIGHT_SHIFT
	
; Scan Code Tables
;a.0bf0
;K8
		db	1Bh,0FFh, 00h,0FFh,0FFh
     		db	0FFh, 1Eh,0FFh,0FFh,0FFh,0FFh
     		db	1Fh,0FFh, 7Fh,0FFh, 11h, 17h
     		db	05h, 12h, 14h, 19h, 15h, 09h
     		db	0Fh, 10h, 1Bh, 1Dh, 0Ah,0FFh
     		db	01h, 13h, 04h, 06h, 07h, 08h
     		db	0Ah, 0Bh, 0Ch,0FFh,0FFh,0FFh
     		db	0FFh, 1Ch, 1Ah, 18h, 03h, 16h
     		db	02h, 0Eh, 0Dh,0FFh,0FFh,0FFh
 		db	0FFh,0FFh,0FFh, 20h,0FFh

; Control Table Scan
;a.0c2a
;K9		
     		db	'^_`abcdefg'
     		db	0FFh,0FFh, 77h,0FFh, 84h,0FFh
     		db	 73h,0FFh, 74h,0FFh, 75h,0FFh
 		db	 76h,0FFh,0FFh

; LC Table
;a.0c43
;K10
data_86:	db	1Bh, '1234567890-=', 8, 9, 'qwert'	;  xref A.0F2D
     		db	'yuiop[]', 0Dh, 0FFh
     		db	'asdfghjkl',3bh,27h,60h, 0FFh
     		db	'\zxcvbnm,./'
 		db	0FFh, 2Ah,0FFh, 20h,0FFh

; UC Table
;a.0c7d
;K11
 		db	1Bh, '!@#$'
     		db	'%^&*()_+', 8, 0
     		db	'QWERTYUIOP{}', 0Dh, 0FFh
     		db	'ASDFGHJKL:"~', 0FFh
     		db	'|ZXCVBNM<>?'
     		db	0FFh, 00h,0FFh, 20h,0FFh

; UC Table Scan
;a.0cb7
;K12
;		db	54h, 55h, 'VWXYZ[\]'
		db	84,85,86,87,88,89,90
		db	91,92,93

; Alt Table Scan
;K13
;a.0cc1
;		db	'hiklmnopq'
		db	104,105,106,107,108
		db	109,110,111,112,113

; Num State Table
;a.0cca
;K14
		db	'789-456+1230.'

;a.0cd7
;K15
;		db	'GHI', 0FFh, 4Bh,0FFh, 4Dh,0FFh, 4Fh
;		db	50h, 51h, 52h, 53h 
		db	71,72,73,-1,75,-1,77
		db	-1,79,80,81,82,83
 
;a.0ce4
INT0DHANDLER:
; 	db	 50h, 52h
;    	db	0B8h, 00h, 80h,0BAh, 22h,0FFh
;     	db	0EFh, 5Ah, 58h,0CDh, 09h,0CFh
 		push	ax
 		push	dx
 		mov	ax,8000h		; do EOI
 		mov	dx,0FF22h		;PCRBASE+ICR+EOIREG
 		out	dx,ax
 		pop	dx
 		pop	ax
 		int	09
 		iret

;a.0cf2
INT09HANDLER:
;     	db	 50h, 53h, 51h, 52h, 56h, 57h
;     	db	 1Eh, 06h,0FCh,0B8h, 40h, 00h
;     	db	 8Eh,0D8h,0E4h, 60h,0A2h, 7Bh
;     	db	 00h, 50h,0E4h, 61h, 8Ah,0E0h
;     	db	 0Ch, 80h,0E6h, 61h, 86h,0E0h
;     	db	0E6h, 61h, 58h, 8Ah,0E0h, 3Ch
;     	db	0FFh, 75h, 03h,0E9h, 60h, 02h
	;	sti
 		push	ax
 		push	bx
 		push	cx
 		push	dx
 		push	si
 		push	di
 		push	ds
 		push	es
 		cld
 		mov	ax,40h
 		mov	ds,ax
 		in	al,60h 
 		mov	ds:[lptto+3],al		;7b
 		push	ax
 		in	al,61h 
 		mov	ah,al
 		or	al,80h 
 		out	61h,al
 		xchg	ah,al
 		out	61h,al
 		pop	ax
 		mov	ah,al
 		cmp	al,0FFh
 		jnz	loc_141
 		jmp	loc_186			;0F7C
;a.0d1c
loc_141:
 		and	al,7Fh
 		push	cs
 		pop	es
 		mov	di,offset data_84	; (A.0BE0=52h)
 		mov	cx,8
 		repne	scasb			; Rep zf=0+cx >0 Scan es:[di] for al
 		mov	al,ah
 		jz	loc_142			; Jump if zero
 		jmp	loc_151			; (0DB7)
loc_142:					;  xref A.0D2A
 		sub	di,0BE1h
 		mov	ah,byte ptr cs:data_85[di]	; (A.0BE8=80h)
 		test	al,80h
 		jnz	loc_149			; Jump if not zero
 		cmp	ah,10h
 		jae	loc_144			; Jump if above or =
 		or	byte ptr ds:[keybd_flags_1],ah	; (A.0017=32h)
 		jmp	loc_152			; (0DCB)
loc_144:					;  xref A.0D3F
 		test	byte ptr ds:[keybd_flags_1],4	; (A.0017=32h)
 		jnz	loc_151			; Jump if not zero
 		cmp	al,52h			; 'R'
 		jne	loc_148			; Jump if not equal
 		test	byte ptr ds:[keybd_flags_1],8	; (A.0017=32h)
 		jz	loc_145			; Jump if zero
 		jmp	short loc_151		; (0DB7)
 		db	90h
;a.0d5d
loc_145:					;  xref A.0D58
 		test	byte ptr ds:[keybd_flags_1],20h	; (A.0017=32h) ' '
 		jnz	loc_147			; Jump if not zero
 		test	byte ptr ds:[keybd_flags_1],3	; (A.0017=32h)
 		jz	loc_148			; Jump if zero
loc_146:					;  xref A.0D76
 		mov	ax,5230h
 		jmp	loc_181			; (0F34)
loc_147:					;  xref A.0D62
 		test	byte ptr ds:[keybd_flags_1],3	; (A.0017=32h)
 		jz	loc_146			; Jump if zero
loc_148:					;  xref A.0D51, 0D69
 		test	ah,byte ptr ds:[keybd_flags_2]	; (A.0018=31h)
 		jnz	loc_152			; Jump if not zero
 		or	byte ptr ds:[keybd_flags_2],ah	; (A.0018=31h)
 		xor	byte ptr ds:[keybd_flags_1],ah	; (A.0017=32h)
 		cmp	al,52h			; 'R'
 		jne	loc_152			; Jump if not equal
 		mov	ax,5200h
 		jmp	loc_181			; (0F34)
loc_149:					;  xref A.0D3A
 		cmp	ah,10h
 		jae	loc_150			; Jump if above or =
 		not	ah
 		and	byte ptr ds:[keybd_flags_1],ah	; (A.0017=32h)
 		cmp	al,0B8h
 		jne	loc_152			; Jump if not equal
 		mov	al,byte ptr ds:[19h]	; (A.0019=2Fh)
 		mov	ah,0
 		mov	byte ptr ds:[19h],ah	; (A.0019=2Fh)
 		cmp	al,0
 		je	loc_152			; Jump if equal
 		jmp	loc_182			; (0F3D)
;a.0daf
loc_150:					;  xref A.0D93
 		not	ah
 		and	byte ptr ds:[keybd_flags_2],ah	; (A.0018=31h)
 		jmp	short loc_152		; (0DCB)
loc_151:					;  xref A.0D2C, 0D4D, 0D5A
 		cmp	al,80h
 		jae	loc_152			; Jump if above or =
 		test	byte ptr ds:[keybd_flags_2],8	; (A.0018=31h)
 		jz	loc_153			; Jump if zero
 		cmp	al,45h			; 'E'
 		je	loc_152			; Jump if equal
 		and	byte ptr ds:[keybd_flags_2],0F7h	; (A.0018=31h)
loc_152:					;  xref A.0D45, 0D7C, 0D88, 0D9D
 						;            0DAA, 0DB5, 0DB9, 0DC4
 						;            0E39, 0E60, 0EA8, 0EDE
 						;            0F57, 0F79, 0F7F
 		pop	es
 		pop	ds
 		pop	di
 		pop	si
 		pop	dx
 		pop	cx
 		pop	bx
 		pop	ax
 		iret				; Interrupt return

; Ctrl-Alt-Del restart?
;a.0dd4
loc_153:					;  xref A.0DC0
 		test	byte ptr ds:[keybd_flags_1],8	; (A.0017=32h)
 		jnz	loc_154			; Jump if not zero
 		jmp	loc_162			; (0E6D)
loc_154:					;  xref A.0DD9
 		test	byte ptr ds:[keybd_flags_1],4	; (A.0017=32h)
 		jz	loc_155			; Jump if zero
 		cmp	al,53h			; 'S'
 		jne	loc_155			; Jump if not equal
 		mov	word ptr ds:[72h],1234h	; (A.0072=0FEB9h)
		jmp	COLD2			;*(001F) go to cold restart
; 		db	0E9h, 2Dh,0F2h

;a.0df2
data_88:	db	'ROPQKLMGHI'		;  xref A.0E1F
     		db	 10h, 11h, 12h, 13h, 14h, 15h
     		db	 16h, 17h, 18h, 19h, 1Eh, 1Fh
 		db	' !"#$'
     		db	'%&,-./012'
;a.0e16
loc_155:					;  xref A.0DE3, 0DE7
 		cmp	al,39h			; '9'
 		jne	loc_156			; Jump if not equal
 		mov	al,20h			; ' '
 		jmp	loc_181			; (0F34)
loc_156:					;  xref A.0E18
 		mov	di,offset data_88	; (A.0DF2='ROPQKLMGHI')
 		mov	cx,0Ah
 		repne	scasb			; Rep zf=0+cx >0 Scan es:[di] for al
 		jnz	loc_157			; Jump if not zero
 		sub	di,0DF3h
 		mov	al,byte ptr ds:[19h]	; (A.0019=2Fh)
 		mov	ah,0Ah
 		mul	ah			; ax = reg * al
 		add	ax,di
 		mov	byte ptr ds:[19h],al	; (A.0019=2Fh)
 		jmp	short loc_152		; (0DCB)
loc_157:					;  xref A.0E27
 		mov	byte ptr ds:[19h],0	; (A.0019=2Fh)
 		mov	cx,1Ah
 		repne	scasb			; Rep zf=0+cx >0 Scan es:[di] for al
 		jnz	loc_158			; Jump if not zero
 		mov	al,0
 		jmp	loc_181			; (0F34)
loc_158:					;  xref A.0E45
 		cmp	al,2
 		jb	loc_159			; Jump if below
 		cmp	al,0Eh
 		jae	loc_159			; Jump if above or =
 		add	ah,76h			; 'v'
 		mov	al,0
 		jmp	loc_181			; (0F34)
loc_159:					;  xref A.0E4E, 0E52
 		cmp	al,3Bh			; ';'
 		jae	loc_161			; Jump if above or =
;a.0e60
loc_160:					;  xref A.0E65
 		jmp	loc_152			; (0DCB)
loc_161:					;  xref A.0E5E
 		cmp	al,47h			; 'G'
 		jae	loc_160			; Jump if above or =
 		mov	bx,0CC1h
 		jmp	loc_187			; (0F82)
loc_162:					;  xref A.0DDB
 		test	byte ptr ds:[keybd_flags_1],4	; (A.0017=32h)
 		jz	loc_168			; Jump if zero
 		cmp	al,46h			; 'F'
 		jne	loc_163			; Jump if not equal
 		mov	bx,1Eh
 		mov	word ptr ds:[keybd_q_head],bx	; (A.001A=3538h)
 		mov	word ptr ds:[keybd_q_tail],bx	; (A.001C=0D0Ah)
 		mov	byte ptr ds:[71h],80h	; (A.0071=0)
 		int	1Bh			; Keyboard break (cntrl-break)
 		mov	ax,0
 		jmp	loc_181			; (0F34)
loc_163:					;  xref A.0E76
 		cmp	al,45h			; 'E'
 		jne	loc_165			; Jump if not equal
 		or	byte ptr ds:[keybd_flags_2],8	; (A.0018=31h)
 		mov	dx,3D8h
 		mov	al,byte ptr ds:[65h]	; (A.0065=0A3h)
 		out	dx,al			; port 3D8h, CGA video control
 		sti				; Enable interrupts
loc_164:					;  xref A.0EA6
 		test	byte ptr ds:[keybd_flags_2],8	; (A.0018=31h)
 		jnz	loc_164			; Jump if not zero
 		jmp	loc_152			; (0DCB)
;a.0eab
loc_165:					;  xref A.0E92
 		cmp	al,37h			; '7'
 		jne	loc_166			; Jump if not equal
 		mov	ax,7200h
 		jmp	loc_181			; (0F34)
loc_166:					;  xref A.0EAD
 		mov	bx,0BF0h
 		cmp	al,3Bh			; ';'
 		jae	loc_167			; Jump if above or =
 		jmp	short loc_180		; (0F30)
 		db	90h
loc_167:					;  xref A.0EBA
 		mov	bx,0C2Ah
 		jmp	loc_187			; (0F82)
loc_168:					;  xref A.0E72
 		cmp	al,47h			; 'G'
 		jae	loc_172			; Jump if above or =
 		test	byte ptr ds:[keybd_flags_1],3	; (A.0017=32h)
 		jz	loc_178			; Jump if zero
 		cmp	al,0Fh
 		jne	loc_169			; Jump if not equal
 		mov	ax,0F00h
 		jmp	short loc_181		; (0F34)
 		db	90h
loc_169:					;  xref A.0ED2
 		cmp	al,37h			; '7'
 		jne	loc_170			; Jump if not equal
 		jmp	loc_152			; (0DCB)
;a.0ee1
loc_170:					;  xref A.0EDC
 		cmp	al,3Bh			; ';'
 		jb	loc_171			; Jump if below
 		mov	bx,0CB7h
 		jmp	loc_187			; (0F82)
loc_171:					;  xref A.0EE3
 		mov	bx,0C7Dh
 		jmp	short loc_180		; (0F30)
loc_172:					;  xref A.0EC7
 		test	byte ptr ds:[keybd_flags_1],20h	; (A.0017=32h) ' '
 		jnz	loc_176			; Jump if not zero
 		test	byte ptr ds:[keybd_flags_1],3	; (A.0017=32h)
 		jnz	loc_177			; Jump if not zero
loc_173:					;  xref A.0F1C
 		cmp	al,4Ah			; 'J'
 		je	loc_174			; Jump if equal
 		cmp	al,4Eh			; 'N'
 		je	loc_175			; Jump if equal
 		sub	al,47h			; 'G'
 		mov	bx,0CD7h
 		jmp	short loc_188		; (0F84)
loc_174:					;  xref A.0F00
 		mov	ax,4A2Dh
 		jmp	short loc_181		; (0F34)
;a.0f12
loc_175:					;  xref A.0F04
 		mov	ax,4E2Bh
 		jmp	short loc_181		; (0F34)
loc_176:					;  xref A.0EF5
 		test	byte ptr ds:[keybd_flags_1],3	; (A.0017=32h)
 		jnz	loc_173			; Jump if not zero
loc_177:					;  xref A.0EFC
 		sub	al,46h			; 'F'
 		mov	bx,0CCAh
 		jmp	short loc_180		; (0F30)
loc_178:					;  xref A.0ECE
 		cmp	al,3Bh			; ';'
 		jb	loc_179			; Jump if below
 		mov	al,0
 		jmp	short loc_181		; (0F34)
loc_179:					;  xref A.0F27
 		mov	bx,offset data_86	; (A.0C43=' 1234567890-=  q')
;a.0f30
loc_180:					;  xref A.0EBC, 0EEE, 0F23
 		dec	al
 		xlat	cs:[bx]			; al=[al+[bx]] table
loc_181:					;  xref A.0D6E, 0D8D, 0E1C, 0E49
 						;            0E59, 0E8D, 0EB2, 0ED7
 						;            0F10, 0F15, 0F2B, 0F8A
 		cmp	al,0FFh
 		je	loc_183			; Jump if equal
 		cmp	ah,0FFh
 		je	loc_183			; Jump if equal
loc_182:					;  xref A.0DAC
 		test	byte ptr ds:[keybd_flags_1],40h	; (A.0017=32h) '@'
 		jz	loc_185			; Jump if zero
 		test	byte ptr ds:[keybd_flags_1],3	; (A.0017=32h)
 		jz	loc_184			; Jump if zero
 		cmp	al,41h			; 'A'
 		jb	loc_185			; Jump if below
 		cmp	al,5Ah			; 'Z'
 		ja	loc_185			; Jump if above
 		add	al,20h			; ' '
 		jmp	short loc_185		; (0F64)
loc_183:					;  xref A.0F36, 0F3B
 		jmp	loc_152			; (0DCB)
loc_184:					;  xref A.0F49
 		cmp	al,61h			; 'a'
 		jb	loc_185			; Jump if below
 		cmp	al,7Ah			; 'z'
 		ja	loc_185			; Jump if above
 		sub	al,20h			; ' '
;a.0f64
loc_185:					;  xref A.0F42, 0F4D, 0F51, 0F55
 						;            0F5C, 0F60
 		mov	bx,word ptr ds:[keybd_q_tail]	; (A.001C=0D0Ah)
 		mov	si,bx
 		call	sub_30			; (0BD3)
 		cmp	bx,word ptr ds:[keybd_q_head]	; (A.001A=3538h)
 		je	loc_186			; Jump if equal
 		mov	[si],ax
 		mov	word ptr ds:[keybd_q_tail],bx	; (A.001C=0D0Ah)
 		jmp	loc_152			; (0DCB)
loc_186:					;  xref A.0F71
 		call	sub_31			; (0F8C)
 		jmp	loc_152			; (0DCB)
loc_187:					;  xref A.0E6A, 0EC2, 0EE8
 		sub	al,3Bh			; ';'
loc_188:					;  xref A.0F0B
 		xlat	cs:[bx]			; al=[al+[bx]] table
 		mov	ah,al
 		mov	al,0
 		jmp	short loc_181		; (0F34)

;===============================================================================
 ;                              SUBROUTINE
 ;
 ;         Called from:   A.0F7C
;===============================================================================
;a.0f8c
sub_31		proc	near
 		push	ax
 		push	bx
 		push	cx
 		mov	bx,0C0h
 		in	al,61h			; port 61h, 8255 port B, read
 		push	ax
loc_189:					;  xref A.0FA8
 		and	al,0FCh
 		out	61h,al			; port 61h, 8255 B - spkr, etc
 						;  al = 0, speaker off
 		mov	cx,48h

locloop_190:					;  xref A.0F9C
 		loop	locloop_190		; Loop if cx > 0

 		or	al,2
 		out	61h,al			; port 61h, 8255 B - spkr, etc
 		mov	cx,48h

locloop_191:					;  xref A.0FA5
 		loop	locloop_191		; Loop if cx > 0

 		dec	bx
 		jnz	loc_189			; Jump if not zero
 		pop	ax
 		out	61h,al			; port 61h, 8255 B - spkr, etc
 						;  al = 0, speaker off
 		pop	cx
 		pop	bx
 		pop	ax
 		retn
sub_31		endp


;===============================================================================
 ;                              SUBROUTINE
 ;
 ;         Called from:   A.008A
;===============================================================================
; Grab INT10/1D video
;a.0fb1
sub_32		proc	near
 		push	ds
 		xor	ax,ax				; Zero register
 		mov	ds,ax
 		mov	ax,offset INT10HANDLER		;0FF1h
 		mov	ds:Int10v,ax			; (0000:0040=0EEh)
 		mov	ds:Int10v+2,cs			; (0000:0042=0C000h)
 		mov	ax,offset INT_1D		;1020h
 		mov	ds:Int1Dv,ax			; (0000:0074=0C958h)
 		mov	word ptr ds:Int1Dv+2,cs		; (0000:0076=0F000h)
 		pop	ds
 		mov	ax,3
 		int	10h				; Video display   ah=functn 00h
 							;  set display mode in al
 		retn
sub_32		endp

; INT10 function table
;a.0fd1
INT10FN:	dw	offset loc_193		;  xref A.101B
		dw	offset loc_202		;  xref A.101B
		dw	offset loc_203		;  xref A.101B
		dw	offset loc_205		;  xref A.101B
		dw	offset loc_292		;  xref A.101B
		dw	offset loc_206		;  xref A.101B
		dw	offset loc_211		;  xref A.101B
		dw	offset loc_219		;  xref A.101B
		dw	offset loc_225		;  xref A.101B
		dw	offset loc_231		;  xref A.101B
		dw	offset loc_234		;  xref A.101B
		dw	offset loc_207		;  xref A.101B
		dw	offset loc_238		;  xref A.101B
		dw	offset loc_237		;  xref A.101B
		dw	offset loc_280		;  xref A.101B
		dw	offset loc_210		;  xref A.101B

;INT 10 Interrupt Handler
;a.0ff1
INT10HANDLER:
;     	db	0FBh,0FCh, 06h, 1Eh, 52h, 51h
;     	db	 53h, 56h, 57h, 50h, 8Ah,0C4h
;     	db	 32h,0E4h,0D1h,0E0h, 8Bh,0F0h
;     	db	 3Dh, 20h, 00h, 72h, 04h, 58h
; 	db	0E9h, 2Ah, 01h
		sti
		cld
		push	es
		push	ds
		push	dx
		push	cx
		push	bx
		push	si
		push	di
		push	ax
		mov	al,ah
		xor	ah,ah
		shl	ax,1
		mov	si,ax
		cmp	ax,20h			; max functions?
		jb	loc_192			;100C
		pop	ax
		jmp	loc_200			;1136
loc_192:
 		mov	ax,40h
 		mov	ds,ax
 		mov	ax,0B800h
 		mov	es,ax
 		pop	ax
 		mov	ah,ds:video_mode	; (0040:0049=3)
 		jmp	word ptr cs:INT10FN[si]	;*(A.0FD1=1078h)     16 entries

;a.1020
; Video Parameter Table
;00h 16 BYTEs   6845 register values for modes 00h and 01h
;10h 16 BYTEs   6845 register values for modes 02h and 03h
;20h 16 BYTEs   6845 register values for modes 04h and 05h
;30h 16 BYTEs   6845 register values for modes 06h and 07h
;40h    WORD    bytes in video buffer for modes 00h and 01h (0800h)
;42h    WORD    bytes in video buffer for modes 02h and 03h (1000h)
;44h    WORD    bytes in video buffer for modes 04h and 05h (4000h)
;46h    WORD    bytes in video buffer for mode 06h (4000h)
;48h  8 BYTEs   columns on screen for each of modes 00h through 07h
;50h  8 BYTEs   CRT controller mode bytes for each of modes 00h through 07h
INT_1D:
		db	 38h, 28h, 2Dh, 0Ah, 1Fh, 06h	; Init string for 40 x 25
		db	 19h, 1Ch, 02h, 07h, 06h, 07h
		db	 00h, 00h, 00h, 00h

		db	 71h, 50h      			; Init string for 80 x 25 col
		db	 5Ah, 0Ah, 1Fh, 06h, 19h, 1Ch
		db	 02h, 07h, 06h, 07h, 00h, 00h
		db	 00h, 00h

		db	 38h, 28h, 2Dh, 0Ah		; Init string for GRAPHIX
		db	 7Fh, 06h, 64h, 70h, 02h, 01h
		db	 06h, 07h, 00h, 00h, 00h, 00h

		db	 61h, 50h, 52h, 0Fh, 19h, 06h	; Init string for 80 x 25 b/w
		db	 19h, 19h, 02h, 0Dh, 0Bh, 0Ch
		db	 00h, 00h, 00h, 00h

;a.1060	Regen lengths
REGENL:		dw	800h			; xref A.1111 40x25
     		dw	1000h			; 80x25
		dw	4000h			; graphics
		dw	4000h
;a.1068 Column lengths				; Data table (indexed access) xref A.1103
MAXCOLS:	db	28h, 28h, 50h, 50h
		db	28h, 28h, 50h, 50h
;a;1070 table of mode sets			; Data table (indexed access) xref A.10FA
MODES:		db	2Ch, 28h, 2Dh, 29h
		db	2Ah, 2Eh, 1Eh, 29h

;����� Indexed Entry Point ������������������������������������������������
;a.1078
loc_193:					;  xref A.0FD1, 101B
 		mov	dx,3D4h
 		mov	bl,0
 		cmp	al,7
 		jb	loc_194			; Jump if below
 		jmp	loc_200			; (1136)
loc_194:					;  xref A.107F
 		mov	ah,al
 		mov	ds:video_mode,al	; (0040:0049=3)
 		mov	ds:video_port,dx	; (0040:0063=3D4h)
 		push	ds
 		push	ax
 		push	dx
 		add	dx,4
 		mov	al,bl
 		out	dx,al			; port 3D8h, CGA video control
 		pop	dx
 		sub	ax,ax
 		mov	ds,ax
 		lds	bx,dword ptr ds:Int1Dv	; (0000:0074=0C958h) Load seg:offset p
 		pop	ax
 		mov	cx,10h
 		cmp	ah,2
 		jb	loc_195			; Jump if below
 		add	bx,cx
 		cmp	ah,4
 		jb	loc_195			; Jump if below
 		add	bx,cx
 		cmp	ah,7
 		jb	loc_195			; Jump if below
 		add	bx,cx
loc_195:					;  xref A.10A6, 10AD, 10B4
 		push	ax
 		xor	ah,ah			; Zero register

;a.10bb
locloop_196:					;  xref A.10C6
 		mov	al,ah
 		out	dx,al			; port 3D4h, CGA/EGA reg index
 						;  al = 0, horiz char total
 		inc	dx
 		inc	ah
 		mov	al,[bx]
 		out	dx,al			; port 3D5h, CGA/EGA indxd data
 		inc	bx
 		dec	dx
 		loop	locloop_196		; Loop if cx > 0

 		pop	ax
 		pop	ds
 		xor	di,di			; Zero register
 		mov	ds:video_segment,di	; (0040:004E=0)
 		mov	byte ptr ds:video_page,0	; (0040:0062=0)
 		mov	cx,2000h
 		cmp	ah,4
 		jb	loc_197			; Jump if below
 		xor	ax,ax			; Zero register
 		jmp	short loc_198		; (10E4)
loc_197:					;  xref A.10DB
 		mov	ax,720h
;a.10e4
loc_198:					;  xref A.10DF
 		rep	stosw			; Rep when cx >0 Store ax to es:[di]
 		mov	word ptr ds:vid_curs_mode,67h	; (0040:0060=2000h)
 		mov	al,ds:video_mode	; (0040:0049=3)
 		xor	ah,ah			; Zero register
 		mov	si,ax
 		mov	dx,ds:video_port	; (0040:0063=3D4h)
 		add	dx,4
 		mov	al,byte ptr cs:MODES[si]		; (A.1070=2Ch)
 		out	dx,al			; port 3D8h, CGA video control
 		mov	ds:video_mode_reg,al	; (0040:0065=29h)

 		mov	al,byte ptr cs:MAXCOLS[si]	; (A.1068='((PP((PP')
 		xor	ah,ah			; Zero register
 		mov	ds:video_columns,ax	; (0040:004A=50h)
 		and	si,word ptr 0Eh
 		mov	cx,word ptr cs:REGENL[si]	; (A.1060=800h)
 		mov	ds:video_buf_siz,cx	; (0040:004C=1000h)
 		mov	cx,8
 		mov	di,offset vid_curs_pos0	; (0040:0050=4Fh) bf 0050
 		push	ds
 		pop	es
 		xor	ax,ax			; Zero register
 		rep	stosw			; Rep when cx >0 Store ax to es:[di]
 		inc	dx
 		mov	al,30h			; '0'
 		cmp	byte ptr ds:video_mode,6	; (0040:0049=3)
 		jne	loc_199			; Jump if not equal
 		mov	al,3Fh			; '?'
loc_199:					;  xref A.112E
 		out	dx,al			; port 3D9h, CGA color control
 		mov	ds:video_color,al	; (0040:0066=30h)
;a.1136
loc_200:					;  xref A.1081, 1147, 1176, 11C0
 						;            11DC, 1252, 12F3, 1331
 						;            1350, 1361, 1380, 141C
 						;            147C, 14FC, 155C, 15E0
 						;            16A9
 		pop	di
 		pop	si
 		pop	bx
loc_201:					;  xref A.11F7
 		pop	cx
 		pop	dx
 		pop	ds
 		pop	es
 		iret				; Interrupt return

;����� Indexed Entry Point ������������������������������������������������

loc_202:					;  xref A.0FD3, 101B
 		mov	ah,0Ah
 		mov	ds:vid_curs_mode,cx	; (0040:0060=2000h)
 		call	sub_33			; (1149)
 		jmp	short loc_200		; (1136)

;===============================================================================
 ;                              SUBROUTINE
 ;
 ;         Called from:   A.1144, 1185, 11B3
;===============================================================================
;a.1149
sub_33		proc	near
 		mov	dx,ds:video_port	; (0040:0063=3D4h)
 		mov	al,ah
 		out	dx,al			; port 3D4h, CGA/EGA reg index
 						;  al = 0Ah, cursor start, mode
 		inc	dx
 		mov	al,ch
 		out	dx,al			; port 3D5h, CGA/EGA indxd data
 		dec	dx
 		mov	al,ah
 		inc	al
 		out	dx,al			; port 3D4h, CGA/EGA reg index
 						;  al = 0Bh, cursor end
 		inc	dx
 		mov	al,cl
 		out	dx,al			; port 3D5h, CGA/EGA indxd data
 		retn
sub_33		endp


;����� Indexed Entry Point ������������������������������������������������
;a.115f
loc_203:					;  xref A.0FD5, 101B
 		mov	cl,bh
 		xor	ch,ch			; Zero register
 		shl	cx,1			; Shift w/zeros fill
 		mov	si,cx
 		mov	ds:vid_curs_pos0[si],dx	; (0040:0050=184Fh)
 		cmp	ds:video_page,bh	; (0040:0062=0)
 		jne	loc_204			; Jump if not equal
 		mov	ax,dx
 		call	sub_34			; (1178)
loc_204:					;  xref A.116F
 		jmp	short loc_200		; (1136)

;===============================================================================
 ;                              SUBROUTINE
 ;
 ;         Called from:   A.1173, 11BD
;===============================================================================
;a.1178
sub_34		proc	near
 		call	sub_35			; (11FA)
 		mov	cx,ax
 		add	cx,ds:video_segment	; (0040:004E=0)
 		sar	cx,1			; Shift w/sign fill
 		mov	ah,0Eh
 		call	sub_33			; (1149)
 		retn
sub_34		endp


;����� Indexed Entry Point ������������������������������������������������
;a.1189
loc_205:					;  xref A.0FD7, 101B
 		mov	bl,bh
 		xor	bh,bh			; Zero register
 		shl	bx,1			; Shift w/zeros fill
 		mov	dx,ds:vid_curs_pos0[bx]	; (0040:0050=184Fh)
 		mov	cx,ds:vid_curs_mode	; (0040:0060=2000h)
 		pop	di
 		pop	si
 		pop	bx
 		pop	ax
 		pop	ax
 		pop	ds
 		pop	es
 		iret				; Interrupt return

;����� Indexed Entry Point ������������������������������������������������
;a.119f
loc_206:					;  xref A.0FDB, 101B
 		mov	ds:video_page,al	; (0040:0062=0)
 		mov	cx,ds:video_buf_siz	; (0040:004C=1000h)
 		cbw				; Convrt byte to word
 		push	ax
 		mul	cx			; dx:ax = reg * ax
 		mov	ds:video_segment,ax	; (0040:004E=0)
 		mov	cx,ax
 		sar	cx,1			; Shift w/sign fill
 		mov	ah,0Ch
 		call	sub_33			; (1149)
 		pop	bx
 		shl	bx,1			; Shift w/zeros fill
 		mov	ax,ds:vid_curs_pos0[bx]	; (0040:0050=184Fh)
 		call	sub_34			; (1178)
 		jmp	loc_200			; (1136)

;����� Indexed Entry Point ������������������������������������������������
;a.11c3
loc_207:					;  xref A.0FE7, 101B
 		mov	dx,ds:video_port	; (0040:0063=3D4h)
 		add	dx,5
 		mov	al,ds:video_color	; (0040:0066=30h)
 		or	bh,bh			; Zero ?
 		jnz	loc_209			; Jump if not zero
 		and	al,0E0h
 		and	bl,1Fh
 		or	al,bl
loc_208:					;  xref A.11E3, 11E7
 		out	dx,al			; port 3D9h, CGA color control
 		mov	ds:video_color,al	; (0040:0066=30h)
 		jmp	loc_200			; (1136)
loc_209:					;  xref A.11CF
 		and	al,0DFh
 		shr	bl,1			; Shift w/zeros fill
 		jnc	loc_208			; Jump if carry=0
 		or	al,20h			; ' '
 		jmp	short loc_208		; (11D8)

;����� Indexed Entry Point ������������������������������������������������
;a.11e9
loc_210:					;  xref A.0FEF, 101B
 		mov	ah,byte ptr ds:video_columns	; (0040:004A=50h)
 		mov	al,ds:video_mode	; (0040:0049=3)
 		mov	bh,ds:video_page	; (0040:0062=0)
 		pop	di
 		pop	si
 		pop	cx
 		jmp	loc_201			; (1139)

;===============================================================================
 ;                              SUBROUTINE
 ;
 ;         Called from:   A.1178, 1259, 130C
;===============================================================================
;a.11fa
sub_35		proc	near
 		push	bx
 		mov	bx,ax
 		mov	al,ah
 		mul	byte ptr ds:video_columns	; (0040:004A=50h) ax = data * al
 		xor	bh,bh			; Zero register
 		add	ax,bx
 		shl	ax,1			; Shift w/zeros fill
 		pop	bx
 		retn
sub_35		endp


;����� Indexed Entry Point ������������������������������������������������
;a.120b
loc_211:					;  xref A.0FDD, 101B
 		mov	bl,al
 		cmp	ah,4
 		jb	loc_212			; Jump if below
 		cmp	ah,7
 		je	loc_212			; Jump if equal
 		jmp	loc_244			; (13CA)
loc_212:					;  xref A.1210, 1215
 		push	bx
 		mov	ax,cx
 		call	sub_36			; (1259)
 		jz	loc_218			; Jump if zero
 		add	si,ax
 		mov	ah,dh
 		sub	ah,bl
loc_213:					;  xref A.1231
 		call	sub_37			; (1280)
 		add	si,bp
 		add	di,bp
 		dec	ah
 		jnz	loc_213			; Jump if not zero
loc_214:					;  xref A.1257
 		pop	ax
 		mov	al,20h			; ' '
loc_215:					;  xref A.123D
 		call	sub_38			; (1289)
 		add	di,bp
 		dec	bl
 		jnz	loc_215			; Jump if not zero
loc_216:					;  xref A.12C5
 		mov	ax,40h
 		mov	ds,ax
 		cmp	byte ptr ds:video_mode,7	; (0040:0049=3)
 		je	loc_217			; Jump if equal
 		mov	al,ds:video_mode_reg	; (0040:0065=29h)
 		mov	dx,3D8h
 		out	dx,al			; port 3D8h, CGA video control
loc_217:					;  xref A.1249
 		jmp	loc_200			; (1136)
loc_218:					;  xref A.1220
 		mov	bl,dh
 		jmp	short loc_214		; (1233)

;===============================================================================
 ;                              SUBROUTINE
 ;
 ;         Called from:   A.121D, 12A3
;===============================================================================
;a.1259
sub_36		proc	near
 		call	sub_35			; (11FA)
 		add	ax,ds:video_segment	; (0040:004E=0)
 		mov	di,ax
 		mov	si,ax
 		sub	dx,cx
 		inc	dh
 		inc	dl
 		xor	ch,ch			; Zero register
 		mov	bp,ds:video_columns	; (0040:004A=50h)
 		add	bp,bp
 		mov	al,bl
 		mul	byte ptr ds:video_columns	; (0040:004A=50h) ax = data * al
 		add	ax,ax
 		push	es
 		pop	ds
 		cmp	bl,0
 		retn
sub_36		endp


;===============================================================================
 ;                              SUBROUTINE
 ;
 ;         Called from:   A.1228, 12AE
;===============================================================================
;a.1280
sub_37		proc	near
 		mov	cl,dl
 		push	si
 		push	di
 		rep	movsw			; Rep when cx >0 Mov [si] to es:[di]
 		pop	di
 		pop	si
 		retn
sub_37		endp


;===============================================================================
 ;                              SUBROUTINE
 ;
 ;         Called from:   A.1236, 12BC
;===============================================================================
;a.1289
sub_38		proc	near
 		mov	cl,dl
 		push	di
 		rep	stosw			; Rep when cx >0 Store ax to es:[di]
 		pop	di
 		retn
sub_38		endp


;����� Indexed Entry Point ������������������������������������������������
;a.1290
loc_219:					;  xref A.0FDF, 101B
 		std				; Set direction flag
 		mov	bl,al
 		cmp	ah,4
 		jb	loc_220			; Jump if below
 		cmp	ah,7
 		je	loc_220			; Jump if equal
 		jmp	loc_250			; (1423)
loc_220:					;  xref A.1296, 129B
 		push	bx
 		mov	ax,dx
 		call	sub_36			; (1259)
 		jz	loc_224			; Jump if zero
 		sub	si,ax
 		mov	ah,dh
 		sub	ah,bl
loc_221:					;  xref A.12B7
 		call	sub_37			; (1280)
 		sub	si,bp
 		sub	di,bp
 		dec	ah
 		jnz	loc_221			; Jump if not zero
loc_222:					;  xref A.12CA
 		pop	ax
 		mov	al,20h			; ' '
loc_223:					;  xref A.12C3
 		call	sub_38			; (1289)
 		sub	di,bp
 		dec	bl
 		jnz	loc_223			; Jump if not zero
 		jmp	loc_216			; (123F)
loc_224:					;  xref A.12A6
 		mov	bl,dh
 		jmp	short loc_222		; (12B9)

;����� Indexed Entry Point ������������������������������������������������
;a.12cc
loc_225:					;  xref A.0FE1, 101B
 		cmp	ah,4
 		jb	loc_226			; Jump if below
 		cmp	ah,7
 		je	loc_226			; Jump if equal
 		jmp	loc_268			; (155F)
loc_226:					;  xref A.12CF, 12D4
 		call	sub_39			; (12F6)
 		mov	si,bx
 		mov	dx,ds:video_port	; (0040:0063=3D4h)
 		add	dx,6
 		push	es
 		pop	ds
loc_227:					;  xref A.12EA
 		in	al,dx			; port 3DAh, CGA/EGA vid status
 		test	al,1
 		jnz	loc_227			; Jump if not zero
 		cli				; Disable interrupts
loc_228:					;  xref A.12F0
 		in	al,dx			; port 3DAh, CGA/EGA vid status
 		test	al,1
 		jz	loc_228			; Jump if zero
 		lodsw				; String [si] to ax
 		jmp	loc_200			; (1136)

;===============================================================================
 ;                              SUBROUTINE
 ;
 ;         Called from:   A.12D9, 1323, 1343
;===============================================================================
;a.12f6
sub_39		proc	near
 		mov	cl,bh
 		xor	ch,ch			; Zero register
 		mov	si,cx
 		shl	si,1			; Shift w/zeros fill
 		mov	ax,ds:vid_curs_pos0[si]	; (0040:0050=184Fh)
 		xor	bx,bx			; Zero register
 		jcxz	loc_230			; Jump if cx=0

locloop_229:					;  xref A.130A
 		add	bx,ds:video_buf_siz	; (0040:004C=1000h)
 		loop	locloop_229		; Loop if cx > 0

loc_230:					;  xref A.1304
 		call	sub_35			; (11FA)
 		add	bx,ax
 		retn
sub_39		endp


;����� Indexed Entry Point ������������������������������������������������
;a.1312
loc_231:					;  xref A.0FE3, 101B
 		cmp	ah,4
 		jb	loc_232			; Jump if below
 		cmp	ah,7
 		je	loc_232			; Jump if equal
 		jmp	loc_256			; (14AD)
loc_232:					;  xref A.1315, 131A
 		mov	ah,bl
 		push	ax
 		push	cx
 		call	sub_39			; (12F6)
 		mov	di,bx
 		pop	cx
 		pop	bx

locloop_233:					;  xref A.132F
 		cli				; Disable interrupts
 		mov	ax,bx
 		stosw				; Store ax to es:[di]
 		sti				; Enable interrupts
 		loop	locloop_233		; Loop if cx > 0

 		jmp	loc_200			; (1136)

;����� Indexed Entry Point ������������������������������������������������
;a.1334
loc_234:					;  xref A.0FE5, 101B
 		cmp	ah,4
 		jb	loc_235			; Jump if below
 		cmp	ah,7
 		je	loc_235			; Jump if equal
 		jmp	loc_256			; (14AD)
loc_235:					;  xref A.1337, 133C
 		push	ax
 		push	cx
 		call	sub_39			; (12F6)
 		mov	di,bx
 		pop	cx
 		pop	bx

locloop_236:					;  xref A.134E
 		mov	al,bl
 		stosb				; Store al to es:[di]
 		inc	di
 		loop	locloop_236		; Loop if cx > 0

 		jmp	loc_200			; (1136)

;����� Indexed Entry Point ������������������������������������������������
;a.1353
loc_237:					;  xref A.0FEB, 101B
 		call	sub_40			; (1387)
 		mov	al,es:[si]
 		and	al,ah
 		shl	al,cl			; Shift w/zeros fill
 		mov	cl,dh
 		rol	al,cl			; Rotate
 		jmp	loc_200			; (1136)

;����� Indexed Entry Point ������������������������������������������������
;a.1364
loc_238:					;  xref A.0FE9, 101B
 		push	ax
 		push	ax
 		call	sub_40			; (1387)
 		shr	al,cl			; Shift w/zeros fill
 		and	al,ah
 		mov	cl,es:[si]
 		pop	bx
 		test	bl,80h
 		jnz	loc_240			; Jump if not zero
 		not	ah
 		and	cl,ah
 		or	al,cl
loc_239:					;  xref A.1385
 		mov	es:[si],al
 		pop	ax
 		jmp	loc_200			; (1136)
loc_240:					;  xref A.1374
 		xor	al,cl
 		jmp	short loc_239		; (137C)

;===============================================================================
 ;                              SUBROUTINE
 ;
 ;         Called from:   A.1353, 1366
;===============================================================================
;a.1387
sub_40		proc	near
 		push	bx
 		push	ax
 		mov	al,28h			; '('
 		push	dx
 		and	dl,0FEh
 		mul	dl			; ax = reg * al
 		pop	dx
 		test	dl,1
 		jz	loc_241			; Jump if zero
 		add	ax,2000h
loc_241:					;  xref A.1395
 		mov	si,ax
 		pop	ax
 		mov	dx,cx
 		mov	bx,2C0h
 		mov	cx,302h
 		cmp	byte ptr ds:video_mode,6	; (0040:0049=3)
 		jb	loc_242			; Jump if below
 		mov	bx,180h
 		mov	cx,703h
loc_242:					;  xref A.13AA
 		and	ch,dl
 		shr	dx,cl			; Shift w/zeros fill
 		add	si,dx
 		mov	dh,bh
 		sub	cl,cl
loc_243:					;  xref A.13C2
 		ror	al,1			; Rotate
 		add	cl,ch
 		dec	bh
 		jnz	loc_243			; Jump if not zero
 		mov	ah,bl
 		shr	ah,cl			; Shift w/zeros fill
 		pop	bx
 		retn
sub_40		endp

;a.13ca
loc_244:					;  xref A.1217
 		mov	bl,al
 		mov	ax,cx
 		call	sub_47			; (163B)
 		mov	di,ax
 		sub	dx,cx
 		add	dx,101h
 		shl	dh,1			; Shift w/zeros fill
 		shl	dh,1			; Shift w/zeros fill
 		cmp	byte ptr ds:[video_mode],6	; (A.0049=66h)
 		jae	loc_245			; Jump if above or =
 		shl	dl,1			; Shift w/zeros fill
 		shl	di,1			; Shift w/zeros fill
loc_245:					;  xref A.13E2
 		push	es
 		pop	ds
 		sub	ch,ch
 		shl	bl,1			; Shift w/zeros fill
 		shl	bl,1			; Shift w/zeros fill
 		jz	loc_249			; Jump if zero
 		mov	al,bl
 		mov	ah,50h			; 'P'
 		mul	ah			; ax = reg * al
 		mov	si,di
 		add	si,ax
 		mov	ah,dh
 		sub	ah,bl
loc_246:					;  xref A.140D
 		call	sub_41			; (1483)
 		sub	si,1FB0h
 		sub	di,1FB0h
 		dec	ah
 		jnz	loc_246			; Jump if not zero
loc_247:					;  xref A.1421
 		mov	al,bh
loc_248:					;  xref A.141A
 		call	sub_42			; (149C)
 		sub	di,1FB0h
 		dec	bl
 		jnz	loc_248			; Jump if not zero
 		jmp	loc_200			; (1136)
loc_249:					;  xref A.13F0
 		mov	bl,dh
 		jmp	short loc_247		; (140F)
;a.1423
loc_250:					;  xref A.129D
 		std				; Set direction flag
 		mov	bl,al
 		mov	ax,dx
 		call	sub_47			; (163B)
 		mov	di,ax
 		sub	dx,cx
 		add	dx,101h
 		shl	dh,1			; Shift w/zeros fill
 		shl	dh,1			; Shift w/zeros fill
 		cmp	byte ptr ds:[video_mode],6	; (A.0049=66h)
 		jae	loc_251			; Jump if above or =
 		shl	dl,1			; Shift w/zeros fill
 		shl	di,1			; Shift w/zeros fill
 		inc	di
;a.1443
loc_251:					;  xref A.143C
 		push	es
 		pop	ds
 		sub	ch,ch
 		add	di,offset data_79+1	; (A.00F0=46h)
 		shl	bl,1			; Shift w/zeros fill
 		shl	bl,1			; Shift w/zeros fill
 		jz	loc_255			; Jump if zero
 		mov	al,bl
 		mov	ah,50h			; 'P'
 		mul	ah			; ax = reg * al
 		mov	si,di
 		sub	si,ax
 		mov	ah,dh
 		sub	ah,bl
loc_252:					;  xref A.146C
 		call	sub_41			; (1483)
 		sub	si,2050h
 		sub	di,2050h
 		dec	ah
 		jnz	loc_252			; Jump if not zero
loc_253:					;  xref A.1481
 		mov	al,bh
loc_254:					;  xref A.1479
 		call	sub_42			; (149C)
 		sub	di,2050h
 		dec	bl
 		jnz	loc_254			; Jump if not zero
 		cld				; Clear direction
 		jmp	loc_200			; (1136)
loc_255:					;  xref A.144F
 		mov	bl,dh
 		jmp	short loc_253		; (146E)

;===============================================================================
 ;                              SUBROUTINE
 ;
 ;         Called from:   A.1400, 145F
;===============================================================================
;a.1483
sub_41		proc	near
 		mov	cl,dl
 		push	si
 		push	di
 		rep	movsb			; Rep when cx >0 Mov [si] to es:[di]
 		pop	di
 		pop	si
 		add	si,2000h		;data_121e (A.2000=0)
 		add	di,2000h		;data_121e (A.2000=0)
 		push	si
 		push	di
 		mov	cl,dl
 		rep	movsb			; Rep when cx >0 Mov [si] to es:[di]
 		pop	di
 		pop	si
 		retn
sub_41		endp


;===============================================================================
 ;                              SUBROUTINE
 ;
 ;         Called from:   A.1411, 1470
;===============================================================================
;a.149c
sub_42		proc	near
 		mov	cl,dl
 		push	di
 		rep	stosb			; Rep when cx >0 Store al to es:[di]
 		pop	di
 		add	di,2000h		;data_121e (A.2000=0)
 		push	di
 		mov	cl,dl
 		rep	stosb			; Rep when cx >0 Store al to es:[di]
 		pop	di
 		retn
sub_42		endp

;a.14ad
loc_256:					;  xref A.131C, 133E
 		mov	ah,0
 		push	ax
 		call	sub_46			; (1638)
 		mov	di,ax
 		pop	ax
 		cmp	al,80h
 		jae	loc_257			; Jump if above or =
 		mov	si,offset data_124	; (C000:176D=0)
 		push	cs
 		jmp	short loc_258		; (14CF)
loc_257:					;  xref A.14B8
 		sub	al,80h
 		push	ds
 		sub	si,si
 		mov	ds,si
 		lds	si,dword ptr ds:Int1Fv	; (0000:007C=5E9h) Load seg:offset ptr
 		mov	dx,ds
 		pop	ds
 		push	dx
loc_258:					;  xref A.14BE
 		shl	ax,1			; Shift w/zeros fill
 		shl	ax,1			; Shift w/zeros fill
 		shl	ax,1			; Shift w/zeros fill
 		add	si,ax
 		cmp	byte ptr ds:[video_mode],6	; (A.0049=66h)
 		pop	ds
 		jc	loc_263			; Jump if carry Set

;a.14df
locloop_259:					;  xref A.14FA
 		push	di
 		push	si
 		mov	dh,4
loc_260:					;  xref A.14F5
 		lodsb				; String [si] to al
 		test	bl,80h
 		jnz	loc_262			; Jump if not zero
 		stosb				; Store al to es:[di]
 		lodsb				; String [si] to al
loc_261:					;  xref A.1509
 		mov	byte ptr es:cksumb[di],al	; (A.1FFF=0E6h)
 		add	di,4Fh
 		dec	dh
 		jnz	loc_260			; Jump if not zero
 		pop	si
 		pop	di
 		inc	di
 		loop	locloop_259		; Loop if cx > 0

 		jmp	loc_200			; (1136)
loc_262:					;  xref A.14E7
 		xor	al,es:[di]
 		stosb				; Store al to es:[di]
 		lodsb				; String [si] to al
 		xor	al,byte ptr es:cksumb[di]	; (A.1FFF=0E6h)
 		jmp	short loc_261		; (14EB)
loc_263:					;  xref A.14DD
 		mov	dl,bl
 		shl	di,1			; Shift w/zeros fill
 		call	sub_43			; (15E3)

;a.1512
locloop_264:					;  xref A.155A
 		push	di
 		push	si
 		mov	dh,4
loc_265:					;  xref A.1553
 		lodsb				; String [si] to al
 		call	sub_44			; (15F8)
 		and	ax,bx
 		test	dl,80h
 		jz	loc_266			; Jump if zero
 		xor	ah,es:[di]
 		xor	al,es:[di+1]
loc_266:					;  xref A.151F
 		mov	es:[di],ah
 		mov	es:[di+1],al
 		lodsb				; String [si] to al
 		call	sub_44			; (15F8)
 		and	ax,bx
 		test	dl,80h
 		jz	loc_267			; Jump if zero
 		xor	ah,es:data_121e[di]	; (A.2000=0)
 		xor	al,es:data_122e[di]	; (A.2001=0)
loc_267:					;  xref A.1538
 		mov	es:data_121e[di],ah	; (A.2000=0)
 		mov	es:data_122e[di],al	; (A.2001=0)
 		add	di,50h
 		dec	dh
 		jnz	loc_265			; Jump if not zero
 		pop	si
 		pop	di
 		add	di,2
 		loop	locloop_264		; Loop if cx > 0

 		jmp	loc_200			; (1136)
loc_268:					;  xref A.12D6
 		call	sub_46			; (1638)
 		mov	si,ax
 		sub	sp,8
 		mov	bp,sp
;***
 		cmp	byte ptr ds:video_mode,6	;data_123e,6 text 80x25/40x25
 		push	es
 		pop	ds
 		jc	loc_270			; Jump if carry Set
 		mov	dh,4
;a.1574
loc_269:					;  xref A.1587
 		mov	al,[si]
 		mov	[bp],al
 		inc	bp
 		mov	al,ds:data_121e[si]	; (A.2000=0)
 		mov	[bp],al
 		inc	bp
 		add	si,50h
 		dec	dh
 		jnz	loc_269			; Jump if not zero
 		jmp	short loc_272		; (15A2)
 		db	90h
loc_270:					;  xref A.1570
 		shl	si,1			; Shift w/zeros fill
 		mov	dh,4
loc_271:					;  xref A.15A0
 		call	sub_45			; (161B)
 		add	si,2000h		; data_121e (A.2000=0)
 		call	sub_45			; (161B)
 		sub	si,1FB0h
 		dec	dh
 		jnz	loc_271			; Jump if not zero
loc_272:					;  xref A.1589
 		mov	di,offset data_124		; (C000:176D=0)
 		push	cs
 		pop	es
 		sub	bp,8
 		mov	si,bp
 		cld				; Clear direction
 		mov	al,0
loc_273:					;  xref A.15DB
 		push	ss
 		pop	ds
 		mov	dx,80h
;a.15b4
loc_274:					;  xref A.15C5
 		push	si
 		push	di
 		mov	cx,8
 		repe	cmpsb			; Rep zf=1+cx >0 Cmp [si] to es:[di]
 		pop	di
 		pop	si
 		jz	loc_275			; Jump if zero
 		inc	al
 		add	di,8
 		dec	dx
 		jnz	loc_274			; Jump if not zero
 		cmp	al,0
 		je	loc_275			; Jump if equal
 		sub	ax,ax
 		mov	ds,ax
 		les	di,dword ptr ds:Int1Fv	; (0000:007C=5E9h) Load seg:offset ptr
 		mov	ax,es
 		or	ax,di
 		jz	loc_275			; Jump if zero
 		mov	al,80h
 		jmp	short loc_273		; (15AF)
loc_275:					;  xref A.15BD, 15C9, 15D7
 		add	sp,8
 		jmp	loc_200			; (1136)

;===============================================================================
 ;                              SUBROUTINE
 ;
 ;         Called from:   A.150F
;===============================================================================
;a.15e3
sub_43		proc	near
 		and	bl,3
 		mov	al,bl
 		push	cx
 		mov	cx,3

locloop_276:					;  xref A.15F2
 		shl	al,1			; Shift w/zeros fill
 		shl	al,1			; Shift w/zeros fill
 		or	bl,al
 		loop	locloop_276		; Loop if cx > 0

 		mov	bh,bl
 		pop	cx
 		retn
sub_43		endp


;===============================================================================
 ;                              SUBROUTINE
 ;
 ;         Called from:   A.1517, 1530
;===============================================================================
;a.15f8
sub_44		proc	near
 		push	dx
 		push	cx
 		push	bx
 		mov	dx,0
 		mov	cx,1
loc_277:					;  xref A.1613
 		mov	bx,ax
 		and	bx,cx
 		or	dx,bx
 		shl	ax,1			; Shift w/zeros fill
 		shl	cx,1			; Shift w/zeros fill
 		mov	bx,ax
 		and	bx,cx
 		or	dx,cx
 		shl	cx,1			; Shift w/zeros fill
 		jnc	loc_277			; Jump if carry=0
 		mov	ax,dx
 		pop	bx
 		pop	cx
 		pop	dx
 		retn
sub_44		endp


;===============================================================================
 ;                              SUBROUTINE
 ;
 ;         Called from:   A.1590, 1597
;===============================================================================
;a.161b
sub_45		proc	near
 		mov	ah,[si]
 		mov	al,[si+1]
 		mov	cx,0C000h
 		mov	dl,0
loc_278:					;  xref A.1631
 		test	ax,cx
 		clc				; Clear carry flag
 		jz	loc_279			; Jump if zero
 		stc				; Set carry flag
loc_279:					;  xref A.1628
 		rcl	dl,1			; Rotate thru carry
 		shr	cx,1			; Shift w/zeros fill
 		shr	cx,1			; Shift w/zeros fill
 		jnc	loc_278			; Jump if carry=0
 		mov	[bp],dl
 		inc	bp
 		retn
sub_45		endp


;===============================================================================
 ;                              SUBROUTINE
 ;
 ;         Called from:   A.14B0, 155F
;===============================================================================
;a.1638
sub_46		proc	near
 		mov	ax,word ptr ds:[vid_curs_pos0]	; (A.0050=74AAh) cursor position

;���� External Entry into Subroutine ��������������������������������������
 ;
 ;         Called from:   A.13CE, 1428
;a.163b
sub_47:
 		push	bx
 		mov	bx,ax
 		mov	al,ah
 		mul	byte ptr ds:[video_columns]	; (A.004A=0) ax = data * al columns
 		shl	ax,1			; Shift w/zeros fill
 		shl	ax,1			; Shift w/zeros fill
 		sub	bh,bh
 		add	ax,bx
 		pop	bx
 		retn
sub_46		endp


;����� Indexed Entry Point ������������������������������������������������
;a.164e
loc_280:					;  xref A.0FED, 101B
 		push	ax
 		push	ax
 		mov	ah,3
 		int	10h			; Video display   ah=functn 03h
 						;  get cursor loc in dx, mode cx
 		pop	ax
 		cmp	al,8
 		je	loc_288			; Jump if equal
 		cmp	al,0Dh
 		je	loc_289			; Jump if equal
 		cmp	al,0Ah
 		je	loc_290			; Jump if equal
 		cmp	al,7
 		je	loc_291			; Jump if equal
 		mov	bh,ds:video_page	; (0040:0062=0)
 		mov	ah,0Ah
 		mov	cx,1
 		int	10h			; Video display   ah=functn 0Ah
 						;  set char al at present curs
 						;   cx=# of chars to replicate
 		inc	dl
 		cmp	dl,byte ptr ds:video_columns	; (0040:004A=50h)
 		jne	loc_287			; Jump if not equal
 		mov	dl,0
 		cmp	dh,18h
 		jne	loc_286			; Jump if not equal
loc_281:					;  xref A.16C4
 		mov	ah,2
 		mov	bh,0
 		int	10h			; Video display   ah=functn 02h
 						;  set cursor location in dx
 		mov	al,byte ptr ds:[video_mode]	; (A.0049=66h)
 		cmp	al,4
 		jb	loc_282			; Jump if below
 		cmp	al,7
 		mov	bh,0
 		jnz	loc_283			; Jump if not zero
loc_282:					;  xref A.168A
 		mov	ah,8
 		int	10h			; Video display   ah=functn 08h
 						;  get char al & attrib ah @curs
 		mov	bh,ah
loc_283:					;  xref A.1690
 		mov	ax,601h
 		mov	cx,0
 		mov	dh,18h
 		mov	dl,byte ptr ds:[video_columns]	; (A.004A=0)
 		dec	dl
loc_284:					;  xref A.16B0
 		int	10h			; Video display   ah=functn 02h
 						;  set cursor location in dx
;a.16a8
loc_285:					;  xref A.16CB
 		pop	ax
 		jmp	loc_200			; (1136)
loc_286:					;  xref A.167D, 16C2
 		inc	dh
loc_287:					;  xref A.1676, 16B5, 16B9, 16BD
 		mov	ah,2
 		jmp	short loc_284		; (16A6)
loc_288:					;  xref A.1657
 		cmp	dl,0
 		je	loc_287			; Jump if equal
 		dec	dl
 		jmp	short loc_287		; (16AE)
loc_289:					;  xref A.165B
 		mov	dl,0
 		jmp	short loc_287		; (16AE)
loc_290:					;  xref A.165F
 		cmp	dh,18h
 		jne	loc_286			; Jump if not equal
 		jmp	short loc_281		; (167F)
loc_291:					;  xref A.1663
 		mov	bl,2
 		call	BEEP			; (05C3)
 		jmp	short loc_285		; (16A8)

;a.16cd
;Light Pen offset table
PENOFF:	db	3, 3, 5, 5, 3, 3, 3, 4		; Data table (indexed access) xref A.1704
     		

;����� Indexed Entry Point ������������������������������������������������
;a.16d5
loc_292:					;  xref A.0FD9, 101B
 		mov	ah,0
 		mov	dx,ds:video_port	; (0040:0063=3D4h)
 		add	dx,6
 		in	al,dx			; port 3DAh, CGA/EGA vid status
 		test	al,4
 		jnz	loc_297			; Jump if not zero
 		test	al,2
 		jz	loc_298			; Jump if zero
 		mov	ah,10h
 		mov	dx,ds:video_port	; (0040:0063=3D4h)
 		mov	al,ah
 		out	dx,al			; port 3D4h, CGA/EGA reg index
 						;  al = 10h, light pen high
 		inc	dx
 		in	al,dx			; port 3D5h, CGA/EGA indxd data
 		mov	ch,al
 		dec	dx
 		inc	ah
 		mov	al,ah
 		out	dx,al			; port 3D4h, CGA/EGA reg index
 						;  al = 11h, light pen low
 		inc	dx
 		in	al,dx			; port 3D5h, CGA/EGA indxd data
 		mov	ah,ch
 		mov	bl,ds:video_mode	; (0040:0049=3)
 		sub	bh,bh
 		mov	bl,byte ptr cs:PENOFF[bx]	; (A.16CD=3)
 		sub	ax,bx
 		sub	ax,ds:video_segment	; (0040:004E=0)
 		jns	loc_293			; Jump if not sign
 		mov	ax,0
;a.1714
loc_293:					;  xref A.170F
 		mov	cl,3
 		cmp	byte ptr ds:video_mode,4	; (0040:0049=3)
 		jb	loc_295			; Jump if below
 		cmp	byte ptr ds:video_mode,7	; (0040:0049=3)
 		je	loc_295			; Jump if equal
 		mov	dl,28h			; '('
 		div	dl			; al, ah rem = ax/reg
 		mov	ch,al
 		add	ch,ch
 		mov	bl,ah
 		sub	bh,bh
 		cmp	byte ptr ds:video_mode,6	; (0040:0049=3)
 		jne	loc_294			; Jump if not equal
 		mov	cl,4
 		shl	ah,1			; Shift w/zeros fill
loc_294:					;  xref A.1735
 		shl	bx,cl			; Shift w/zeros fill
 		mov	dl,ah
 		mov	dh,al
 		shr	dh,1			; Shift w/zeros fill
 		shr	dh,1			; Shift w/zeros fill
 		jmp	short loc_296		; (1759)
loc_295:					;  xref A.171B, 1722
 		div	byte ptr ds:video_columns	; (0040:004A=50h) al,ah rem = ax/data
 		mov	dh,al
 		mov	dl,ah
 		shl	al,cl			; Shift w/zeros fill
 		mov	ch,al
 		mov	bl,ah
 		xor	bh,bh			; Zero register
 		shl	bx,cl			; Shift w/zeros fill
;a.1759
loc_296:					;  xref A.1745
 		mov	ah,1
loc_297:					;  xref A.16E1
 		push	dx
 		mov	dx,ds:video_port	; (0040:0063=3D4h)
 		add	dx,7
 		out	dx,al			; port 3DBh, CGA light pen clr
 		pop	dx
loc_298:					;  xref A.16E5
 		pop	di
 		pop	si
 		pop	ds
 		pop	ds
 		pop	ds
 		pop	ds
 		pop	es
 		iret				; Interrupt return

 ; this doesn't seem to code for anything useful through 1C00, so
 ; maybe it's data tables of some sort
 ;a.176d
 data_124:	db	8 dup (0)
     		db	 73h, 81h,0A5h, 81h,0BDh, 99h
     		db	 81h, 73h, 73h,0FFh,0DBh,0FFh
     		db	0C3h,0E7h,0FFh, 7Eh, 6Ch,0FEh
     		db	0FEh,0FEh, 7Ch, 38h, 10h, 00h
     		db	 10h, 38h, 7Ch,0FEh, 7Ch, 38h
     		db	 10h, 08h, 38h, 7Ch, 38h,0FEh
     		db	0FEh, 7Ch, 38h, 7Ch, 10h, 10h
 		db	38h
;a.17a0
loc_299:					;  xref A.17A0
 		jl	loc_299			; Jump if <
 		jl	$+3Ah			; Jump if <
 		jl	$+2			; delay for I/O
 		add	[bx+si],bl
 		cmp	al,3Ch			; '<'
 		sbb	[bx+si],al
; 		add	bh,bh
		db	0, 0ffh
 		jmp	di			;*
 			                        ;* No entry point to code
 		retn
 			                        ;* No entry point to code
 		retn
 			                        ;* No entry point to code
 		out	0FFh,ax			; port 0FFh ??I/O Non-standard
 		inc	word ptr [bx+si]
 		cmp	al,66h			; 'f'
 		inc	dx
 		inc	dx
		db	 66h, 3Ch, 00h,0FFh,0C3h, 99h
		db	0BDh,0B0h, 99h,0C3h,0FFh, 0Fh
		db	 07h, 0Fh, 7Dh,0CCh,0CCh,0CCh
		db	 78h, 3Ch, 66h, 66h, 66h, 3Ch
		db	 18h, 7Eh, 18h, 3Fh, 3Fh, 3Fh
		db	 30h, 30h, 70h,0F0h,0E0h, 7Fh
		db	 63h, 7Fh, 63h, 63h, 67h,0E6h
		db	0C0h, 99h, 5Ah, 3Ch,0E7h,0E7h
		db	 3Ch, 5Ah, 99h, 80h,0E0h,0F8h
		db	0FEh,0F8h,0E0h, 80h, 00h, 02h
		db	 0Eh, 3Eh,0FEh, 3Eh, 0Eh, 02h
		db	 00h, 18h, 3Ch, 7Eh, 18h, 18h
		db	 7Eh, 3Ch, 18h, 66h, 66h, 66h
		db	 66h, 66h, 00h, 66h, 00h, 7Fh
		db	0DBh,0DBh, 7Bh, 1Bh, 1Bh, 1Bh
		db	 00h, 3Eh, 63h, 38h, 6Ch, 6Ch
		db	 38h,0CCh, 78h, 00h, 00h, 00h
		db	 00h, 7Eh, 7Eh, 7Eh, 00h, 18h
		db	 3Ch, 7Eh, 18h, 7Eh, 3Ch, 18h
		db	0FFh, 18h, 3Ch, 7Eh, 18h, 18h
		db	 18h, 18h, 00h, 18h, 18h, 18h
		db	 18h, 73h, 3Ch, 18h, 00h, 00h
		db	 18h, 0Ch,0FEh, 0Ch, 18h, 00h
		db	 00h, 00h, 30h, 60h,0FEh, 60h
		db	 30h, 00h, 00h, 00h, 00h,0C0h
		db	0C0h,0C0h,0FEh, 00h, 00h, 00h
		db	 24h, 66h,0FFh, 66h, 24h, 00h
		db	 00h, 00h, 18h, 3Ch, 7Eh,0FFh
		db	0FFh, 00h, 00h, 00h,0FFh,0FFh
		db	 7Eh, 3Ch, 18h, 00h
 		db	9 dup (0)
 		db	 30h, 78h
;a.1877		
loc_300:
 ;*		js	loc_301			;*Jump if sign=1
 		db	 78h, 30h
 		xor	[bx+si],al
 		xor	[bx+si],al
 		insb				; Port dx to es:[di]
 		insb				; Port dx to es:[di]
 		insb				; Port dx to es:[di]
		db	 00h, 00h, 00h, 00h, 00h, 6Ch
		db	 6Ch,0FEh, 6Ch,0FEh, 6Ch, 6Ch
		db	 00h, 30h, 7Ch,0C0h, 78h, 0Ch
		db	0F8h, 30h, 00h, 00h,0C6h,0CCh
		db	 18h, 30h, 66h,0C6h, 00h, 38h
		db	 6Ch, 38h, 76h,0DCh,0CCh, 76h
			db	 00h, 60h, 60h,0C0h, 00h
		db	 00h, 00h, 00h, 00h, 18h, 30h
		db	 60h, 60h, 60h, 30h, 18h, 00h
		db	 60h, 30h, 18h, 18h, 18h, 30h
		db	 60h, 00h, 00h, 66h, 3Ch,0FFh
		db	 3Ch, 66h, 00h, 00h, 00h, 30h
 		db	 30h,0FCh
 		db	 30h, 30h
 		db	7 dup (0)
     		db	 30h, 30h, 60h, 00h, 00h, 00h
 		db	0FCh
 		db	9 dup (0)
     		db	 30h, 30h, 00h, 06h, 0Ch, 18h
     		db	 30h, 60h,0C0h, 80h, 00h, 7Ch
		db	0C6h,0CEh,0DEh,0F6h,0E6h, 7Ch
 		db	 00h
     		db	 30h, 70h, 30h, 30h, 30h, 30h
loc_302:					;  xref A.192D
 		cld				; Clear direction
 		add	[bx+si-34h],bh
 ;a.18fe
 ;loc_303:
 ;		int	3
 		or	al,38h			; '8'
 		pusha				; Save all regs
 		int	3			; Debug breakpoint
loc_304:					;  xref A.1935
 		cld				; Clear direction
 		add	[bx+si-34h],bh
 		or	al,38h			; '8'
 		or	al,0CCh
 		js	$+2			; delay for I/O
 		sbb	al,3Ch			; '<'
 		insb				; Port dx to es:[di]
 		int	3			; Debug breakpoint
 		dec	byte ptr [si]
 		push	ds
; 		add	ah,bh
		db	0, 0fch
 		sar	al,0Ch			; Shift w/sign fill
 		or	al,0CCh
 		js	$+2			; delay for I/O
 		cmp	[bx+si-40h],ah
 		clc				; Clear carry flag
 		int	3			; Debug breakpoint
 		int	3			; Debug breakpoint
 		js	$+2			; delay for I/O
 		cld				; Clear direction
 		int	3			; Debug breakpoint
 		or	al,18h
 		xor	[bx+si],dh
 		xor	[bx+si],al
 		js	loc_302			; Jump if sign=1
 		int	3			; Debug breakpoint
 ;*		js	loc_303		;*Jump if sign=1 18fe
 		db	 78h,0CCh
 		int	3			; Debug breakpoint
 		js	loc_305			; Jump if sign=1
loc_305:					;  xref A.1933
 		js	loc_304			; Jump if sign=1
 		int	3			; Debug breakpoint
 		jl	loc_306			; Jump if <
 ;*		sbb	[bx+si+0],dh
 		db	 18h, 70h, 00h
     		db	 00h, 30h, 30h, 00h, 00h, 30h
 		db	 30h, 00h, 00h
;a.1946
loc_306:					;  xref A.1938
 		xor	[bx+si],dh
 		add	[bx+si],al
 		xor	[bx+si],dh
 		pusha				; Save all regs
 		sbb	[bx+si],dh
 		pusha				; Save all regs
 		shl	byte ptr [bx+si+30h],18h	; Shift w/zeros fill
 		add	[bx+si],al
; 		add	ah,bh
		db	0, 0fch
 		add	[bx+si],al
 		cld				; Clear direction
 		add	[bx+si],al
 		pusha				; Save all regs
 		xor	[bx+si],bl
 		or	al,18h
 ;*		xor	[bx+si+0],ah
 		db	 30h, 60h, 00h
		db	 78h,0CCh, 0Ch, 18h, 30h, 00h
		db	 30h, 00h, 7Ch,0C6h,0DEh,0DEh
		db	0DEh,0C0h, 78h, 00h, 30h, 78h
		db	0CCh,0CCh,0FCh,0CCh,0CCh, 00h
		db	0FCh, 66h, 66h, 7Ch, 66h, 66h
		db	0FCh, 00h, 3Ch, 66h,0C0h,0C0h
		db	0C0h, 66h, 3Ch, 00h,0F8h, 6Ch
		db	 66h, 66h, 66h, 6Ch,0F8h, 00h
		db	0FEh, 62h, 68h, 78h, 68h, 62h
		db	0FEh, 00h,0FEh, 62h, 68h, 78h
		db	 68h, 60h,0F0h, 00h, 3Ch, 66h
		db	0C0h,0C0h,0CEh, 66h, 3Eh, 00h
		db	0CCh,0CCh,0CCh,0FCh,0CCh,0CCh
		db	0CCh, 00h, 78h, 30h, 30h, 30h
		db	 30h, 30h, 78h, 00h, 1Eh, 0Ch
		db	 0Ch, 0Ch,0CCh,0CCh, 78h, 00h
		db	0E6h, 66h, 6Ch, 78h, 6Ch, 66h
		db	0E6h, 00h,0F0h, 60h, 60h, 60h
		db	 62h, 66h,0FEh, 00h,0C6h,0EEh
		db	0FEh,0FEh,0D6h,0C6h,0C6h, 00h
		db	0C6h,0E6h,0F6h,0DEh,0CEh,0C6h
		db	0C6h, 00h, 38h, 6Ch,0C6h,0C6h
		db	0C6h, 6Ch, 38h, 00h,0FCh, 66h
		db	 66h, 7Ch, 60h, 60h,0F0h, 00h
		db	 78h,0CCh,0CCh,0CCh,0DCh, 78h
		db	 1Ch, 00h,0FCh, 66h, 66h, 7Ch
		db	 6Ch, 66h,0E6h, 00h, 78h,0CCh
		db	0E0h, 70h, 1Ch,0CCh, 78h, 00h
		db	0FCh,0B4h, 30h, 30h, 30h, 30h
		db	 78h, 00h,0CCh,0CCh,0CCh,0CCh
		db	0CCh,0CCh,0FCh, 00h,0CCh,0CCh
		db	0CCh,0CCh,0CCh, 78h,0C0h, 00h
		db	0C6h,0C6h,0C6h,0D6h,0FEh,0EEh
		db	0C6h, 00h,0C6h,0C6h, 6Ch, 38h
		db	 38h, 6Ch,0C6h, 00h,0CCh,0CCh
		db	0CCh, 78h, 30h, 30h, 78h, 00h
		db	0FEh,0C6h, 8Ch, 18h, 32h, 66h
		db	0FEh, 00h, 78h, 60h, 60h, 60h
		db	 60h, 60h, 78h, 00h,0C0h, 60h
		db	 30h, 18h, 0Ch, 06h, 02h, 00h
		db	 78h, 18h, 18h, 18h, 18h, 18h
		db	 78h, 00h, 10h, 38h, 6Ch,0C6h
		db	 00h, 00h
		db	9 dup (0)
		db	0FFh, 30h, 30h
;a.1a6f
loc_308:
 		sbb	[bx+si],al
		db	 00h, 00h, 00h, 00h, 00h, 00h
		db	 78h, 0Ch, 7Ch,0CCh, 76h, 00h
		db	0E0h, 60h, 60h, 7Ch, 66h, 66h
		db	0DCh, 00h, 00h, 00h, 78h,0CCh
		db	0C0h,0CCh, 78h, 00h, 1Ch, 0Ch
		db	 0Ch, 7Ch,0CCh,0CCh, 76h, 00h
		db	 00h, 00h, 78h,0CCh,0FCh,0C0h
		db	 78h, 00h, 38h, 6Ch, 60h,0F0h
		db	 60h, 60h,0F0h, 00h, 00h, 00h
		db	 76h,0CCh,0CCh, 7Ch, 0Ch,0F8h
		db	0E0h, 60h, 6Ch, 76h, 66h, 66h
		db	0E6h, 00h, 30h, 00h, 70h, 30h
		db	 30h, 30h, 78h, 00h, 0Ch, 00h
		db	 0Ch, 0Ch, 0Ch,0CCh,0CCh, 78h
		db	0E0h, 60h, 66h, 6Ch, 78h, 6Ch
		db	0E6h, 00h, 70h, 30h, 30h, 30h
		db	 30h, 30h, 78h, 00h, 00h, 00h
		db	0CCh,0FEh,0FEh,0D6h,0C6h, 00h
		db	 00h, 00h,0F8h,0CCh,0CCh,0CCh
		db	0CCh, 00h, 00h, 00h, 78h,0CCh
		db	0CCh,0CCh, 78h, 00h, 00h, 00h
		db	0DCh, 66h, 66h, 7Ch, 60h,0F0h
		db	 00h, 00h, 76h,0CCh,0CCh, 7Ch
		db	 0Ch, 1Eh, 00h, 00h,0DCh, 76h
		db	 66h, 60h,0F0h, 00h, 00h, 00h
		db	 7Ch,0C0h, 78h, 0Ch,0F8h, 00h
		db	 10h, 30h, 7Ch, 30h, 30h, 34h
		db	 18h, 00h, 00h, 00h,0CCh,0CCh
		db	0CCh,0CCh, 76h, 00h, 00h, 00h
		db	0CCh,0CCh,0CCh, 78h, 30h, 00h
		db	 00h, 00h,0C6h,0D6h,0FEh,0FEh
		db	 6Ch, 00h, 00h, 00h,0C6h, 6Ch
		db	 38h, 6Ch,0C6h, 00h, 00h, 00h
		db	0CCh,0CCh,0CCh, 7Ch, 0Ch,0F8h
		db	 00h, 00h,0FCh, 98h, 30h, 64h
		db	0FCh, 00h, 1Ch, 30h, 30h,0E0h
		db	 30h, 30h, 1Ch, 00h, 18h, 18h
		db	 18h, 00h, 18h, 18h, 18h, 00h
		db	0E0h, 30h, 30h, 1Ch, 30h, 30h
		db	0E0h, 00h, 76h,0DCh
 		db	7 dup (0)
;a.1b66
     		db	 10h, 38h, 6Ch,0C6h,0C6h,0FEh
;a.1b6c
; 		db	148 dup (0)		; should end @1bff

IF	ROMSEARCH
;***** Expansion ROM code *****
; This is called after the hardware is initialized but before
; the video is displayed. Borrowed from the Generic XT BIOS.
EXPROM: MOV     DX,0C800h                       ; ROM segment start
	PUSH    DS

FNDROM: MOV     DS,DX                           ; Load ROM segment
        XOR     BX,BX                           ;  ...ID offset
        MOV     AX,[BX]                         ; Read the ROM id
        CMP     AX,0AA55h
        JNZ     NXTROM                          ;  ...not valid ROM
        MOV     AX,40h
        MOV     ES,AX
        MOV     AH,0
        MOV     AL,[BX+2]                       ; Get ROM size (bytes * 512)
        MOV     CL,5
        SHL     AX,CL                           ; Now ROM size in segments
        ADD     DX,AX                           ;  ...add base segment
        MOV     CL,4
        SHL     AX,CL                           ; ROM address in bytes
        MOV     CX,AX                           ;  ...checksum requires CX
        CALL    CHK_01                          ; Find ROM checksum
        JNZ     BADROM                          ;  ...bad ROM
        PUSH    DX
        MOV     Word ptr ES:[gen_io_ptr],3	; 67h Offset  for ROM being setup
        MOV     ES:[gen_io_ptr+2],DS		; 69h Segment for ROM being setup
        CALL    Dword ptr ES:[gen_io_ptr]	;  ...call ROM initialization
        POP     DX
        JMP     short FND_01			; see if there are any more ROMs

BADROM: OR      Byte ptr ES:[scratch1],ER_ROM          ; ROM present, bad checksum 15h

NXTROM: ADD     DX,80h                          ; Segment for next ROM

FND_01: CMP     DX,0F600h                       ; End of ROM space
        JL      FNDROM                          ;  ...no, continue
	ret

CHKSUM: MOV     CX,2000h                        ; Bytes in 2764 eprom
CHK_01: MOV     AL,0                            ;  ...zero checksum
ADDBYT: ADD     AL,[BX]                         ; Add byte to checksum
	INC     BX                              ;  ...BX --> next byte
	LOOP    ADDBYT                          ;  ...loop until done
	OR      AL,AL                           ; Set condition codes
	RET                                     ;  ...and return
ENDIF

; In Monitor v3.3, the SCSI code resides near the end of the ROM
; before some RAM test code and the 186 init. It is included as a
; library file (i.e., "scsi.lib"), which I assume is a plain text
; file.
;include "scsimon.asm"

;a.1c00
	org	01c00h
include "INIT186.ASM"
;	dup 	(POWER - $) dup (0)
; should end at 1fefh

;******************************************************************************
; Restart Address
;	org	01FF0h
	ENTRY 	01FF0h			; this should put fill bytes before
	PUBLIC	POWER
POWER:	jmpf	0FE00h, COLDST
;	db	09 dup (0)
;******************************************************************************
	ENTRY 	01FFEh
; NOTE: the original ROM did not have an equipment byte.
	db	0FBh			; model byte for later XT
cksumb:
	db	0E6h			; checksum byte xref A.14EB, 1504
code    ENDS
END POWER
