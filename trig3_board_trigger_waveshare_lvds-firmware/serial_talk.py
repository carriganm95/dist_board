from serial import Serial
from struct import unpack
import time
import random

class bcolors:
    HEADER = '\033[95m'
    OKBLUE = '\033[94m'
    OKCYAN = '\033[96m'
    OKGREEN = '\033[92m'
    WARNING = '\033[93m'
    FAIL = '\033[91m'
    ENDC = '\033[0m'
    BOLD = '\033[1m'
    UNDERLINE = '\033[4m'

ser=Serial("/dev/ttyUSB0",921600,timeout=1.0)

ser.write(bytearray([0])) # firmware version
result = ser.read(1); byte_array = unpack('%dB' % len(result), result); print("firmware v",byte_array[0])

time.sleep(.5)

def setrngseed():
    random.seed()
    b1 = random.randint(0, 255)
    b2 = random.randint(0, 255)
    b3 = random.randint(0, 255)
    b4 = random.randint(0, 255)
    ser.write(bytearray([6, b1, b2, b3, b4]))
    print("set trigboard random seed to", b1, b2, b3, b4)

def set_inputmask(m1,m2,m3,m4,m5,m6,m7,m8): # input mask for each set of 8 inputs (0-7,8-15,...)
    # ff would be unmasked, 0 would be masked
    m1 = int(m1,base=16)
    m2 = int(m2, base=16)
    m3 = int(m3, base=16)
    m4 = int(m4, base=16)
    m5 = int(m5, base=16)
    m6 = int(m6, base=16)
    m7 = int(m7, base=16)
    m8 = int(m8, base=16)
    ser.write(bytearray([14,m1,m2,m3,m4,m5,m6,m7,m8]))
    print("set input mask to",hex(m1),hex(m2),hex(m3),hex(m4),hex(m5),hex(m6),hex(m7),hex(m8))

def set_prescale(prescale):  # takes a float from 0-1 that is the fraction of events to pass
    if prescale > 1.0 or prescale < 0.0:
        print("bad prescale value,", prescale)
        return
    prescaleint = int((pow(2, 32) - 1) * prescale)
    b4 = int(prescaleint / 256 / 256 / 256) % 256
    b3 = int(prescaleint / 256 / 256) % 256
    b2 = int(prescaleint / 256) % 256
    b1 = int(prescaleint) % 256
    ser.write(bytearray([7, b1, b2, b3, b4]))
    print("set trigboard prescale to", prescale, " - will pass", prescaleint, "out of every 4294967295", ", bytes:", b1, b2, b3, b4)

def get_histos(h):
    ser.write(bytearray([2, h]))  # set histos to be from channel h
    ser.write(bytearray([10]))  # get histos
    res = ser.read(32)
    b = unpack('%dB' % len(res), res)
    if(h==14): print("*************testing***********", b)
    mystr = "histos for "
    mystr+=str(h)
    mystr+=": "
    myint = []
    for i in range(8):
        myint.append(b[4 * i + 0] + 256 * b[4 * i + 1] + 256 * 256 * b[4 * i + 2] + 0 * 256 * 256 * 256 * b[4 * i + 3])
        mystr += str(myint[i]) + " "
        if i == 3: mystr += ", "
    return mystr, myint
    
def set_trigger(tn8,tn7,tn6,tn5,tn4,tn3,tn2,tn1): # put value 1 for each trigger you want to use (0 means not use), begin is trigger number 8
    tn_b=str(tn8*pow(10, 7)+tn7*pow(10, 6)+tn6*pow(10, 5)+tn5*pow(10, 4)+tn4*pow(10, 3)+tn3*pow(10, 2)+tn2*pow(10, 1)+tn1*pow(10, 0))
    tn=int(tn_b, base=2)
    ser.write(bytearray([15,tn]))
    print("set the trigger to number", tn, "from the menu")
#enter the combination of all the triggers wanted ie if want to use trigger 2,3 and 7 enter 732
# trigger 1-3 are for testing purposes; 1 should give ~0 event, 3 is for testing the default FPGA code
# trigger 4 corresponds to 4 layers coincidence which is the signal trigger
# trigger 5 correspond to 3 layers coincidence



setrngseed()
set_prescale(0.3)

set_inputmask("ff","ff","00","00","00","00","00","00") # use just the first 16 inputs

set_trigger(0,0,1,0,0,0,1,1)

#read what the clock source is
ser.write(bytearray([8]))
result = ser.read(1); byte_array = unpack('%dB' % len(result), result); print("clock source",byte_array[0])

#change the dead time
ser.write(bytearray([11, 1]))

#set input coincidence time
ser.write(bytearray([1,20]))

#read number of clock cycles since start (work in progress)
ser.write(bytearray([2,15]))
ser.write(bytearray([16]))
result = ser.read(8)
print("result", len(result), result)
r0 = bin(result[3] << 24)
r1 = bin(result[2] << 16)
r2 = bin(result[1] << 8)
r3 = bin(result[0])
result = result[3] << 24 | result[2] << 16 | result[1] << 8 | result[0]
print(bcolors.OKBLUE, r0, r1, r2, r3, result, bcolors.ENDC)
#byte_array = unpack('%dB' % len(result), result)
byte_array = result
print("clock cycles",byte_array)

print("Turning on/off trigger enable")
ser.write(bytearray([3]))

for his in range(64):
    histostr, histo = get_histos(his)
    if histo[0]>0: print(histostr)

ser.close()
