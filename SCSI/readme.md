Unfortunately not a lot is known about this board from Lomas. It's a SCSI controller with two serial ports and an RTC.
Schematics are not known to exist, and I have not been able to locate a manual anywhere. The onboard ROM has been 
archived, but it contains a PAL which is more difficult to de-logic without a schematic. Using the DuPAL tool and
some manual logic texting, I think the equations posted are very close to actual, but without a working setup
(in process), it's hard to test.

The schematics, board plot, and design files are as close to actual that I can get without seeing an original
schematic. I ohmed-out the entire board, so I'm pretty confident its right, but still...

I made one component substitution which saved three chips -- I used higher-density MAX1406 level shifters rather
than the usual MC1488/MC1489. Other than that, it's all the same.

