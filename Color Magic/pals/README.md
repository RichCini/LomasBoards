# Reading the PALs
The basis of reading the PALs is a project called DuPAL (https://github.com/DuPAL-PAL-DUmper)
which has several associated Java-based tools to read the PAL, analyze the results,
and do equation reductions. The instructions aren't as fulsome as they could be, 
so here are some notes to hopefully make it easier. Also helpful is the site
https://proghq.org/wiki/index.php/DuPAL which runs through compiling some of the Java
code.

## DuPAL board
Largely no issues getting the board manufactured. Rather than taking the existing gerbers,
I loaded the design into KiCAD and tweaked a few components and placements to fit my
liking. I moved the overlapped bypass capacitors and changed the foortprints for the
DE9M, power switch, and the coaxial power jack.

## DuPAL Firmware
The Atmel ATMega328 can be programmed in-circuit using the ISP header (for loading
the Optiboot bootloader) or out-of-circuit using any other number of methods.
I use a USBtiny programmer from Adafruit. First, download Optiboot, compile it,
and the program it into the ATMega:

  make atmega328 AVR_FREQ=20000000L LED_START_FLASHES=8 BAUD_RATE=57600

  avrdude  -c avrtiny -P /dev/ttyUSB0 -p atmega328p -e -u -U efuse:w:0xFD:m \
  -U hfuse:w:0xDE:m -U lfuse:w:0xFF:m -U flash:w:optiboot_atmega328.hex

Connect the host PC to the serial port on the DuPAL, compile and upload the firmware:

  make

  make program

## DuPAL Analyze
The different software packages require different versions of Java. Analyze uses Java 8.
Make sure that "maven" is installed: 

  sudo apt-get install maven

Then, change to the directory with the source code and compile it:

  mvn compile

  sudo mvn install

The ./target folder contains the compiled JAR file. Run that:

  java -jar ./target/dupal-analyzer-0.1.4-jar-with-dependencies.jar /dev/ttyUSB0 16L8 out.json

It will first analyze the GAL to detect the byte mask. Then, re-run with the detected mask (where "xx"
is the mask number provided):

  java -jar ./target/dupal-analyzer-0.1.4-jar-with-dependencies.jar /dev/ttyUSB0 16L8 out.json xx

## DuPAL Peeper
This program requires compiling using Java 11, so you need to switch to that before
compiling.

Using in on-line mode:

  java -jar ./target/dupal-peeper-0.0.1-jar-with-dependencies.jar --serial=/dev/ttyUSB0 --pal=16L8

Using in off-line mode:

  java -jar ./target/dupal-peeper-0.0.1-jar-with-dependencies.jar --dump=/path/to/dump.json


## DuPAL Espresso Converter
This program requires compiling using Java 11, so you need to switch to that before
compiling. I have not played with this yet, but here's the command line:

  java -jar espresso_converter.jar <input_file> <output_file> [single output table] [use only source FIOs Y|N]

  java -jar ./target/espresso-converter-0.0.3-jar-with-dependencies.jar


