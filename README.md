# LomasBoards
Small repository of files/data related to Lomas Data Products S-100 boards. I have
a particular interest in the Color Magic video board as it seems to have been
supported by the Seattle Gazelle that I own. The board of course is pretty rare,
so I'm redrawing it in KiCAD 6 to hopefully reproduce the board.

## Status
The PALs have been fully decoded and tested in the original board (and they work
fine). The board layout has been compared to the original and any corrections have
been made (like positioning/orientation of jumpers, etc.).

The first run of the board was deffective (ground/Vcc ties), so a second run was
made. This version had some issues with jumper orientation, but it does not work
in the intended test system (a Thunder 186 and ColorMagic two-board configuration).
Several sample boards were sent out to other intrepid builders to see if there's
something I may have missed after hand-comparing the schematics again.

