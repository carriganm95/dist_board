import time
import os
from serial import Serial
from array import array
import ROOT as r

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

start = time.time()
last_result = 0

def getClock(start, last_result, ser, tree, clockCycles, trigTime, trigFired):
	end = time.time()
	ser.write(bytearray([16]))
	result = ser.read(8)
	counter = result[6] << 48 | result[5] << 40 | result[4] << 32 | result[3] << 24 | result[2] << 16 | result[1] << 8 | result[0]
	trigger = result[7]
	print(bcolors.OKBLUE,"Clock Counter: ", counter,bcolors.ENDC, \
		bcolors.OKBLUE, "Trigger Fired: ", trigger, bcolors.ENDC, \
		bcolors.OKGREEN, "Time:", end-start, bcolors.ENDC, \
		bcolors.OKCYAN, "Clock Cycles:", (end-start)/(50e6), bcolors.ENDC, \
		bcolors.FAIL, "Diff:", counter-last_result-(end-start)*50e6, bcolors.ENDC)
	start = end
	last_result = counter
	clockCycles[0] = counter
	trigTime[0] = counter * 50e6
	trigFired[0] = trigger
	tree.Fill()
	return start, last_result


def runClock():
	start = time.time()
	last_result = 0
	for i in range(1000):
		end = time.time()
		ser.write(bytearray([16]))
		result = ser.read(8)
		counter = result[6] << 48 | result[5] << 40 | result[4] << 32 | result[3] << 24 | result[2] << 16 | result[1] << 8 | result[0]
		#print(result[7] << 56 | result[6] << 48 | result[5] << 40 | result[4] << 32 | result[3] << 24 | result[2] << 16 | result[1] << 8 | result[0])
		trigger = result[7]
		print(bcolors.OKBLUE,"Clock Counter: ", counter,bcolors.ENDC, \
			bcolors.OKBLUE, "Trigger Fired: ", trigger, bcolors.ENDC, \
			bcolors.OKGREEN, "Time:", end-start, bcolors.ENDC, \
			bcolors.OKCYAN, "Clock Cycles:", (end-start)*50e6, bcolors.ENDC, \
			bcolors.FAIL, "Diff:", counter-last_result-(end-start)*50e6, bcolors.ENDC)
		start = end
		#print(last_result)
		if(trigger > 0): print(bcolors.BOLD, "Trigger: ", trigger, bcolors.ENDC)
		last_result = counter
		




ser=Serial("/dev/ttyUSB0",921600,timeout=1)

start = time.time()
#runClock()
end = time.time()
print("Ran in ", end-start, "seconds")

run = True

myfile = r.TFile("triggerTree.root", "recreate")

myTree = r.TTree("Events", "Trigger Events")

clockCycles = array('f', [0.])
trigTime = array('f', [0.])
trigger = array('f', [0.])

myTree.Branch('clockCycles', clockCycles, 'clockCycles')
myTree.Branch('time', trigTime, 'trigTime')
myTree.Branch('trigger', trigger, 'trigger')


counter = 0
while run:
	start, last_result = getClock(start, last_result, ser, myTree, clockCycles, trigTime, trigger)
	counter += 1
	if counter > 100: run = False
	if counter == 50: 
		print(bcolors.FAIL, "RESETTING CLOCK!!!!", bcolors.ENDC)
		ser.write(bytearray([17]))
		fw = ser.read(1)
		print("got fw version", fw)
		#time.sleep(5)
myTree.Write()
myfile.Close()



