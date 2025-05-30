; code: language=nasm tabSize=8
; MkExpROM <myrom.bin >myrom.rom
; 
%include "defines.inc"

int19_vec 	equ (0x19*4)		; 64h
int19_save 	equ (0x37*4)		; DCh INT37h - FP emulation
;int19_save	equ (0x2B*4)		; INT2B - DOS reserved
EPROM		equ 8192		; 8K EPROM 

; ---------------------------------------------------------------------------
section_save
; ---------------------------------------------------------------------------
section .romdata ; MARK: __ .rwdata __
; ---------------------------------------------------------------------------

option_prompt: 	db 13, 10, "BIOS Extension Test",13, 10
		db "Press S to skip...",0
option_skip: 	db "(skipping)", 13, 10, 0
option_loaded:	db "Extension loaded", 13, 10, 0

; ---------------------------------------------------------------------------
section_restore ; MARK: __ restore __
; ---------------------------------------------------------------------------

optrom_sig:	dw	0xAA55
optrom_size:	db	EPROM/512

optrom_start:	jmp	install_int19		; entry point for option ROM
dos_start:	jmp	optionrom		; entry point for loading from DOS

;
install_int19:
		pushf
		push	bx
		push	si
		push	ds

		xor	bx,bx
		mov	ds,bx			; set DS to the interrupt table
; install check
		mov	bx, (int19_save*4)
		mov	si, [int19_vec]
		cmp	si, int_19_handler	; if the interrupt vector is already set to ours, skip
		je	.done

; not installed, so trap INT19h
		cli				; no interrupts when trapping
		mov	word [bx], si		; save the original interrupt vector offset
		mov	si, [int19_vec+2]
		mov	word [bx+2], si		; save the original interrupt vector segment
		mov	word [int19_vec], int_19_handler	; set the new interrupt vector offset
		mov	word [int19_vec+2], cs			; set the new interrupt vector segment

	.done:	
		pop	ds
		pop 	si
		pop	bx
		popf				; restores interrupt state too
		retf

bios_puts:
		mov	ah, 0x0E
	.loop:
		mov	al, [cs:si]
		inc	si
		or	al, al
		jz	.done
		int	0x10
		jmp	.loop
	.done:
		ret


bios_read_input:
		mov	bx, 3 * 18 			; 3 seconds timeout
	.delay_keypress:
		sti					; Enable interrupts so timer can run
		add	bx, [0x46C]			; Add pause ticks to current timer ticks
	.delay:
		mov	ah, 01h
		int	16h				; Check for keypress
		jnz	.keypress			; End pause if key pressed

		mov	cx, [0x46C]			; Get current ticks
		sub	cx, bx				; See if pause is up yet
		jc	.delay				; Nope

	.done:
		cli					; Disable interrupts
		ret

	.keypress:
		xor	ah, ah
		int	16h				; Flush keystroke from buffer
		jmp	short .done


int_19_handler:
		; pushf
		; push	ax			; save registers
		; push	bx
		; push	cx
		; push	dx
		; push	si
		; push	ds
		; push	es

		xor	ax,ax
		mov	ds,ax			; set DS to the interrupt table

; handler installs automatically, but you have the option to not run the extension code
; here. wonder if it's better to do a trap skip in the ROM initialization rather than here?
		mov	si, option_prompt
		call	bios_puts
		call	bios_read_input
		cmp	al, 'S'
		je	skipload
		cmp	al, 's'
		je	skipload
		jmp	optionrom

skipload:
		mov	si, option_skip
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

optionrom:
		mov	si, option_loaded
		call	bios_puts
;
; this is where the option code lies. 
;
		iret

	TIMES EPROM-$+$ db 0

