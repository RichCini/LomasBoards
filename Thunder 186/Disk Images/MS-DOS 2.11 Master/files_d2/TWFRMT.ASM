page	80,120

WFRMT	SEGMENT
ASSUME	CS:WFRMT,DS:WFRMT,ES:WFRMT

;Generalized version of winchester formatter. This version may be patched
;with either DDT86(CP/M86) or DEBUG(MS-DOS), to format any type of winchester 
;drive. 

false		equ	0
true		equ	not false

;Set the following equate to true if it is desired to only check for bad
;sectors on the winchester drive

mapper_flag	equ	false

;Set the following equate to true if this is to be used with THUNDER 186

THUNDER		equ	true 

;Set one of the following equates to true corresponding to the type of
;drive this formatter is to format.

QTM2010		equ	false		;QUANTUM 2010 10 mbyte 8"
QTM2020		equ	false		;QUANTUM 2020 20 mybte 8"
QTM2040		equ	true 		;QUANTUM 2040 40 mbyte 8"
QTM520		equ	false		;QUANTUM 520 20 mbyte 5 1/4"
QTM540		equ	false		;QUANTUM 540 40 mbyte 5 1/4"
SA1004		equ	false		;SHUGART SA1004 10 mbyte 8"
SA712		equ	false		;SHUGART SA712 10 mbyte 5 1/4"

		if	THUNDER
DISK		EQU	10H
		endif
		if	not THUNDER
DISK		EQU	90H
		endif
WRITE_CMND	EQU	30H
SDH		EQU	DISK+6
DOS		EQU	033		;224 FOR CPM, 33 FOR MSDOS
DOSREG		EQU	AH		;CL FOR CPM, AH FOR MSDOS
CR		EQU	13
LF		EQU	10
FRMT_CMND	EQU	50H
RESTORE		EQU	18H
seek		equ	70h 
READ_CMND	EQU	20H

DELAY	MACRO
	PUSH	BX
	POP	BX
ENDM

	ORG	100H
START:
	JMP	SHORT SKIP
;The following vaviables should be changed using either DDT86 of DEBUG
;depending upon which operating system this program is being modified
;for. NUM_HEADS is the number of heads the drive to be formatted has. This
;may be in the range of 1 to 8. The variable MAPPER if set to 0FFh will
;cause the program to only check for bad sectors on the drive. After
;checking for bad sectors the user will be prompted asking wether the new
;error status should be saved. If you decide to answer 'Y', the system should
;be reset and rebooted after saving the status. The CYLINDERS variable sets
;the number of cylinders the drive has. This may range from 1 to 1024.
;The INTERLEAVE_8 variable if set to 0FFH will use an interleave factor of
;8 on the hard disk, if set to 0 the interleave factor will be 4.
;Experimentation has shown an interleave factor of 8 is the best for
;performance. You may want to experiment.
;
;Use of DEBUG or DDT86 is explained in the corresponding operating system
;doccumentation. This program is supplied to dealers and OEM's for their
;use only. There is no support for this program from LDP beyond this listing
;
		if	QTM2010
hds		equ	2
trks		equ	512
		endif
		if	QTM2020 or QTM520
hds		equ	4
trks		equ	512
		endif
		if	QTM2040 or QTM540
hds		equ	8
trks		equ	512
		endif
		if	SA1004
hds		equ	4
trks		equ	256
		endif
		if	SA712
hds		equ	4
trks		equ	320
		endif

NUM_HEADS	DB	hds		;THIS SHOULD COINCIDE TO THE NUMBER OF
					;HEADS ON THE DRIVE YOU ARE USING
MAPPER		DB	mapper_flag    	;IF 0 THEN FORMATS AND CHECKS, IF 0
					;ONLY CHECKS DRIVE
CYLINDERS	dw	trks 		;NUMBER OF TRACKS BEING USED
INTERLEAVE_8	db	0FFH		;IF 0FFH THEN USE 8 INTERLEAVE FACTOR

