# LomasBoards
Small repository of files/data related to Lomas Data Products S-100 boards. I have
a particular interest in the Color Magic video board as it seems to have been
supported by the Seattle Gazelle that I own. The board of course is pretty rare,
so I'm redrawing it in KiCAD 6 to hopefully reproduce the board.

## Status
The PALs have been fully decoded and tested in the original board (and they work
fine). The board layout has been compared to the original and any corrections have
been made (like positioning/orientation of jumpers, etc.).

The first run of the board was defective (bad ground/Vcc), so a second run was
made. This second version had some issues with jumper orientation, and several
other small errors had been discovered through a net-by-net continuity check
against the original board. A third run was made (v004; no v003), which does
mostly work. There is some screen corruption, so there is a lingering issue
in the dual-port memory circuit. But, the fact that it works even with screen
corruption is a significant milestone.

