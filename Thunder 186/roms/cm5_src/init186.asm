; CPU 186 defined in CM5.ASM
; 1C00h
COLDST:
	mov	ax,cs
	mov	ds,ax
	mov	es,ax
	mov	si,offset inittbl	;1c29h
	cld
loc_309:				;  xref A.1C13
 	lodsw				; String [si] to ax
 	test	ax,ax
 	jz	loc_310			; Jump if zero
 	mov	dx,ax
 	lodsw				; String [si] to ax
 	out	dx,ax			; port 4552h ??I/O Non-standard
 	jmp	short loc_309		; (1C0A)
; work on second table
;1c15
loc_310:				;  xref A.1C0D
 	mov	si,offset inittbl2	; (A.1C5F=82h)
 	mov	dx,0
loc_311:				;  xref A.1C24
 	lodsb				; String [si] to al
 	test	al,al
 	jz	loc_312			; Jump if zero
 	mov	dl,al
 	lodsb				; String [si] to al
 	out	dx,al			; port 82h, DMA page reg ch 3
 	jmp	short loc_311		; (1C1B)

loc_312:				;  xref A.1C1E
 	jmp	COLD2			;loc_2	;*(001F)

;a.1c29
; Initialization table. First word is the port and
; second word is the value.
inittbl:
    	db	0A0h,0FFh, 38h,0FEh
	db	0A2h,0FFh, 0F8h, 3Fh
	db	0A4h,0FFh, 3Ah, 00h
     	db	0A6h,0FFh, 38h, 40h
	db	0A8h,0FFh, 38h,0A0h
	db	52h,0FFh, 06h, 00h
	db	54h,0FFh, 07h, 00h
	db	56h,0FFh, 03h,0C0h
	db	5Ah,0FFh, 06h, 00h
     	db	5Ch,0FFh, 07h, 00h
	db	5Eh,0FFh, 03h,0C0h
	db	62h,0FFh, 20h, 4Eh
    	db	66h,0FFh, 01h,0C0h
	db	00h, 00h

; Initialization table 2. Ports?
inittbl2:
 	db	82h, 00h, 82h, 00h, 82h, 00h, 82h
     	db	 40h, 82h,0CEh, 82h, 37h,0C2h
     	db	 00h,0C2h, 00h,0C2h, 00h,0C2h
     	db	 40h,0C2h,0CEh,0C2h, 37h,0D6h
 	db	 82h,0D4h, 0Fh
;
; END OF INIT186.ASM