SKIP:
	MOV	DI,OFFSET ERR_BUF
	MOV	CX,256
	MOV	AL,0
	REP	STOSB
	MOV	ERRORS,0		;ZERO ERROR COUNT
	MOV	DX,OFFSET SIGNON
	test	mapper,0ffh
	jz	start2
	mov	dx,offset signon1
start2:
	CALL	PMSG
	MOV	AL,NUM_HEADS
	MOV	HEADS,AL		;SAVE NUMBER OF HEADS
	MOV	DX,OFFSET SURE_MSG
	test	mapper,0ffh
	jz	start1
	mov	dx,offset sure_msg1	;not whole message if mapper
start1:
	CALL	PMSG
	CALL	GETCHAR
	CMP	AL,'Y'
	JNE	EXIT
	CALL	NEWLINE
	MOV	AL,80H		;SET PRECOMP REG FOR PRECOMP AT 256
	DELAY
	OUT	DISK+1,AL
	MOV	AL,seek		;HOME THE DRIVE TO SET STEP RATE AND
	DELAY
	OUT	DISK+7,AL	;INITIALIZE THE DRIVE
	MOV	TRACK,0		;FIRST TRACK TO FORMAT IS 0
	CALL	WAIT_DONE	;WAIT FOR THE DRIVE TO COMPLETE
	MOV	CX,CYLINDERS	;NUMBER OF TRACKS 
FRMT_LOOP:
	test	mapper,0ffh	;if mapper dont format and write
	jnz	frmt_loop1
	CALL	FRMT_TRACK	;FORMAT ONE TRACK ALL HEADS
	CALL	FILL_TRACK	;PUT ALL E5'S IN ALL SECTORS
frmt_loop1:
	CALL	CHECK_TRACK	;CHECK FOR ANY BAD SECTORS
	INC	TRACK		;NEXT TRACK TO FORMAT
	test	mapper,0ffh
	jnz	frmt_loop2
	PUSH	AX
	MOV	AL,07H		;BELL CHARACTER
	CALL	PUT_CHAR
	POP	AX
frmt_loop2:
	LOOP	FRMT_LOOP	;DO UNTIL ALL TRACKS FORMATED
	test	mapper,0ffh
	jz	frmt_loop3
	MOV	DX,OFFSET SAVE_MSG
	CALL	PMSG
	CALL	GETCHAR
	PUSH	AX
	CALL	NEWLINE
	POP	AX
	CMP	AL,'Y'
	JNE	DONE
frmt_loop3:
	CALL	WRITE_ERR_DATA	;NOT PUT THE ERROR INFO ON THE DRIVE
DONE:
	MOV	DX,OFFSET DONE_MSG ; TELL USER ALL DONE WITH FORMATING
	CALL	PMSG
EXIT:
	MOV	DL,0
	MOV	DOSREG,0	;EXIT CODE
	INT	DOS		;RETURN TO CLI

SAVE_MSG	EQU	$
	DB	'Save the new error status?(Y/N) $'

SURE_MSG	EQU	$
	DB 'Formating will destroy all files currently on the drive.',cr,lf 
sure_msg1	equ $
	db	'Do you wish to continue(Y/N)? $'

FRMT_TRACK:
	MOV	AX,TRACK
	OUT	DISK+4,AL
	MOV	AL,AH
	DELAY
	OUT	DISK+5,AL	;SET TRACK IN WD1000
	PUSH	CX		;SAVE OLD LOOP COUNT
	MOV	CL,HEADS		;GET NEW LOOP COUNT
	MOV	CH,0
	MOV	HEAD,0
FT_LOOP:
	MOV	AL,HEAD		;GET HEAD PRESENTLY FORMATING
	DELAY
	OUT	SDH,AL
	MOV	AL,32		;NUMBER OF SECTORS TO FORMAT
	DELAY
	OUT	DISK+2,AL
	MOV	AL,FRMT_CMND
	DELAY
	OUT	DISK+7,AL
	CALL	OUTPUT_FRMT_TBL
	PUSH	CX
	MOV	CX,256-64
	MOV	AL,0
