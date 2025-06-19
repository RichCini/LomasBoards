	name    scsiblk
	page    60,132
	title 	SCSI Block Device Driver
;
; This is the code from Hul Tytus from the September/October 1986
; issue of MicroSystems Journal (v2n5). Certain changes made for either
; clarity or to avoid naming conflicts.
;
; Compile with MASM and MSC
;	masm /la /Zd driver.asm,driver.com,,driver.lst
;	link driver,driver,driver;
;	exe2com	driver.exe driver.sys
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

; Begin Code Listing 1 - device driver
; HDRV REV	2.11.03		850112	Hul Tytus
	NAME C
extern	diskr:near
extern	init:near
extern	diskw:near
extern	maxblk:word

public	inbyte
public	outbyte
public	drive
public	dsget

DRVCNT		equ 2			;number of logical drives
TOTSECNT	equ 2400

DGROUP	GROUP	DATA
PGROUP	GROUP	BASE,PROG

BASE	segment word public 'PROG'
        assume cs:PGROUP,ds:DGROUP

;****************************************************************
;*      DEVICE HEADER REQUIRED BY DOS                           *
;****************************************************************
	dw 	-1 			;Offffh,Offffh 
	dw 	0
	dw 	offset catch 	;save add. to request header catch:
	dw 	offset start 	;start of driver code
unitc: 	db 	2 			;number of units
	db 	7 dup (0)		;0,0,0,0,0,0,0
savess:	dw 	0 
savesp:	dw 	0
reqhed:	dw 	0
	dw 	0

; BPB 0
bpbO: 	dw 	800h			;8OOh bytes per sector (2048)
	db 	1 			;sectors per cluster
	dw 	1 			;reserved sectors
	db 	2 			;number of fats
	dw 	192 			;number of root dir entries
					;3 sectors
totsctO:
	dw 	TOTSECNT-33		;total number of sectors
medis0:	db 	0f8h			;media descriptor
	dw 	3 			;number of fat sectors
	dw 	7 			;sectors per track
	dw 	7 			;number of heads
	dw 	0 			;number of hidden sectors

; BPB 1
bpb1: 	dw 	800h 			;bytes per sector
	db 	16 			;sectors per cluster
	dw 	1 			;reserved sectors
	db 	2			;number of fats
	dw 	192 			;number of root dir entries
					; 3 sectors
totsct1:
	dw 	0a5e0h			;total number of sectors
medis1:	db 	0f8h			;media descriptor
	dw 	3 			;number of fat sectors
	dw 	6 			;sectors per track
	dw 	7 			;number of heads
	dw 	0 			;number of hidden sectors
bpbpoint:
	dw 	offset bpb0
	dw 	offset bpb1
medpoint:
	dw 	offset medis0
	dw 	offset rnedis1
	db 	'ERROR'
	dw 	0 

jmptbl:
	dw 	offset hinit		; 0
	dw 	offset media		; 1
	dw 	offset bldbpb		; 2
	dw 	offset dummy		; 3
	dw 	offset hread		; 4
	dw 	offset dummy		; 5
	dw 	offset dummy		; 6
	dw 	offset dummy		; 7
	dw 	offset hwrite		; 8
	dw 	offset hwrite		; 9
	dw 	offset dummy		; 10
	dw 	offset dummy		; 11
	dw 	offset dunmy 		; 12

;	SCSI to MSDOS error code conversion
scsi:	db	2,3,4,0dh,10h,11h,12h,13h,14h,15h,19h,20h,
	db	21h,22h,23h,24h,25h,98h,0
msdos 	db	6,0ah,2,0,4,0bh,8,8,8,6,0ah,7,7,7,7,7
	db	7,4,0

C	proc	far
;****************************************************************
;*      THE STRATEGY PROCEDURE                                  *
;*								*
;* Called by MS-DOS with es:bx set to the address of the 	*
;* request header.						*
;****************************************************************
catch:	
	mov 	word ptr cs:[reqhed],bx
	mov 	word ptr cs:[reqhed+2],es
	ret 

;****************************************************************
;*	THE INTERRUPT PROCEDURE  				*
;****************************************************************
;device interrupt handler - 2nd call from DOS and start of the driver
start:
	push 	ax 			; start of driver
	push 	bx
	push 	cx
	push 	dx
	push 	bp
	push 	di
	push 	si
	push 	ds
	push 	es
	cli
	mov 	ax,ss 			; save stack pointer
	mov 	word ptr cs:[savess],ax
	mov 	ax,sp
	mov 	word ptr cs:[savesp],ax
	mov 	ax,seg DGROUP
	mov 	bx,cs
	add 	ax,bx
	mov 	ds,ax
	mov 	ss,ax
	mov 	sp,offset DGROUP:SBASES
	sti
	mov 	si,word ptr cs: [reghed] 	; load request header
	mov 	es,word ptr cs:[reghed+2]	; address
	xor 	ax,ax
	mov	al,es:[si+1]			; remember which logical drive
	mov 	word ptr ds:[drive],ax
	mov 	cx,8101h
	cmp 	al,DRVCNT 			; make sure legal drive
	jnc 	lastxx
	mov 	ax,word ptr cs:[error] 		; see if last call
	or 	ax,ax 				; produced an error
	jz 	skpinit
	push 	si 				; reinit if so
	push 	es
	push 	ds
	pop 	es
	call 	init
	pop 	es
	pop 	si
	call 	setcnt
