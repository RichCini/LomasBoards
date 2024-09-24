# LomasBoards
Small repository of files/data related to Lomas Data Products S-100 boards. I have
a particular interest in the Color Magic video board as it seems to have been
supported by the Seattle Gazelle that I own. The board of course is pretty rare,
so I'm redrawing it in KiCAD 6 to hopefully reproduce the board.

## Color Magic Redux 
### Status - version 1.1-004 WORKING
The PALs have been fully decoded and tested in the original board (and they work
fine). 

The first run of the board was defective (bad ground/Vcc), so a second run was
made. This second version had some issues with jumper orientation, and several
other small errors that had been discovered through a net-by-net continuity check
against the original board. A third run was made (v004; no v003), which works
fine. 

### Board Notes - version 1.1-004
There are 4 tie points (TP2 - TP5) that need to be connected to either VCC 
(TP3 - TP5) or the /BW (TP2) signal as applicable. If another board run is
done, these will be permanently connected to their respective points.

The speaker connection is like the PC -- simple 4-8 ohm speaker.

The keyboard is a standard PC 5150 type. If you want to use a PS/2-style 
keyboard, you need to use an AT2XT keyboard converter. I got mine on eBay
and it has both PS/2 and AT inputs and an XT (DIN-5) output. J3 is the
keyboard interface connector. You will need to build a small dongle cable 
with a DIN-5F on one end and a 1x5 0.1" pin header connector on the other.
The AT2XT adapter would then connect to this cable. The PC keyboard pinout
is available on the Internet.

Regarding video, the output is standard RGBI/CGA in addition to B&W composite. 
The RGBI interface cable is a standard 2x5 IDC to a DE9M. To use with a modern
HDMI monitor, you need to use an RGB2HDMI adapter like the one from TexElec
(https://texelec.com/product/rgbtohdmi-ttl/?highlight=hdmi). This one works
very well and can be used for more than just this setup.

Regarding memory devices, the design seems to be very sensitive to device speeds
(i.e. EPROM and SRAM). The character generator EPROM is a D2732A which is a 250ns
device. The original SRAM are stacked 6264-15 (150ns) chips which I replaced with
62256-10 (100ns) devices with some adjustments to the circuit. I temporarily used
55ns chips, and those resulted in screen artifacts. PAL device speeds are either
7ns or 15ns depending on the device.

I have a single MS-DOS 3.1 disk image which is posted. MS-DOS 2.1 disks are also 
in the archive but I haven't tried them. I use a standard Gotek interface with the
images converted to the HFE format. The disk is a standard 360k IBM-PC format.
