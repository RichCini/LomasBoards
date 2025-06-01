; This is based on the option ROM loader code from the XTRamTest project by
; David Giller & Adrian Black (https://github.com/ki3v/xtramtest)
; (file: \inc\option_rom.asm)
;
; code: language=nasm tabSize=8
;
; ASSEMBLE: nasm optrom.asm -o optrom.bin -l optrom.lst
;
; In order to make the option ROM pass muster with the BIOS loader, it
; requires a valid checksum byte in the last byte of the ROM. I used
; MkExpRom (https://github.com/Raffzahn/MakeExpROM) to do this. The output
; file is a valid ROM file. MakeExpRom needs to be compiled with MASM.
;
; USAGE: MkExpROM <optrom.bin >optrom.rom
;
; TESTING: this ROM code has been tested in the MartyPC emulator
; (https://github.com/dbalsom/martypc) which gives great flexibility in which
; ROM sets are loaded into the emulation.
; 
%include "defines.inc"

int19_vec 	equ (0x19*4)		; 64h
int19_save 	equ (0x37*4)		; DCh INT37h - FP emulation
;int19_save	equ (0x2B*4)		; INT2B - DOS reserved
EPROM		equ 8192		; 8K EPROM 

; ---------------------------------------------------------------------------
; Header: This is the expansion ROM header.
; ---------------------------------------------------------------------------
optrom_sig:	dw	0xAA55			; magic number
optrom_size:	db	EPROM/512		; ROM size in 512-byte chunks
optrom_start:	jmp	install_int19		; entry point for option ROM
		db	"EXPANSION ROM TEST FOR LOMAS T186 SYSTEM "

; ---------------------------------------------------------------------------
; Initialization: This code installs the INT19h handler. It checks for a prior
;   installation of our code from a cold boot so that if a warm boot occurs
;   it won't install another handler. Although the INT19h vector is 
;   automatically trapped at IPL, the user is given the option to skip the
;   installation of any other parts of the code. Not sure if this is the best
;   approach at this point, but will leave it for now.
;
install_int19:
		pushf
		push	bx
		push	si
		push	ds			; save key entry regs

		xor	bx,bx
		mov	ds,bx			; set DS to the interrupt table
; install check
		mov	bx,(int19_save*4)	; get old vector address offset for below
		mov	si,[int19_vec]		; get offset of installed vector
		cmp	si,int_19_handler	; is it ours? If so, skip installation
		je	.done

; INT19h does not point to our code, so we haven't loaded yet.
		cli				; no interrupts when changing vectors
		mov	word [bx],si		; save the original interrupt vector offset
		mov	si, [int19_vec+2]
		mov	word [bx+2],si		; save the original interrupt vector segment
		mov	word [int19_vec],int_19_handler		; set the new interrupt vector offset
		mov	word [int19_vec+2],cs			; set the new interrupt vector segment

	.done:	
		pop	ds			; clean up stack and exit
		pop 	si
		pop	bx
		popf				; restores interrupt state too
		retf


; ---------------------------------------------------------------------------
; BIOS_puts:	simple string print using INT10h
; ---------------------------------------------------------------------------
bios_puts:	
		mov	ah, 0x0E		; TTY out
	.loop:
		mov	al,[cs:si]
		inc	si
		or	al,al
		jz	.done
		int	10h
		jmp	.loop
	.done:
		ret


; ---------------------------------------------------------------------------
; BIOS_read_input:	simple keyboard input using INT16h
;   46c is ticks_today_lo
;   maybe need to add STC to allow "no press" testing.
; ---------------------------------------------------------------------------
bios_read_input:
		mov	bx, 3 * 18 		; 3 seconds timeout
	.delay_keypress:
		sti				; Enable interrupts so timer can run
		add	bx,[0x46C]		; Add pause ticks to current timer ticks
	.delay:
		mov	ah,01h
		int	16h			; Check for keypress
		jnz	.keypress		; End pause if key pressed

		mov	cx,[0x46C]		; Get current ticks
		sub	cx,bx			; See if pause is up yet
		jc	.delay			; Nope

	.done:
		cli				; Disable interrupts
		ret

	.keypress:
		xor	ah,ah
		int	16h			; Flush keystroke from buffer
		jmp	short .done


; ---------------------------------------------------------------------------
; INT19H Handler:	This is the handler registered by the initialization
;   routine above.
; ---------------------------------------------------------------------------
int_19_handler:
		; pushf
		; push	ax			; save registers
		; push	bx
		; push	cx
		; push	dx
		; push	si
		; push	ds
		; push	es

		xor	ax,ax			; set DS to the interrupt table
		mov	ds,ax			; used only if trapping other vectors

; Handler installs automatically, but you have the option to not run the extension code
; here. Wonder if it's better to remove the skip option or follow this approach?
; There's a 3-second timeout for hitting a key.
		mov	si,option_prompt	; let people know we're alive
		call	bios_puts
		call	bios_read_input		; get a key from the keyboard
		cmp	al,'S'			; s=skip, any other key loads
		je	skipload
		cmp	al,'s'
		je	skipload
		jmp	loadcode		; OK to load/run the other code

skipload:
		mov	si,option_skip
		call	bios_puts
		; pop 	es
		; pop	ds
		; pop 	si
		; pop	dx
		; pop	cx
		; pop	bx
		; pop	ax
		; popf
		int	int19_save		; chain to old INT19h
		iret


; ---------------------------------------------------------------------------
; loadcode:	This is the core of the code. The INT19h reboot trap is
;   installed and if the user doesn't bypass the installation of the
;   remaining code, execution winds-up here.
; ---------------------------------------------------------------------------
loadcode:

; put the other code here.

loadok:
		mov	si,option_loaded	; let everyone know we're here
		jmp	optexit

loaderr:
		mov	si,option_exit	
; falls through to the exit routine
optexit:
		call	bios_puts
		int	int19_save		; chain to old INT19h
		iret


; ---------------------------------------------------------------------------
; Static Data:	Messages and static data.
; ---------------------------------------------------------------------------
option_prompt: 	db 13, 10, "BIOS Extension Test",13, 10
		db "Press S to skip...",0
option_skip: 	db "(skipping)", 13, 10, 0
option_loaded:	db "Extension loaded", 13, 10, 0
option_exit:	db "Aborting loading", 13, 10, 0

; ---------------------------------------------------------------------------
; End-of-ROM:	Pad the binary image to the size of the EPROM so that
;   MkExpRom can place the checksum byte at the end.
; ---------------------------------------------------------------------------
;	TIMES EPROM-$+$ db 0
	TIMES EPROM-($-$$)-11 DB 0
dt:	db __DATE__		; Assembled date (YYYY-MM-DD)
;	TIMES EPROM-($-$$) DB 0
	db  0
	

