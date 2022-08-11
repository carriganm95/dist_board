module processor(clk, rxReady, rxData, txBusy, txStart, txData, readdata,
	coincidence_time, histostosend, enable_outputs, 
	phasecounterselect,phaseupdown,phasestep,scanclk, clkswitch,
	histos, resethist, activeclock,
	setseed, seed, prescale, dorolling, dead_time,
	io_top_extra, triggermask, triggernumber, clockCounter, 
	triggerFired, resetClock, resetOut, syncClock, startTime,
	nLayerThreshold, nHitThreshold
	);
	
	input clk;
	input[7:0] rxData;
	input rxReady;
	input txBusy;
	input [5-1:0] io_top_extra;
	output reg txStart;
	output reg[7:0] txData;
	output reg[7:0] readdata;//first byte we got
	output reg enable_outputs=1;//set low to enable outputs
	reg[7:0] extradata[32];//to store command extra data, like arguemnts (up to 10 bytes)
	localparam READ=0, SOLVING=1, WRITE1=3, WRITE2=4, READMORE=5, PLLCLOCK=6, CLKSWITCH=7, RESETHIST=8, RESETCLOCK=9, RESETOUT=10, SYNCCLOCK=11;
	reg[7:0] state=READ;
	reg[7:0] bytesread, byteswanted;
	
	reg[7:0] pllclock_counter=0;
	reg[7:0] scanclk_cycles=0;
	output reg[2:0] phasecounterselect; // Dynamic phase shift counter Select. 000:all 001:M 010:C0 011:C1 100:C2 101:C3 110:C4. Registered in the rising edge of scanclk.
	output reg phaseupdown=1; // Dynamic phase shift direction; 1:UP, 0:DOWN. Registered in the PLL on the rising edge of scanclk.
	output reg phasestep=0;
	output reg scanclk=0;
	output reg clkswitch=0; // No matter what, inclk0 is the default clock
		
	reg[7:0] ioCount, ioCountToSend;
	reg[7:0] data[64]; // for writing out data in WRITE1,2
	
	output reg[7:0] coincidence_time=20; // number of ticks to buffer inputs for (sets the coincidence time)
	output reg[7:0] dead_time=50; // number of ticks to be dead for after firing
	output reg[7:0] histostosend=0; // the board from which to get histos
	output reg[63:0] triggermask=64'hffffffffffffffff; // start with all bits unmasked
	output reg[7:0] triggernumber=8'b00000000; // Trigger to use //Antoine
	output reg[7:0] nLayerThreshold;
	output reg[7:0] nHitThreshold;
	input reg[55:0] clockCounter[8]; // Counter for number of triggers fired (mcarrigan)
	input reg[7:0] triggerFired[8]; // Trigger most recently fired by board (mcarrigan)
	input reg[55:0] startTime;

	
	input reg[31:0] histos[8];
	output reg resethist;
	output reg resetClock;
	output reg resetOut;
	output reg syncClock;
	input activeclock;
	reg[7:0] i;
	
	output reg setseed;
	output reg[31:0] seed = 0;
	output reg[31:0] prescale[8];// = 32'hffffffff;
	output reg dorolling=1;

	initial begin
		i=0; while(i<8) begin
			prescale[i] <= 32'hffffffff;
			i=i+1;
		end
	end
	
	always @(posedge clk) begin
	case (state)
	READ: begin		  
		txStart=0;
		bytesread=0;
		byteswanted=0;
      ioCount=0;
      resethist=0;
		setseed=0;
		resetClock=0;
		resetOut=0;
		syncClock=0;
		if (rxReady) begin
			readdata = rxData;
         state = SOLVING;
      end
	end
	READMORE: begin
		if (rxReady) begin
			extradata[bytesread] = rxData;
			bytesread = bytesread+1;
			if (bytesread>=byteswanted) state=SOLVING;
		end
	end
   SOLVING: begin
		if (readdata==0) begin		
			ioCountToSend = 1;
			data[0]=9; // this is the firmware version
			state=WRITE1;				
		end
		else if (readdata==1) begin //wait for next byte: the coincidence time
			byteswanted=1; if (bytesread<byteswanted) state=READMORE;
			else begin
				if (extradata[0]<64) coincidence_time=extradata[0];
				state=READ;
			end
		end
		else if (readdata==2) begin //wait for next byte: which histos to send out over serial when asked for histos
			byteswanted=1; if (bytesread<byteswanted) state=READMORE;
			else begin
				histostosend=extradata[0];
				state=READ;
			end
		end
		else if (readdata==3) begin //toggle output enable
			ioCountToSend = 1;
			byteswanted=1; if(bytesread<byteswanted) state=READMORE;
			else begin
				enable_outputs = ~extradata[0];
				if (enable_outputs) data[0] = 1;
				else data[0] = 0;
				//data[0] = enable_outputs;
				state=WRITE1;
			end
		end
		else if (readdata==4) begin //toggle clk inputs
			pllclock_counter=0;			
			clkswitch = 1;
			state=CLKSWITCH;
		end
		else if (readdata==5) begin //adjust clock phases
			phasecounterselect=3'b000; // all clocks - see https://www.intel.com/content/dam/www/programmable/us/en/pdfs/literature/hb/cyc3/cyc3_ciii51006.pdf table 5-10
			//phaseupdown=1'b1; // up
			scanclk=1'b0; // start low
			phasestep=1'b1; // assert!
			pllclock_counter=0;
			scanclk_cycles=0;
			state=PLLCLOCK;
		end
		else if (readdata==6) begin // set the random number seed in rng
			byteswanted=4; if (bytesread<byteswanted) state=READMORE;
			else begin
				seed={extradata[3],extradata[2],extradata[1],extradata[0]};
				setseed=1;
				state=READ;
			end
		end
		else if (readdata==7) begin // set prescale int
			byteswanted=32; if (bytesread<byteswanted) state=READMORE;
			else begin
				i=0; while(i<8) begin
					prescale[i]={extradata[3+i*4],extradata[2+i*4],extradata[1+i*4],extradata[0+i*4]};
					i=i+1;
				end
				state=READ;
			end
		end
		else if (readdata==8) begin // report what clock is active input
			ioCountToSend = 1;
			data[0]= {7'b0000000,activeclock};
			state=WRITE1;
		end
		else if (readdata==9) begin // toggle phaseupdown up (default) or down
			phaseupdown = ~phaseupdown;
			state=READ;
		end
		else if (readdata==10) begin //send out histo
			ioCountToSend = 32;
			i=0; while (i<32) begin
				data[i]=histos[i/4][8*i%32 +:8]; // selects 8 bits starting at bit 8*i%32
				i=i+1;
			end
			state=RESETHIST;
		end
		else if (readdata==11) begin //wait for next byte: the dead time
			byteswanted=1; if (bytesread<byteswanted) state=READMORE;
			else begin
				dead_time=extradata[0];
				state=READ;
			end
		end
		else if (readdata==12) begin //adjust phase of clock c1
			phasecounterselect=3'b011; // clock c1 - see https://www.intel.com/content/dam/www/programmable/us/en/pdfs/literature/hb/cyc3/cyc3_ciii51006.pdf table 5-10
			//phaseupdown=1'b1; // up
			scanclk=1'b0; // start low
			phasestep=1'b1; // assert!
			pllclock_counter=0;
			scanclk_cycles=0;
			state=PLLCLOCK;
		end
		else if (readdata==13) begin // toggle rolling of triggers
			dorolling = ~dorolling;
			state=READ;
		end
		else if (readdata==14) begin // set the input trigger mask
			byteswanted=8; if (bytesread<byteswanted) state=READMORE;
			else begin
				triggermask={extradata[7],extradata[6],extradata[5],extradata[4],extradata[3],extradata[2],extradata[1],extradata[0]};
				state=READ;
			end
		end
		else if (readdata==15) begin // select a trigger from the menu
			byteswanted=1; if (bytesread<byteswanted) state=READMORE;
			else begin							
				triggernumber=extradata[0];
				state=READ;
			end
		end
		else if (readdata==16) begin // read out number of clock cycles since start	
			ioCountToSend = 64;
			i=0; while (i<64) begin
				if (i%8 < 7) data[i]=clockCounter[i/8][8*i%64 +:8]; // selects 8 bits 
				else data[i]=triggerFired[i/8][0 +:8];
				i=i+1;
			end
			state=RESETOUT;
		end
		else if (readdata==17) begin // reset clock counter
			ioCountToSend = 1;
			state=RESETCLOCK;
		end
		else if (readdata==18) begin //sync clocks
			ioCountToSend = 7;
			i=0; while (i<7) begin
				data[i]=startTime[8*i +:8];
				i=i+1;
			end
			state=WRITE1;
		end
		else if (readdata==19) begin // get N layers hit threshold
		    byteswanted=1; if (bytesread<byteswanted) state=READMORE;
			 else begin
			     nLayerThreshold = extradata[0];
				  state=READ;
		    end
		end
		else if (readdata==20) begin // get N hits threshold
				    byteswanted=1; if (bytesread<byteswanted) state=READMORE;
			 else begin
			     nHitThreshold = extradata[0];
				  state=READ;
		    end
		end
		else state=READ; // if we got some other command, just ignore it		    
	end
	
	CLKSWITCH: begin // to switch between clock inputs, put clkswitch high for a few cycles, then back down low
		pllclock_counter=pllclock_counter+1;
		if (pllclock_counter[3]) begin
			clkswitch = 0;
			state=READ;
		end
	end
	
	PLLCLOCK: begin // to step the clock phase, you have to toggle scanclk a few times
		pllclock_counter=pllclock_counter+1;
		if (pllclock_counter[4]) begin
			scanclk = ~scanclk;
			pllclock_counter=0;
			scanclk_cycles=scanclk_cycles+1;
			if (scanclk_cycles>5) phasestep=1'b0; // deassert!
			if (scanclk_cycles>7) state=READ;
		end
	end
	RESETHIST: begin // to reset the histos
		resethist=1;
		state=WRITE1;
	end
	
	RESETCLOCK: begin // to reset clock
		resetClock=1;
		state=WRITE1;
	end
	
	RESETOUT: begin //to reset trigger and clock output arrays
	    resetOut=1;
		 state=WRITE1;
   end
	
	SYNCCLOCK: begin //to sync trigger board and caen clocks
	    syncClock=1;
		 state=WRITE1;
	end
	
	//just writng out some data bytes over serial
	WRITE1: begin
		resethist=0;
		resetClock=0;
		resetOut=0;
		syncClock=0;
		if (!txBusy) begin
			txData = data[ioCount];
         txStart = 1;
         state = WRITE2;
		end
	end
   WRITE2: begin
		txStart = 0;
      if (ioCount < ioCountToSend-1) begin
			ioCount = ioCount + 1;
         state = WRITE1;
      end
		else state = READ;
	end

	endcase
	end  
	
endmodule
