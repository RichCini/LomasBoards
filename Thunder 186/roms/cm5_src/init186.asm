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
;    	db	0A0h,0FFh, 38h,0FEh
;	db	0A2h,0FFh, 0F8h, 3Fh
;	db	0A4h,0FFh, 3Ah, 00h
;    	db	0A6h,0FFh, 38h, 40h
;	db	0A8h,0FFh, 38h,0A0h
;	db	52h,0FFh, 06h, 00h
;	db	54h,0FFh, 07h, 00h
;	db	56h,0FFh, 03h,0C0h
;	db	5Ah,0FFh, 06h, 00h
;    	db	5Ch,0FFh, 07h, 00h
;	db	5Eh,0FFh, 03h,0C0h
;	db	62h,0FFh, 20h, 4Eh
;   	db	66h,0FFh, 01h,0C0h
    	dw	CSCR+UMCR, 0FE38h		; Upper memory: 8k block @ FE000h
						; to allow for a larger ROM...
						; 16k @ FC000h: 0FC38h
						; 32k @ F8000h: 0F838h 
	dw	CSCR+LMCR, 3FF8h		; Lower memory: 256k block @ 0-3FFFFh
	dw	CSCR+PACS, 003Ah		; 2 wait states @ 0
    	dw	CSCR+MMCS, 4038h		; Middle block start @ 40000h, 0WS with RDY
	dw	CSCR+MPCS, 0A038h		; 256k total block, 64k selects, 0WS with RDY
	dw	TM0CR+TMRCA, 0006h
	dw	TM0CR+TMRCB, 0007h
	dw	TM0CR+TMRCW, 0C003h
	dw	TM1CR+TMRCA, 0006h
    	dw	TM1CR+TMRCB, 0007h
	dw	TM1CR+TMRCW, 0C003h
	dw	TM2CR+TMRCA, 4E20h
   	dw	TM2CR+TMRCW, 0C001h
	db	0,0

; Initialization table 2. DMA registers for DMA 1 and 2
inittbl2:
 	db	82h, 00h		; DMA1
	db	82h, 00h
	db	82h, 00h
	db	82h, 40h
	db	82h, 0CEh
	db	82h, 37h
	db	0C2h, 00h		; DMA2
	db	0C2h, 00h
	db	0C2h, 00h
	db	0C2h, 40h
	db	0C2h, 0CEh
	db	0C2h, 37h
	db	0D6h, 82h
	db	0D4h, 0Fh
	db	0,0
; should end at 1C7C
;
; END OF INIT186.ASM