PAD_LOOP:
	OUT	DISK+0,AL
	LOOP	PAD_LOOP
	POP	CX
	CALL	WAIT_DONE	;WAIT FOR FORMAT TO COMPLETE
	INC	HEAD		;DO NEXT HEAD
	LOOP	FT_LOOP		;DO UNTIL ALL HEAD DONE
	POP	CX		;RESTORE LOOP COUNT
	RET

CHECK_TRACK:
	MOV	AX,TRACK
	OUT	DISK+4,AL
	MOV	AL,AH
	DELAY
	OUT	DISK+5,AL
	PUSH	CX
	MOV	CL,HEADS	;NUMBER OF HEAD TO CHECK SECTORS ON
	MOV	CH,0
	MOV	HEAD,0		;START WITH HEAD 0
CT_LOOP:
	MOV	SECTOR,0	;AND SECTOR 0
	MOV	AL,HEAD
	OUT	SDH,AL
	PUSH	CX
	MOV	CX,32
RD_SECTOR_LOOP:
	MOV	AL,SECTOR
	DELAY
	OUT	DISK+3,AL
	MOV	AL,READ_CMND
	DELAY
	OUT	DISK+7,AL
	CALL	WAIT_DONE	;WAIT FOR READ TO COMPLETE
	TEST	AL,1		;CHECK FOR ERROR STATUS
	JZ	RSL_CONT	;IF OK NO NEED TO FLAG ERROR
	CALL	FLAG_ERROR	;PUT ERROR IN ERROR BUFFER AND REPORT 
				;IT TO THE USER
RSL_CONT:
	INC	SECTOR
	LOOP	RD_SECTOR_LOOP
	POP	CX
	INC	HEAD
	LOOP	CT_LOOP
	POP	CX
	RET

FILL_TRACK:
	MOV	AX,TRACK
	OUT	DISK+4,AL
	MOV	AL,AH
	DELAY
	OUT	DISK+5,AL
	PUSH	CX
	MOV	CL,HEADS
	MOV	CH,0
	MOV	HEAD,0
FLT_LOOP:
	MOV	SECTOR,0
	MOV	AL,HEAD
	OUT	SDH,AL
	PUSH	CX
	MOV	CX,32
WT_SECTOR_LOOP:
	MOV	AL,SECTOR
	DELAY
	OUT	DISK+3,AL
	MOV	AL,WRITE_CMND
	DELAY
	OUT	DISK+7,AL
	PUSH	CX
	MOV	CX,256
	MOV	AL,0E5H
WT_FILL_LOOP:
	OUT	DISK+0,AL
	LOOP	WT_FILL_LOOP
	POP	CX
	CALL	WAIT_DONE
	INC	SECTOR
	LOOP	WT_SECTOR_LOOP
	POP	CX
	INC	HEAD
	LOOP	FLT_LOOP
	POP	CX
	RET

