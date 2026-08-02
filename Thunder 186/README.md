# Thunder 186
Small repository of files/data related to Lomas Data Products Thunder 186 as well
as the KiCAD design files for my replica.

## Disk Images
From a Facebook purchase, I was able to obtain original MS-DOS 2.11 and
Concurrent CP/M-86 distribution disks. The MS-DOS disks were intact and
readable but they will not mount on any normal system because the format
of track 0 is unique to Lomas. Patching it to make it readable in a
normal machine makes it unusable on the T186 (you need to overwrite
sector 0 with a standard MS-DOS boot sector).

Regarding the Concurrent CP/M-86 disks, disk 1 is not readable due to a
destroyed directory. Disks 2 and 3 are fine. Pete Higgins did extract 
the files from each disk and those are posted. Online AI tools did
grind away at the image and repaired it enough, but some of the programs
need to be replaced, and it's still not bootable. Progress...

The PCDOS-winslow disk is a PC/DOS bootable image that contains
Windows 1.0 configured for no mouse and a CGA monitor. It will work
with the ColorMagic, but the user experience is bad without a mouse.

