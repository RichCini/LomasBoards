; Lomas SCSI Driver from TCJ #33 by John C. Ford
; 
;	Listing 1 - SCSI testdriver
;
;	adapted from Rick Lehrbaum's example SCSI driver in
;	The Computer Journal, issue 26, page 12 ff, 1986
;
;	conversion to 8086 assembly by J. C. Ford, 4/88
;
; macro to slow down S100 and 8086
;	this is to prevent the 8086 from accessing the I/O ports
;	too quickly. It forces the instruction queue to empty

pause	macro
	jmp	$+2
	endm
	
; general equates

lf		equ	0Ah
cr		equ	0Dh

; the next address is Lomas specific. I used the default.

ncrbase		equ	40h		; base address of ncr 5380

; 5380 input-only and input/output registers

ncrcsd		equ	ncrbase+0	; current scsi data register
ncricr		equ	ncrbase+1	; initiator command register
ncrmr		equ	ncrbase+2	; mode register
ncrtcr		equ	ncrbase+3	; target commend register
ncrcsbs		equ	ncrbase+4	; current scsi bus status
ncrbsr		equ	ncrbase+5	; bus & status register
ncridr		equ	ncrbase+6	; input data register
ncrrpi		equ	ncrbase+7	; reset parity/interrupt

; the next addresses are also Lomas specific

ncrdack		equ	ncrbase+18h	; dack pseudo-dma
scsi_ctrl	equ	ncrbase+0Bh	; control port for an 8255
scsi_portc	equ	ncrbase+0Ah	; the SCSI ID for the LDP-HA is set by DIP
					; switches at this port of the 8255

; 5380 output-only registers

ncrodr		equ	ncrbase+0	; output data register
ncrser		equ	ncrbase+4	; select enable register
ncrsds		equ	ncrbase+5	; start dma send
ncdsdtr		equ	ncrbase+6	; start dma target receive
ncrsdir		equ	ncrbase+7	; start dma initiator receive

; flag masks for current SCSI bus status register

ncrrst		equ	10000000b
ncrbsy		equ	01000000b
ncrreq		equ	00100000b
ncrmsg		equ	00010000b
ncred		equ	00001000b
ncrio		equ	00000100b
ncrsel		equ	00000010b
ncrdbp		equ	00000001b

; flag mask for bus and status reguster

ncrphm		equ	00001000b	; phase mismatch

; flag masks for SCSI status

BUSY_STATUS	equ	08h
CHECK_STATUS	equ	02h

target_ID	equ	01h		; SCSI device 0 - NOTE this is system specific
					; the address used here will depend on the target
					; address of the controller board in your system
					
	code	segment
	assume	cs:code, ds:code, es:code, ss:stack
	
start:
main:
scsi_trial:
		mov	ax, code
		mov	ds,ax
		mov	es,ax
		call	hdinit			; this also does SCSI init
		call	scsireset
		call	zero_unit
lbusy:		call	test_ready
		mov	al,status
		test	al,BUSY_STATUS
		jnz	lbusy			; loop if busy
		test	al,CHECK_STATUS
		jz	continue
		call	req_sense		; there was an error
continue:
mbusy:		call	mode_select
		mov	al,status
		test	al,BUSY_STATUS
		jnz	mbusy			; loop if busy
		test	al,CHECK_STATUS
		jz	cont2
		call	req_sense
cont2:
fbusy:		call	format_unit
		mov	al,status
		test	al,BUSY_STATUS
		jnz	fbusy			; loop if busy
		test	al,CHECK_STATUS
		jz	cont3
		call	req_sense
cont3:
		mov	ah,4ch
		int	21h			; exit
		
hdinit:		mov	al,92h			; setup 8255 mode
		out	scsi_ctrl,al
		pause
		mov	al,55h
		out	scsi_portc,al
		
; fall through into an 5380 reset

ncrinit:	xor	ax,ax			; just reset 5280
		out	ncricr,al
		pause
		out	ncrmc,al
		pause
		out	ncrtcr,al
		pause
		out	ncrser,al
		ret
		
scsireset:	mov	ax,0000000010000000b
		out	ncricr,al
		mov	al,100			; generate long delay
rst1:		dec	ax
		jnz	rst1
		xor	ax,ax
		out	ncricr,al
delay:		mov	cx,0			; setup counter
rst2:		mov	ax,cx
		dec	cx
		jnz	rst2
		in	al,ncrrpi		; reset interrupt indicator
		ret

disbyte:	push	ax
		push	bx
		push	cx
		push	dx
		push	ax			; save byte
		mov	cl,4
		shr	al,cl			; get high nibble
		call	disnibble
		pop	ax
		and	al,0fh			; get low nibble
		call	disnibble
		mov	al,20h			; output a space between bytes
		mov	ah,2			; DOS output byte
		int	21h
		pop	dx
		pop	cx
		pop	bx
		pop	ax
		ret
		
disnibble:	add	al,30h			; change to ASCII
		cmp	al,39h
		jle	dn2			; jump if less than or equal
		add	al,7			; change hex to ASCII
dn2:		mov	ah,2			; DOS output byte
		int	21h
		ret

; if you're going to add arbitration code, it would be done before
; calling select

;*************** ENTRY POINT FOR SCSI DEVICE ACCESS ***********

select:





waitblp:



; drop through into phase

;*************** MASTER BUS PHASE PROCESSING ROUTINE ***********

phase:		xor	ax,ax
		out	ncrmr,al		; reset ncr ctrl registers
		mov	ax, offset message	; ready message pointer
		mov	message_pointer,ax
		xor	ax,ax
		out	ncrico,al
		mov	ax, offset status	; now ready status pointer
		mov	status_pointer,ax