FLAG_ERROR:
	MOV	AL,ERRORS
	CMP	AL,33
	JE	FLAG_ERROR_RET
	CMP	AL,32
	JE	TO_MANY_ERRORS
	INC	ERRORS
	PUSH	CX
	MOV	BX,OFFSET ERR_BUF
	MOV	DI,FRAME_PTR
	MOV	AX,TRACK
	MOV	[BX+DI],AX	;SAVE THE DEFECTIVE TRACK
	ADD	DI,2		;NEXT WORD
	MOV	AL,HEAD		;GET HEAD FOR DEFECTIVE SECTOR
	MOV	CX,5		;SHIFT IT 5 LEFT
	SHL	AL,CL
	OR	AL,SECTOR	;MAKE 8 BIT NUMBER
	MOV	AH,0
	MOV	[BX+DI],AX	;SAVE THE SECTOR HEAD INFO
	ADD	DI,2		;POINT TO THE NEXT WORD
	PUSH	AX		;SAVE SECTOR INFO
	MOV	AX,NEXT_FREE	;GET NEXT REPLACEMENT SECTOR
	MOV	[BX+DI],AX
	ADD	DI,2		;NEXT FRAME
	MOV	FRAME_PTR,DI	;SAVE NEW POINTER
	INC	NEXT_FREE	;NEXT FREE SECTOR = SECTOR+1
	MOV	DX,OFFSET SECTOR_MSG	;PRINT 'SECTOR '
	CALL	PMSG
	POP	AX
	CALL	OUTWORD		;PRINT THE SECTOR,HEAD NUMBER
	MOV	DX,OFFSET TRACK_MSG	;PRINT 'TRACK '
	CALL	PMSG
	MOV	AX,TRACK
	CALL	OUTWORD		;PRINT THE TRACK NUMBER
	CALL	NEWLINE		;CR LF
	POP	CX		;RESTORE LOOP COUNT
FLAG_ERROR_RET:
	RET

TO_MANY_ERRORS:
	MOV	DX,OFFSET TMEMSG
	CALL	PMSG
	INC	ERRORS
	RET
TMEMSG	DB	'Too many sector errors - no more will be logged',cr,lf,'$'


OUTWORD:
	PUSH	AX		;SAVE WORD
	MOV	AL,AH		;HIGH BYTE FIRST
	CALL	OUTBYTE
	POP	AX
	CALL	OUTBYTE
	RET

OUTBYTE:
	MOV	AH,AL
	AND	AL,0F0H		;SAVE HEGH NIBLE
	SHR	AL,1
	SHR	AL,1
	SHR	AL,1
	SHR	AL,1		;MAKE HIGH NIBLE, LOW NIBLE
	CALL	OUT_HEX_DIGIT
	MOV	AL,AH
	AND	AL,0FH
	CALL	OUT_HEX_DIGIT
	RET

OUT_HEX_DIGIT:
	ADD	AL,'0'
	CMP	AL,'9'
	JLE	OHD_OK
	ADD	AL,7
OHD_OK:
	CALL	PUT_CHAR
	RET

PMSG:
	PUSH	CX
	MOV	DOSREG,9
	INT	DOS
	POP	CX
	RET

GETCHAR:
	PUSH	CX
	MOV	DOSREG,1
	INT	DOS
	CMP	AL,'Z'
	JLE	GET_CHAR_RET
	CMP	AL,'z'
	JG	GET_CHAR_RET
	SUB	AL,20H		;MAKE UPPER CASE IF LOWER CASE TYPED
GET_CHAR_RET:
	POP	CX
	RET

PUT_CHAR:
	PUSH	AX
	PUSH	CX
	PUSH	DX
	MOV	DL,AL
	MOV	DOSREG,2
	INT	DOS
	POP	DX
	POP	CX
	POP	AX
	RET

NEWLINE:
	MOV	AL,CR
	CALL	PUT_CHAR
	MOV	AL,LF
	CALL	PUT_CHAR
	RET

OUTPUT_FRMT_TBL:
	PUSH	CX
	MOV	SI,OFFSET FRMT_TBL_8
	test	INTERLEAVE_8,0FFH
	JNZ	OFRMT1
	MOV	SI,OFFSET FRMT_TBL_4
OFRMT1:
	MOV	CX,64
OUTPUT_LOOP:
	LODSB
	OUT	DISK+0,AL
	LOOP	OUTPUT_LOOP
	POP	CX
	RET

WRITE_ERR_DATA:
	MOV	AL,0
	OUT	DISK+3,AL	;SECTOR,TRACK AND HEAD = 0
	DELAY
	OUT	DISK+4,AL
	DELAY
	OUT	DISK+5,AL
	DELAY
	OUT	SDH,AL
	MOV	AL,WRITE_CMND
	DELAY
	OUT	DISK+7,AL
	MOV	SI,OFFSET ERR_BUF
	MOV	CX,256
