# LomasBoards
Small repository of files/data related to Lomas Data Products S-100 boards. I have
a particular interest in the Color Magic video board as it seems to have been
supported by the Seattle Gazelle that I own. 

## Color Magic Redux 
<img src="https://raw.githubusercontent.com/RichCini/LomasBoards/master/Color%20Magic/Finished%20Board.JPG?sanitize=true&raw=true"/>

### Status - version 1.1-005 / Version 006 In Development
1.1-005 is the release version, although in the process of debugging CGA Mode 6
(used for Windows 1.04 and Sim City) I discovered that the RAM chip selects are
improperly connected to MA13. It is OK to run the board without the following change if
only text or low-resolution modes are used.

To make the correction on existing 1.1-005 boards, it requires lifting pin 20
of each SRAM (CS*) and connecting it to ground, and lifting pin 26 (A13) and
connecting to MA13 (pin 20 of the socket). I did this with some 30AWG wire-
wrapping wire soldered to the tops of the pins in question.

There is also a revised versions of the U18 and U55 PALs that's recommended for all users.
Again, the update to U18 is related to discoveries made in debugging Mode 6, while the
update to U55 is related to a discovery by Patrick Linstruth that the MS-DOS RTC was
running fast. The 8253 timer was not being initialized properly due to a missing term
in one of the equations.


### Board Notes
Regarding CGA Mode 6, with the above change, it now works, although it shows a
screen artifact, the same as the original board. In this mode, there is a vertical
black stripe along the left side of the screen image which would indicate there's
a timing issue in the horizontal blanking (i.e., video out is being enabled 
one-half character time too early, before the load/shift from the character generator
is ready for the first set of dots, and then disabled the same half-character early
at the end of the video line.) As this exists in the original board, its a mode that
may have not been tested because so few software packages at the time used that mode.

The 5V voltage regulator is a TO-3 switching replacement from EzSBC. To preserve the
footprint and schematic symbol, it's shown as an LM7805K.

The speaker connection is like the PC -- simple 4-8 ohm speaker.

The keyboard is a standard PC 5150 type. If you want to use a PS/2-style 
keyboard, you need to use an AT2XT keyboard converter. I got mine on eBay
and it has both PS/2 and AT inputs and an XT (DIN-5) output. J3 is the
keyboard interface connector. You will need to build a small dongle cable 
with a DIN-5F on one end and a 1x5 0.1" pin header connector on the other.
The AT2XT adapter would then connect to this cable. The PC keyboard pinout
is available on the Internet.

Regarding video, the output is standard RGBI/CGA in addition to B&W composite. 
The RGBI interface cable is a standard 2x5 IDC to a DE9F. To use with a modern
HDMI monitor, you need to use an RGB2HDMI adapter like the one from TexElec
(https://texelec.com/product/rgbtohdmi-ttl/?highlight=hdmi). This one works
very well and can be used for more than just this setup.

Regarding memory devices, the design seems to be very sensitive to device speeds
(i.e. EPROM and SRAM). The character generator EPROM is a D2732A which is a 250ns
device. The original SRAM are stacked 6264-15 (150ns) chips which I replaced with
62256-10 (100ns) devices with some adjustments to the circuit. I temporarily used
55ns chips, and those resulted in screen artifacts. PAL device speeds are either
7ns or 15ns depending on the device.


## Thunder 186 Redux 
<img src="https://raw.githubusercontent.com/RichCini/LomasBoards/master/Thunder%20186/Thunder186_final.jpg?sanitize=true&raw=true"/>

### Status - version 1.0-006 FINAL
Three minor changes: the serial headers were changed back to the 2x10 used on the prototype
(which then requires using a DB25F cable), consistent with the original; corrected the
footprint on C9 to a polarized tantalum; final change was to rotate the CPU 180 degrees
to have the chip legend oriented properly.

As with the ColorMagic, the 5V voltage regulator is a TO-3 switching replacement from EzSBC. 
To preserve the footprint and schematic symbol, it's shown as an LM7805K.


### Board Notes
The serial section seems to be sensivite to the voltage levels used on the interface of the
peripherals connected to it. This became evident when trying the old Move-IT file transfer
program. My go-to serial-USB dongle wasn't driving the handshaking lines to conforming
voltages. After changing USB interfaces, it worked. Original interfaces, like on a DOS
laptop I keep around for such purposes, work fine.

Regarding DOS versions, I run PC/DOS rather than MS-DOS. Versions 3.0, 3.1, and 3.3 work.
I have a single 360k MS-DOS 3.1 disk image which is posted. MS-DOS 2.1 disks are 
also in the archive, but appear to rely on direct calls into the monitor in order to
boot (non-standard MS-DOS boot sector) and are 320k in size (8 sectors).

The I/O ports (serial and parallel) are at non-standard, non-PC-compatible addresses, so
any software that uses them either has to (1) allow for defining custom ports, (2) read
the BIOS data area in order to get the right port number, or (3) rely solely on BIOS
calls to access the hardware. 

Similar to the serial port, the parallel port seems sensitive to what it's connected
to. I used LPT-Capture (https://github.com/bkw777/LPT_Capture) which works with an old
DOS laptop but will not work with this parallel port. I have gotten it working using a
Practical Peripherals Serial/Parallel converter/buffer. Although I haven't tested it,
it's possible the LPT-Capture would work on that port.

In the process of debugging Mode 6 video (mentioned above) some users reported that depending
on the S-100 backplane used, a pull-up resistor might be needed on PRDY (pin 72). There is a note
on the schematic about this, but the original design did not include one. RN2 pin 8 (1.0k 
resistor array) can be connected to pin 72 (on the rear) of the S-100 edge connector with a piece
of wirewrap wire.

### Status - version 1.0-005 Working
Works! PC-DOS 3 reports 256k of RAM which is correct. 

There is one errata. Capacitor C9 in the reset circuit should be 22uF/16v polarized; it
is misdrawn on the original schematic. A regular tantalum fits fine in this space. The
original board uses a 10v tantalum.

## LomasSCSI 

### Status --
The board is about 85% redrawn in KiCAD. Since no printed schematics are known to exist, this is
being done by the "continuity tester" method -- ohming out every connection on the board. Slow
going at best.

The board contains one PAL, a 20L10, used as an address decoder. The PAL has been reversed and the
equations tested against the original by burning another PAL, but without a working test setup for
the original board, confirming that the equations are 100% correct will be difficult. From probing,
I do believe that they are correct, though. So, more to come on this.








