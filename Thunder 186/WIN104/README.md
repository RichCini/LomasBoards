#Notes

The Thunder 186 and its BIOS are kind-of PC-Compatible in the way that
the Tandy 2000 was PC-Compatible. So long as software uses either MS-DOS
INT21h calls or direct BIOS calls, it should work fine. Anything else
would require writing custom hardware interfaces because device port 
addresses are at non-standard locations.

The Tandy 2000 was able to run Windows 1.04 using OEM drivers written
by Tandy (or someone contracted by Tandy). Since the Color Magic is
CGA-compatible, the other hardware items which would need custom
drivers would be for the serial and parallel ports, and the "system"
itself (which means floppy drive configuration and system timers).

No copies of the Tandy driver sources are known to exist, but the 
pre-install disk does exist. No copies of an "OEM Adaptation Kit"
are known to exist for Windows 1, but there is one for Windows 2
(which unfortunately is different enough). So, I've attempted to
back-port the published sources for COMM and SYSTEM from Windows 2.03
to something that would work for Windows 1, using a decompilation of 
the Tandy drivers as a guide.

##Status
As of now, I've back-ported SYSTEM and at least it doesn't crash. I'm
not sure if it's right, but no crashing is good.

I'm in the process of back-porting of COMM but that's much tougher
because the interrupt system in the Thunder 186 is all different
(and even different from the Tandy 2000). I'd love to locate a
"null" COMM driver and use that for now.

Windows will load and run using the "slow boot" configuration
(a special debug configuration with all of the drivers separate).
Windows 1 and 2 used a monolithic file containing all of the drivers
combined in one file to improve loading performance. The modern analog 
would be the WIN386 file in Windows 3.1 where all of the VXDs are combined.