FILL_WRITE_BUFFER:
	LODSB
	OUT	DISK+0,AL
	LOOP	FILL_WRITE_BUFFER
	CALL	WAIT_DONE
	TEST	AL,01
	JNZ	WRITE_ERR
	RET
WRITE_ERR:
	MOV	DX,OFFSET WRITE_ERR_MSG
	CALL	PMSG
	RET

WAIT_DONE:
	IN	AL,DISK+7
	TEST	AL,80H
	JNZ	WAIT_DONE
	RET

HEAD	DB	0
HEADS	DB	0
TRACK	DW	0
ERRORS	DB	0
FRAME_PTR	DW	0
NEXT_FREE	DW	1
SECTOR		DB	0
SIGNON	DB	'Hard disk formatter general version Rev 1.1 9/14/84',cr,lf
	db	'Formats winchester drives connected to a LDP system'
	db	cr,lf
	db	'records and reports any sector errors. Up to 31',cr,lf
	db	'sectors may be bad and remapped. Units are shipped'
	db	cr,lf
	db	'with a maximum of 10 bad sectors.',cr,lf
	db	'Drive: '
	if	QTM2010
	db	'QTM2010'
	endif
	if	QTM2020 or QTM520
	db	'QTM2020 or QTM520'
	ENDIF
	IF	QTM2040 or QTM540 
	DB	'QTM2040 or QTM540'
	ENDIF
	IF	SA1004
	DB	'SA1004'
	ENDIF
	IF	SA712
	DB	'SA712'
	ENDIF
	db	cr,lf
	db	'$'
signon1	db	'Hard disk MAPPER general version Rev 1.00 6/22/84',cr,lf
	db	'Checks winchester drives for bad sectors and records',cr,lf
	db	'any bad sector in the error map on sector 0, track 0',cr,lf 
	db	'If more than 32 sectors are bad, remapping is not',cr,lf
	db	'possible. Try to reformat after saving all data on the drive'
	db	cr,lf
	db	'Drive: '
	if	QTM2010
	db	'QTM2010'
	endif
	if	QTM2020 or QTM520
	db	'QTM2020 or QTM520'
	ENDIF
	IF	QTM2040 or QTM540 
	DB	'QTM2040 or QTM540'
	ENDIF
	IF	SA1004
	DB	'SA1004'
	ENDIF
	IF	SA712
	DB	'SA712'
	ENDIF
	db	cr,lf
	db	'$'
WRITE_ERR_MSG	EQU	$
	db	cr,lf,'Error writting the error buffer on the drive.'
	db	cr,lf,'$'
DONE_MSG	EQU	$
	db	'Formatting operation is complete.$'
SECTOR_MSG	EQU	$
	DB	'Sector $'
TRACK_MSG	EQU	$
	DB	'  Track $'
FRMT_TBL	EQU	$
FRMT_TBL_8	EQU	$
	db	0,0,0,8,0,16,0,24,0,1,0,9,0,17,0,25
	db	0,2,0,10,0,18,0,26,0,3,0,11,0,19,0,27
	db	0,4,0,12,0,20,0,28,0,5,0,13,0,21,0,29
	db	0,6,0,14,0,22,0,30,0,7,0,15,0,23,0,31

FRMT_TBL_4	EQU	$
	db	0,0,0,4,0,8,0,12,0,16,0,20,0,24,0,28
	db	0,1,0,5,0,9,0,13,0,17,0,21,0,25,0,29
	db	0,2,0,6,0,10,0,14,0,18,0,22,0,26,0,30
	db	0,3,0,7,0,11,0,15,0,19,0,23,0,27,0,31

ERR_BUF	DB	256 DUP (0)

	DB	0

WFRMT	ENDS
	END	START
