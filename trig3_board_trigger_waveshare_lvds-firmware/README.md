# How to use FPGA external trigger board
A presentation of the board https://docs.google.com/document/d/1Cnhbys9y_xluXMDHmtWa7gQtES-UBxd38em_gtRzGQk/edit

1) Installation and Compilation
 
Install the Git directory https://github.com/drandyhaas/dist_board/tree/master/trig3_board_trigger_waveshare_lvds-firmware
git clone -b master https://github.com/drandyhaas/dist_board.git
Install Quartus (lite version >18) and the Cyclone IV device support
Open the file coincidence.qpf with quartus (./bin/quartus) in trig3_board_trigger_waveshare_lvds-firmware
Then you can compile the code.

2) Talk to the board

Install pySerial

sudo python3 -m pip install pyserial

Then you can go to the python file serial_talk.py in the trigger firmware to the see the info that will be printed-out. You need 
to modify the Serial first argument so that it corresponds to the USB connected to the board. On linux you can find it in ../dev/, 
and is something like /dev/ttyUSB0 (You may need to give it permissions). To talk with the board:

sudo python3 serial_talk.py

3) Modify the code and compilation

The way the user can interact with the board can be changed in serialprocessor.v (open it through Quartus).
The very logic of the trigger can be modified in LED_4.v

If you make any change, you need to compile the code. There is two possibilities to do that.
The first one is a simple compilation to you can do with quartus (press start after opening the coincidence.qpf).
When doing so the compilation may fail due to permission issue with the USB flasher (especially on Linux). If this is the case 

follow some tutorials on USB Blaster not working like https://wiki.archlinux.org/title/Intel_Quartus_Prime . Also you may need to 
plug/unplug the USB (on the computer and/or on the board).



If you want the compilation to be permanent:
In Quartus go to File, Convert Programming Files and then Generate.
Then go to Tools, Programmer, make sure that the Hardware Setup is correctly set-up to USB-Blaster.
Cross "Enable real-time ISP to allow background programming when available".
Then delete the previous file, and Add File and chose the new output.jic file.
Cross "Program/Configure" and then "Strart" to proceed with.

N.B: You may need to try and retry while plug/unplunging the USB.

