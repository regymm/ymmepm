## YMMEPM

#### CPLD Dev Board & Handheld Serial Terminal

Board with Altera MAX II EPM1270/EPM570/EPM240 TQFP100/TQFP144. With a pluggable 480x320 LCD screen and a matrix keyboard, it work well as a handheld serial terminal. 

**Gallery**

![](pic/rendered.jpg)

**The terminal**

Due to the scares resource of the EPM1270, the terminal supports only basic cursor movement. VT100(`^[[X`) sequences are detected and ignored. Have to put character pixel lists into slow UFM, so only up to 19200 baud rate. In case of Linux, bash and commands like `ls` work. `nano` won't display correctly and the editor that works is `ed`. 

**Design**

Simple is the main concern ... or not?

Single 3V3, or single 5V0 with ASM1117 to 3V3. 

Right two PMODs directly connected to CPLD. Left 2 PMODs share the Arduino pins(these literally give the plugged LCD screen a PMOD interface). Spare IOs scattered here and there. 

1 power LED, 2 user LEDs, 2 user jumpers. 2 oscillators. A strange matrix keyboard. 

For the simplest verification, only the CPLD, power pins, and JTAG pins are needed. Even caps on the back can be left empty. 

**Bugs**

5V is not connected to the Arduino pin. Fly a wire from ASM1117 if using 5V LCD screen. 

JTAG header pins should be soldered on back of the board. 