skpinit:
	mov	al,es:[si+2]
	mov 	cx,8103h
	anp 	al,0ch 				;check for legal command
	jnc 	lastxx
	shl 	ax,1
	mov 	bx,offset cs:jmptbl
	add 	bx,ax
	call 	cs:[bx] 			; call command
	mov 	word ptr cs:[error],ax 		; save error code
	or 	al,al
	mov 	cx,100h
	jz 	lastxx
	call 	seterr
lastxx:						; load request header
	mov 	word ptr es:[si+3],cx		; with status code
	cli
	mov 	ax,word ptr cs:[savess]		; reload stack pointer
	mov 	ss,ax
	mov 	ax.word ptr cs: [savesp]
	mov 	sp,ax
	sti
	pop 	es
	pop 	ds
	pop 	si
	pop 	di
	pop 	bp
	pop 	dx
	pop 	cx
	pop 	bx
	pop 	ax
	ret
;
;
; Come here to abort
ABORT:
	mov 	cx,810ch
	jmp 	lastxx
C	endp

;----------------------------------------------------------------------------
; Initialize				function 0 = initialize
;----------------------------------------------------------------------------
hinit:
	push 	si
	push 	es
	push 	ds
	pop 	es
	call 	init				; initialize
	pop 	es
	pop 	si
	push 	ax
	mov 	al,byte ptr cs:[unitc]		; load reg head with # of
	mov 	byte ptr es:[si+0dh],al		; logical drives
	mov 	ax,offset cs:bpbpoint		; get pointer to BPB pointer
	mov 	bx.word ptr ds:[drive]		; figure which BPB tbl
	shl 	bx,1
	add 	ax,bx
	mov 	wordptr es:[si+12h],ax		; load req header with pointer
	mov 	ax,cs				; to BPB pointe
	mov 	word ptr es:[si+14h],ax
	xor 	ax,ax
	mov	word ptr es:[si+0eh],ax		; load req head with address of
	mov 	ax,seg buffer			; end of driver
	mov 	bx,cs
	add 	ax,bx
	mov 	word ptr es:[si+10h],ax
	pop 	ax
	push 	ax
	call 	setcnt				; set # of logical sectors
						; print install notice only onc
	mov 	al,byte ptr cs:[first]
	or 	al,al
	jnz 	hinit1
	inc	al
	mov 	byte ptr cs:[first],al
	push 	ds
	push 	es
	push 	si
	push 	cs
	pop 	ds
	mov 	dx,offset signon
	mov 	ah,9
	int 	21h
	pop 	si
	pop 	es
	pop 	ds
hinit1:
	xor	ax,ax
	pop	ax
	ret

setcnt: 				; sets number of sectors in
					; logical drive 2
					; ax--> if not 0, will abort
	push ax
	push bx

	push 	cx
	push 	dx
	mov 	dx,ax
	mov 	ax,lo.'Ord ptr [maxblkl		; get # of physical sectors
	mov 	bx,word ptr [maxblk+2]
	mov 	cx,2
setcntl:					;change to logical sectors
	she 	bx,l
	rcr 	ax,l
	loop 	setcntl
	or 	dx,dx
	jnz 	setcntfin
	mov 	bx,TOTSECNT+33
	sub 	ax,6x - ; sub logical sect's in drive I
	and 	ax,OfffOh ; make sure there is no partial cluster
	rnov 	word ptr cs:[totsctl),ax
setcntfin:
	pop 	dx
	pop 	cx
	pop 	bx
	pop 	ax
	ret

first:	db	0
signon:	db	'Hd.sys version 2.11.03 installed.' ,0dh,0ah,'$'

;----------------------------------------------------------------------------
; Media Check				function 1 = media check
;----------------------------------------------------------------------------
media:
	mov 	ax,word ptr cs:[error]
	or 	ax,ax
	mov 	al,Offh if error last time
	jnz 	medial set media changed status
	mov 	bx .word ptr ds: [drive]
	shl 	bx,l
	mov 	ax,offset medpoint
	add 	bx,ax
	mov 	bx,word ptr cs: [bx]
	mov 	al,byte ~tr cs:[bx]
	mov 	bl,es:[sl+Odh)
	anp 	al,bl if MSOOS matches driver's media byte
	mov 	al,l set no change status
	jz 	medial
	mov 	al,Offh else media changed status
