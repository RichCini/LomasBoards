;*************************************************************
;-------------- S100Computers IDE BOARD PORT ASSIGNMENTS  (30-34H)

;Ports for 8255 chip. Change these to specify where the 8255 is addressed,
;and which of the 8255's ports are connected to which IDE signals.
;The first three control which 8255 ports have the IDE control signals,
;upper and lower data bytes.  The forth one is for mode setting for the
;8255 to configure its ports, which must correspond to the way that
;the first three lines define which ports are connected.

IDEBase		equ	030H		; base address of the board
;IDEBase		equ	210h		; 210h is the PC expansion unit address which
					; is unlikely to be used in an emulation but requires
					; rewriting much of the code to use word I/O output.
;IDEBase			equ	090h	; 90h is a PS2 control port so unlikely used on an AT
IDEportA	EQU	IDEBase		;lower 8 bits of IDE interface
IDEportB	EQU	IDEBase+1	;upper 8 bits of IDE interface
IDEportC	EQU	IDEBase+2	;control lines for IDE interface
IDECtrlPort	EQU	IDEBase+3	;8255 configuration port
IDEDrivePort	EQU	IDEBase+4	;To select the 1st or 2nd CF card/drive

IDE_Reset_Delay	EQU	020H		;Time delay for reset/initilization (~66 uS, with 8MHz 8086, 1 I/O wait state)

READcfg8255	EQU	10010010b	;Set 8255 IDEportC out, IDEportA/B input
WRITEcfg8255	EQU	10000000b	;Set all three 8255 ports output

;IDE control lines for use with IDEportC.  

IDEa0line	EQU	01H		;direct from 8255 to IDE interface
IDEa1line	EQU	02H		;direct from 8255 to IDE interface
IDEa2line	EQU	04H		;direct from 8255 to IDE interface
IDEcs0line	EQU	08H		;inverter between 8255 and IDE interface
IDEcs1line	EQU	10H		;inverter between 8255 and IDE interface
IDEwrline	EQU	20H		;inverter between 8255 and IDE interface
IDErdline	EQU	40H		;inverter between 8255 and IDE interface
IDErstline	EQU	80H		;inverter between 8255 and IDE interface
;
;Symbolic constants for the IDE Drive registers, this makes the
;code more readable than always specifying the address pins

REGdata		EQU	IDEcs0line
REGerr		EQU	IDEcs0line + IDEa0line
REGseccnt	EQU	IDEcs0line + IDEa1line
REGsector	EQU	IDEcs0line + IDEa1line + IDEa0line
REGcylinderLSB	EQU	IDEcs0line + IDEa2line
REGcylinderMSB	EQU	IDEcs0line + IDEa2line + IDEa0line
REGshd		EQU	IDEcs0line + IDEa2line + IDEa1line	;(0EH)
REGcommand	EQU	IDEcs0line + IDEa2line + IDEa1line + IDEa0line	;(0FH)
REGstatus	EQU	IDEcs0line + IDEa2line + IDEa1line + IDEa0line
REGcontrol	EQU	IDEcs1line + IDEa2line + IDEa1line
REGastatus	EQU	IDEcs1line + IDEa2line + IDEa1line + IDEa0line

;IDE Command Constants.  These should never change.

COMMANDrecal	EQU	10H
COMMANDread	EQU	20H
COMMANDwrite	EQU	30H
COMMANDinit	EQU	91H
COMMANDid	EQU	0ECH
COMMANDspindown EQU	0E0H
COMMANDspinup	EQU	0E1H
;
; IDE Status Register:
;  bit 7: Busy	1=busy, 0=not busy
;  bit 6: Ready 1=ready for command, 0=not ready yet
;  bit 5: DF	1=fault occured on the IDE drive
;  bit 4: DSC	1=seek complete
;  bit 3: DRQ	1=data request ready, 0=not ready to xfer yet
;  bit 2: CORR	1=correctable error occured
;  bit 1: IDX	vendor specific
;  bit 0: ERR	1=error occured

MAXSEC		EQU	3DH		;Sectors per track for CF my Memory drive, Kingston CF 8G. (CPM format, 0-3CH)
					;translates to LBA format of 1 to 3D sectors, for a total of 61 sectors/track.
					;This CF card actully has 3F sectors/track. Will use 3D for my CPM86 system because
					;my Seagate drive has 3D sectors/track. Don't want different CPM86.SYS files around
					;so this program will also work with a Seagate 6531 IDE drive
DOS_MAXSEC	EQU	3FH		;For MS-DOS BIOS Setting "Hard Disk" to Custom type (CF Card, 63 Sectors/track)
DOS_MAXHEADS	EQU	10H		;16 head(s)
DOS_MAXCYL_L	EQU	0FFH		;Low Byte maximum cylinder (sent via INT 13H's in CH)
DOS_MAXCYL	EQU	1024		;Max cylinders
DOS_MAXSEC_CYL	EQU	0FFH		;3FH, maximum sector number (bits 5-0)+ two Cyl High Bits (Sectors numbered 1....x)
