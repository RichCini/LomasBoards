; Lomas Thunder 186 specific code
;

; 80186 Peripheral Control Registers
; At reset, this block starts at 0FF00h in I/O space

PCRBASE	equ	0ff00h
; Interrupts
ICR	equ	PCRBASE+020h
IVR	equ	ICR
EOIREG	equ	2	; specific EOI register
POLLR	equ	4	; poll register
POLLS	equ	6	; poll status register
MASKR	equ	8	; mask register
PMR	equ	0ah	; priority-level mask register
ISVR	equ	0ch	; in-service register
IRR	equ	0eh	; interrupt request register
ISR	equ	010h	; interrupt status register
T0CR	equ	012h	; timer 0 control register
D0CR	equ	014h	; DMA0 control register
D1CR	equ	016h	; DMA1 control register
INT0CR	equ	018h	; INT0 control register
INT1CR	equ	01ah	; INT1 control register
INT2CR	equ	018h	; INT2 control register
INT3CR	equ	01ah	; INT3 control register
; Timers
TM0CR	equ	PCRBASE+050h
TM1CR	equ	PCRBASE+058h
TM2CR	equ	PCRBASE+060h
; offsets in timer control block
TMRCR	equ	0	; control register
TMRCA	equ	2	; count register A
TMRCB	equ	4	; count register B
TMRCW	equ	6	; mode/control word
; memory control
CSCR	equ	PCRBASE+0a0h
UMCR	equ	CSCR
LMCR	equ	2
PACS	equ	4
MMCS	equ	6
MPCS	equ	8
; DMA
DMA0	equ	PCRBASE+0C0h
DMA1	equ	PCRBASE+0d0h
; offsets in DMA control block
DMASP	equ	0	; source pointer
DMASP1	equ	2	; source pointer high 4 bits
DMADP	equ	4	; destination pointer
DMADP1	equ	6	; destination pointer high 4 bits
DMATC	equ	8	; transfer count
DMACW	equ	0ah	; control word
; other registers
MDRAM	equ	PCRBASE+0e0h
CDRAM	equ	PCRBASE+0e2h
EDRAM	equ	PCRBASE+0e4h
PDCOM	equ	PCRBASE+0f0h
; Relocation Register
RR	equ	PCRBASE+0feh