ph1:		in	al,ncrcsbs		; check for BSY active
		test	al,ncrbsy
		jnz	ph2
		ret				; return if BSY drops out

ph2:
		test	al,ncrreq
		jz	ph1			; not valid if REQ not valid
; NOTE: text has different # of zeros
		and	ax,0000000000011100b	; get MSG, C/D, I/O
		shr	ax,1			; move it to set up for ter
		shr	ax,1
		out	ncrtcr,al
		mov	bx, offset phasetable
		add	bx,ax
		add	bx,ax			; point to correct phase
		jmp	cs:[bx]			; go do it
		
phasetable:	dw	dataout			; jump table for SCSI modes
		dw	datain
		dw	cmdout
		dw	statin
		dw	undefined
		dw	undefined
		dw	msgout
		dw	msgin

dataout:	mov	bx, offset datptr
		jmp	wscsi

datain:		mov	bx, offset datptr
		jmp	rscsi

cmdout:		mov	bx, offset cmdptr
		jmp	wscsi

statin:		mov	bx, offset status_pointer
		jmp	rscsi

msgout:		mov	bx, offset message_pointer
		jmp	wscsi

msgin:		mov	bx, offset message_pointer
		jmp	rscsi

undefined:
		ret
				
wscsi:
		push	bx			; push the address
		pop	di			; di points to address location
						; of pointer
		mov	bx,[di]			; bx points to data
wscsi1:		in	al,ncrbsr		; check for phase mismatch
		test	al,ncrphm
		jz	gotophase
		in	al,ncrcsbs		; check for busy
		test	al,ncrbsy
		jz	gotophase
		test	al,ncrreq
		jz	wscsi1			; loop until req or phase change
		mov	al,[bx]			; get the data to send
		out	ncrodr,al		; send it
		inc	bx			; increment pointer
		mov	[di],bx			; store it
		mov	al,01h
		out	ncricr,al		; assert data bus
		pause
		mov	al,00010001b		; set ack and data bus
		out	ncricr,al
		pause
waitreq:	in	al,ncrcsbs		; wait for req to go away
		test	al,ncrreq
		jnz	waitreq
		xor	ax,ax
		out	ncricr,al		; and when it does, clear ack
		

; drop through to phase

gotophase:	jmp	phase

rscsi:
		push	bx
		push	di
		mov	bx,[di]
		in	al,ncrbsr		; check for phase mismatch
		test	al,ncrphm
		jz	gotophase
		in	al,ncrcsbs		; check for busy
		test	al,ncrbsy
		jz	gotophase
		test	al,ncrreq
		jz	rscsi1			; loop until req or phase change
		in	al,ncrcsd		; get data
		mov	[bx],al			; save it
		inc	bx			; increment pointer
		mov	al,00010001b		; set ack and data bus
		out	ncricr,al
		pause
noreq:		in	al,ncrcsbs		; wait for req to go away
		test	al,ncrreq
		jnz	noreq
		xor	ax,ax
		out	ncricr,al		; and when it does, clear ack
		jmp	phase			; loop back		

test_ready:	mov	cmdptr, offset tr_cmd
		mov	datptr, offset datbuf
		call	select
		ret

zero_unit:	mov	cmdptr, offset zu_cmd
		mov	datptr, offset datbuf
		call	select
		ret

req_sense:	mov	cmdptr, offset re_cmd
		mov	datptr, offset datbuf
		call	select
		ret

; 	now add code to print out the four butes of returned data
;	this returned data contains specific information about
;	the nature of the error
		
		mov	dx, offset errormsg
		mov	ah,09h
		int	21h			; output error message
		mov	bx, offset datbuf
		mov	cx,04h			; setup counter
loopout:
		mov	al,[bx]			; get byte
		inc	bx			; increment pointer
		call	disbyte			; display bute in al as hex
		loop	loopout
		ret

format_unit:	mov	cmdptr, offset fu_cmd
		mov	datptr, offset datbuf
		call	select
		ret
		
mode_select:	mov	cmdptr, offset ms_cmd
		mov	datptr, offset datbuf
		call	select
		ret
		
target		db	target_ID		; a generalized routine would put
						; appropriate target ID here before
						; calling select

message		db	?			; actual variable locations
status		db	?

; I used the following pointers to allow me to use the same form for
; the statin, msgin, and mshout rourines as for the datain, etc. Rich
; Lehrbaum's example didn't, but that was because his routine didn't
; return to PHASE after each byte, but rather output (input) a series of
; bytes util the controller was happy

message_pointer		dw	2 dup (?)
status_pointer		dw	2 dup (?)

cmdptr			dw	2 dup (?)	; pointers to storage locations
datptr			dw	2 dup (?)

datbuf			db	512 dup (0)	; general purpose buffer

; notes on the following - 

; 	first of all, these commands are all setup for the Adaptec 4000
;	SCSI controller - while most of the commands are SCSI standard, the
;	ordering of the data for the mode select isn't, so watch yourself.

;	the logical unit zero is specified bu the three HITE bits of
;	the byte. If you want to attach two disks, you need to
;	include code to select between the different 1.u. numbers

tr_cmd			db	0		; test unit ready command
			db	0		; logical unit 0
			db	0,0,0,0		; reserved

zu_cmd			db	1		; rezero unit comma
			db	0		; logical unit 0
			db	0,0,0,0		; reserved
			
rs_cmd			db	3		; request sense command
			db	0		; logical unit 0
			db	0,0,4,0		; request four bytes of info
			
ends	code
END