media1:
	mov 	byte ptr es:[si+Oeh],al ;load req head with media status
	xor 	ax,ax
	ret

;----------------------------------------------------------------------------
; Get BPB				function 2 = get BPB
;----------------------------------------------------------------------------
bldbpb:
	mov 	bx,offset cs:bpb~int load req head with pointer to
	mov 	ax, Io.'Ord ptr ds:[drive] correct BPB table
	shl 	ax,l
	add 	bx,ax
	rnov 	ax.word ptr cs: [bx]
	mov 	word ptr es:[si+12hl ,ax
	mov 	ax,cs
	mov 	word ptr es: [si+14h] ,ax
	xor 	ax,ax
	ret

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
hread:
	push 	es 				; pass arguments to diskr in 1st #2
	push 	si
	mov 	bp,sp
	mov 	ax,word ptr es:[si+12h]
	push 	ax				; count
	mov 	ax,word ptr es:[si+10h]
	push 	ax 				; transfer seg
	mov 	ax,word ptr es:[si+0eh]
	push 	ax 				; transfer byte
	xor 	ax,ax
	push 	ax 				; sector MSW
	mov 	ax,word ptr es:[si+14h]
	push 	ax				; sector ISW
	push 	ds
	pop 	es
	call 	diskr
	mov 	sp,bp
	pop 	si
	pop 	es
	or 	ax,ax
	jz 	hread1
	xor 	cx,cx
	mov 	word ptr es:[si+12h],cx		; if error, tell MSDOS 0 sect's read
hread1:
	ret

;----------------------------------------------------------------------------
; Write Sectors				function 8 = write (output)
;----------------------------------------------------------------------------
; IN:
;   AX=start sector number
;   CX=sector count
; OUT:                        
;   CX=sector actually write
;   AX=error code, DER_NOERR=no error
; REG:
;----------------------------------------------------------------------------
hwrite:
	push 	es 				; pass arguments to diskw
	push 	si
	mov 	bp,sp
	mov 	ax,word ptr es:[si+12h]
	push 	ax 				; count
	mov 	ax,word ptr es:[si+10h]
	push 	ax 				; transfer seg
	mov 	ax,word ptr es:[si+0eh]
	push 	ax 				; transfer byte
	xor 	ax,ax
	push 	ax 				; sector MSW
	mov 	ax,word ptr es:[si+14h]
	push 	ax 				; sector LSW
	push 	ds
	pop 	es
	call 	diskw
	mov	sp,bp
	pop	si
	pop 	es
	or 	ax,ax
	jz 	hread1
	xor 	cx,cx 				; if error, tell MSDOS 0 sect's written
	mov	word ptr es:[si+12h],cx
hwrit1:	
	ret

dummy:						; just in case MSDOS sends unused command
	xor ax,ax
	ret

seterr: 					; al = error in, cx=error out
	mov 	bx,offset scsi 			; load error code table pointers
	mov 	dx,offset msdos
	mov 	cx,810ch 			; load default error
setrep:
	mov 	ah,byte ptr cs:[bx]
	or 	ah,ah				; if end of scsi table,	
	jnz 	seterr1
	ret					; return w/ default error

seterr1:
	cmp 	ah,al
	jz 	seterr2				; SCSI error found in table
	inc 	bx
	inc	dx
	jmp 	setrep				; try again
seterr2:
	mov 	bx,dx				; since SCSI match was found,
	mov 	cl,byte ptr cs:[bx]		; return MSDOS equivelent
	ret

inbyte	proc 	near
	pop 	bx
	pop 	dx
	push 	dx
	push 	bx
	xor 	ax,ax
	in 	al,dx
	ret
inbyte	endp

outbyte	proc 	near
	pop 	bx
	pop 	dx
	pop 	ax
	push 	ax
	push 	dx
	push 	bx
	out 	dx,al
	ret
outbyte endp

dsget proc near
	mov	ax,ds
	ret
dsget	endp

BASE 	ENDS

;****************************************************************
;*	STACK and DATA						*
;****************************************************************
STKRSV	EQU	256 				; reserved stack size

DATA	segment para public 'DATA'
	public	BASE 
SBASE	db	STKRSV dup (?)
SBASES	db	0,0
BASE	dw	offset DGROUP:SBASE
NULL	dw	0
drive	dw	0
DATA	ENDS

PROG	segment byte public 'PROG'
	assume cs:PGROUP, ds:DGROUP
	nop
	nop
PROG	ENDS

buffer	segment memory 'last'
	db	0,0
buffer	ends

	END
