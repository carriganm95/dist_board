module LED_4(
	input nrst,
	input clk,
	output reg [3:0] led,
	input [64-1:0] coax_in,
	output [16-1:0] coax_out,	
	input [7:0] coincidence_time, input [7:0] histostosend,
	input clk_adc, output reg[31:0] histosout[8], input resethist, 
	input clk_locked,	output ext_trig_out,
	input reg[31:0] randnum, input reg[31:0] prescale, input dorolling,
	input [7:0] dead_time,
	input [16-1:0] coax_in_extra, //coax_in_extra are additional sma inputs
	output [16-1:0] coax_out_extra, //coax_out_extra are additional sma outputs
	input [14-1:0] io_extra, //io_extra are pins next to FPGA (8/16 used for clock)
	output [28-1:0] ep4ce10_io_extra, //ep4ce10_io_extra are pins below FPGA (29-32 are duplicated)
	input [63:0] triggermask,
	input [7:0] triggernumber,
	output reg[55:0] clockCounter[8],
	output reg[7:0] triggerFired[8],
	input resetClock,
	input resetOut,
	input triggerMask,
	input syncClock,
	output reg[55:0] startTimeOut,
	input [7:0] nLayerThreshold,
	input [7:0] nHitThreshold
	);

reg[7:0] i;
reg[7:0] j;
reg[31:0] histos[8][64]; // for monitoring, 8 ints for each channel
reg [64-1:0] coaxinreg; // for buffering input triggers
reg pass_prescale[8];
reg[7:0] triedtofire[16]; // for output trigger deadtime
reg[7:0] ext_trig_out_counter=0;
reg[31:0] autocounter=0; // for a rolling trigger
reg resethist2; // to pass timing
reg [7:0] histostosend2; // to pass timing, since it's sent from the slow clk
reg [31:0] prescale2; // to pass timing, since it's sent from the slow clk
reg[5:0] Tout[16]; // for output triggers
reg[2:0] Nin[64/4]; // number of groups active in each row of 4 groups
reg[4:0] Nin_coin[8]; // number of coincidence for each channel
reg[2:0] Nin_coin_3[8];
reg[6:0] Nactive;//max of 16*4=64
reg[4:0] Nactivetemp[4];//max of 4*4=16
reg[4:0] Nactiverows;//max of 16
reg[2:0] Nactiverowstemp[4];// max of 4
reg[6:0] Nlayer[4];
reg[6:0] Nbars;
reg[2:0] NLayersHit=0;
reg[7:0] triggernumber2;
reg[7:0] lastTrigFired=0; //when a trigger fires set this equal to the trigger number
reg[55:0] clocksFired[8]; //array to hold the clocks fired
reg[7:0] triggerTemp=0;
reg resetClock2;
reg resetOut2;
reg isFiring=0;
reg[2:0] triggerCounter=0; //counter for how many triggers are stored in memory
reg trigSet[8];
reg triggerMask2;
reg syncClock2;
reg[55:0] startTime=0;
reg[2:0] hitsInRow[8];
reg[2:0] maxHitsInRow=0;
reg adjacentLayersHit=0;
reg separatedLayersHit=0;
reg goodTrig[8];
reg[2:0] firstTrig;
reg firstTrigFired=0;
reg[55:0] lastClockFired;
reg[7:0] nLayerThreshold2;
reg[7:0] nHitThreshold2;
reg[55:0] counter2;
reg[7:0] dead_time2;
reg[2:0] caen_trigs=0;
reg[2:0] caen_board_trigs[6]; //buffer for caen board trigs
reg[3:0] external_trigs_buffer[2];
reg[3:0] external_trigs;
reg[31:0] randnum_buffer[8];
reg[6:0] counter125=0; //counter for 125MHz clock

always@(posedge clk_adc) begin
	triggernumber2 <= triggernumber;
	//pass_prescale <= (randnum<=prescale2);
	resethist2<=resethist;
	resetClock2<=resetClock;
	resetOut2<=resetOut;
	histostosend2<=histostosend;
	prescale2<=prescale;
	triggerMask2<=triggerMask;
	syncClock2<=syncClock;
	startTimeOut<=startTime;
	nLayerThreshold2<=nLayerThreshold;
	nHitThreshold2<=nHitThreshold;
	dead_time2<=dead_time;
		
	//set random number buffer every microsecond
	if(counter125==125) begin
		randnum_buffer[0] <= randnum;
		randnum_buffer[1] <= randnum_buffer[0]; 
		randnum_buffer[2] <= randnum_buffer[1]; 
		randnum_buffer[3] <= randnum_buffer[2]; 
		randnum_buffer[4] <= randnum_buffer[3]; 
		randnum_buffer[5] <= randnum_buffer[4]; 
		randnum_buffer[6] <= randnum_buffer[5]; 
		randnum_buffer[7] <= randnum_buffer[6]; 
		counter125<=0;
	end
	else counter125<=counter125+1;
	
	i=0; while (i<8) begin
		pass_prescale[i] <= (randnum_buffer[i]<=prescale2);
		i=i+1;
	end
	
	i=0; while (i<64) begin
		if (triggermask[i]) coaxinreg[i] <= ~coax_in[i]; // inputs are inverted (so that unconnected inputs are 0), then read into registers and buffered
		else coaxinreg[i] <= 0; // masked out inputs are set to 0 regardless of input
		if (i<8) begin
		    histosout[i]<=histos[i][histostosend2]; // histo output
		end
		if (i<16) begin // for output stuff
			coax_out[i] <= Tout[i]>0; // outputs fire while Tout is high
			//coax_out[i] <= coaxinreg[i]; // passthrough		
			if (Tout[i]>0) Tout[i] <= Tout[i]-1; // count down how long the triggers have been active
			if (triedtofire[i]>0) triedtofire[i] <= triedtofire[i]-1; // count down deadtime for outputs
		   if (triedtofire[i]>0) isFiring <=1; // don't fire any trigger within the coincidence time
			else isFiring<=0;
			/*if(i<8) begin
				clockCounter[i]<=8;
				triggerFired[i]<=8;
			end*/
			//clockCounter[0]<=counter;
			//triggerFired[0]<=lastTrigFired;
		end
		i=i+1;
	end
	
	if(coaxinreg[62] > 0) startTime<=counter;
	
	if(resetOut2 || resetClock2) begin
		i=0; while (i<8) begin
			clockCounter[i]<=0;
			triggerFired[i]<=0;
			i=i+1;
		end
		lastTrigFired<=0;
		triggerCounter<=0;
	end
	
	// see how many "groups" (a set of two bars) are active in each "row" of 4 groups (for projective triggers)
	// we ask for them to be >2 so that they will disappear before the calculated "vetos" will be gone
	i=0; while (i<8) begin
	    if(i<2) external_trigs_buffer[i] <= (TinEx[6+i*5]>2) + (TinEx[7+i*5]>2) + (TinEx[8+i*5]>2) + (TinEx[9+i*5]>2) + (TinEx[10+i*5]>2);
	    if(i<4) Nlayer[i] <= (Tin[i*8]>2) + (Tin[i*8+1]>2) + (Tin[i*8+2]>2) + (Tin[i*8+3]>2) + (Tin[i*8+4]>2) + (Tin[i*8+5]>2) + (Tin[i*8+6]>2) + (Tin[i*8+7]>2);
		 if(i<6) caen_board_trigs[i] <= (TinEx[i]>2);
		 hitsInRow[i] <= (Tin[i]>2) + (Tin[i+8]>2) + (Tin[i+16]>2) + (Tin[i+24]>2);
		 i=i+1;
	end
	
	Nbars <= Nlayer[0] + Nlayer[1] + Nlayer[2] + Nlayer[3];
	NLayersHit <= (Nlayer[0]>0) + (Nlayer[1]>0) + (Nlayer[2]>0) + (Nlayer[3]>0);
	
	maxHitsInRow <= (hitsInRow[0]>2) || (hitsInRow[1]>2) || (hitsInRow[2]>2) || (hitsInRow[3]>2) || (hitsInRow[4]>2) || (hitsInRow[5]>2) ||
							(hitsInRow[6]>2) || (hitsInRow[7]>2);
							
	separatedLayersHit <= ((Nlayer[0]>0) && (Nlayer[2]>0)) || ((Nlayer[1]>0) && (Nlayer[3]>0)); 
	adjacentLayersHit <= ((Nlayer[0]>0) && (Nlayer[1]>0)) || ((Nlayer[1]>0) && (Nlayer[2]>0)) || ((Nlayer[2]>0) && (Nlayer[3]>0));
	
	caen_trigs <= caen_board_trigs[0] + caen_board_trigs[1] + caen_board_trigs[2] + caen_board_trigs[3] + caen_board_trigs[4]; //first 6 sma inputs are reserved for CAEN board triggers
	
	external_trigs <= external_trigs_buffer[0] + external_trigs_buffer[1]; 
				
	
	//Start Checking the 8 triggers
	//if(isFiring == 0 && coaxinreg[63] > 0) begin
	
   ////////////////////////////////////	
	//List of Bar detector trigger bits
	// 1. 4LayersHit - at least one hit group in all four layers
	// 2. 3InRow - at least one hit group, int line, in each of three layers
	// 3. 2SeparatedLayers - at least one hit group in each of two non-adjacent layers
	// 4. 2AdjacentLayers - at least one hit group in each of two adjacent layers
	// 5. NLayersHit - at least one hit group in each of N layers, where N can be changed
	// 6. External - an external trigger signal from pulse generator, slab detector, or LED flashing system
	// 7. gtNHits - at least N hit groups anywhere in the detector, where N can be changed
	// 8. internalTrigger - any of the digitizers probides a trigger signal using internal logic
	/////////////////////////////////////
	
		// Trigger Bit 1: 4LayersHit
		if (triggernumber2[0]>0 && triedtofire[0]==0 && (NLayersHit>3) && coaxinreg[63]>0) begin
		//if (triggernumber2[0]>0 && triedtofire[0]==0 && (Tin[1]>0) && coaxinreg[63]>0) begin
			if (pass_prescale[0]) begin
				if(isFiring == 0) begin
					i=0; while (i<16) begin
						if (i<16) Tout[i] <= 16; // fire outputs for this long; changed output from 0,1 to 8 mcarrigan
						i=i+1;
					end
				end
				triedtofire[0] <= dead_time2; // will stay dead for this many clk ticks
				//if(goodTrig[0]==0) lastTrigFired[0] <= 1'b1;
				lastTrigFired[0] <= 1'b1;
				goodTrig[0] <= 1;
			end
		end
		
		//Trigger Bit 2: 3InRow
		if (triggernumber2[1]>0 && triedtofire[1]==0 && (maxHitsInRow>0) && coaxinreg[63]>0) begin
			if (pass_prescale[1]) begin
				if(isFiring == 0) begin
					i=0; while (i<16) begin
						if (i<16) Tout[i] <= 16; // fire outputs for this long; changed output from 0,1 to 8 mcarrigan
						i=i+1;
					end
				end
				triedtofire[1] <= dead_time2; // will stay dead for this many clk ticks
				if(goodTrig[1]==0) lastTrigFired[1] <= 1'b1;
				goodTrig[1] <= 1;
			end
		end
		
		//Trigger Bit 3: 2SeparatedLayers
		if (triggernumber2[2]>0 && triedtofire[2]==0 && (separatedLayersHit>0) && coaxinreg[63]>0) begin
			if (pass_prescale[2]) begin
				if(isFiring == 0) begin
					i=0; while (i<16) begin
						if (i<16) Tout[i] <= 16; // fire outputs for this long; changed output from 0,1 to 8 mcarrigan
						i=i+1;
					end
				end
				triedtofire[2] <= dead_time2; // will stay dead for this many clk ticks
				if(goodTrig[2]==0) lastTrigFired[2] <= 1'b1;
				goodTrig[2] <= 1;
			end
		end

		//Trigger Bit 4: 2AdjacentLayers
		if (triggernumber2[3]>0 && triedtofire[3]==0 && (adjacentLayersHit>0) && coaxinreg[63]>0) begin
			if (pass_prescale[3]) begin
				if(isFiring == 0) begin
					i=0; while (i<16) begin
						if (i<16) Tout[i] <= 16; // fire outputs for this long; changed output from 0,1 to 8 mcarrigan
						i=i+1;
					end
				end
				triedtofire[3] <= dead_time2; // will stay dead for this many clk ticks
				if(goodTrig[3]==0) lastTrigFired[3] <= 1'b1;
				goodTrig[3] <= 1;
			end
		end
		
		// Trigger Bit 5: NLayersHit
		if (triggernumber2[4]>0 && triedtofire[4]==0 && (NLayersHit>=nLayerThreshold2) && coaxinreg[63]>0) begin
			if (pass_prescale[4]) begin
				if(isFiring == 0) begin
					i=0; while (i<16) begin
						if (i<16) Tout[i] <= 16; // fire outputs for this long; changed output from 0,1 to 8 mcarrigan
						i=i+1;
					end
				end
				triedtofire[4] <= dead_time2; // will stay dead for this many clk ticks
				if(goodTrig[4]==0) lastTrigFired[4] <= 1'b1;
				goodTrig[4] <= 1;
			end
		end
		
				// Trigger Bit 6: External
		if (triggernumber2[5]>0 && triedtofire[5]==0 && (external_trigs>0) && coaxinreg[63]>0) begin
			if (pass_prescale[5]) begin
				if(isFiring == 0) begin
					i=0; while (i<16) begin
						if (i<16) Tout[i] <= 16; // fire outputs for this long; changed output from 0,1 to 8 mcarrigan
						i=i+1;
					end
				end
				triedtofire[5] <= dead_time2; // will stay dead for this many clk ticks
				if(goodTrig[5]==0) lastTrigFired[5] <= 1'b1;
				goodTrig[5] <= 1;
			end
		end
		
				// Trigger Bit 7: gtNHits
		if (triggernumber2[6]>0 && triedtofire[6]==0 && (Nbars>nHitThreshold2) && coaxinreg[63]>0) begin
			if (pass_prescale[6]) begin
				if(isFiring == 0) begin
					i=0; while (i<16) begin
						if (i<16) Tout[i] <= 16; // fire outputs for this long; changed output from 0,1 to 8 mcarrigan
						i=i+1;
					end
				end
				triedtofire[6] <= dead_time2; // will stay dead for this many clk ticks
				if(goodTrig[6]==0) lastTrigFired[6] <= 1'b1;
				goodTrig[6] <= 1;
			end
		end
		
				// Trigger Bit 8: Internal
		if (triggernumber2[7]>0 && triedtofire[7]==0 && (caen_trigs>0) && coaxinreg[63]>0) begin
			if (pass_prescale[7]) begin
				if(isFiring == 0) begin
					i=0; while (i<16) begin
						if (i<16) Tout[i] <= 16; // fire outputs for this long; changed output from 0,1 to 8 mcarrigan
						i=i+1;
					end
				end
				triedtofire[7] <= dead_time2; // will stay dead for this many clk ticks
				if(goodTrig[7]==0) lastTrigFired[7] <= 1'b1;
				goodTrig[7] <= 1;
			end
		end
			
		// if any trigger has fired start forming the trigger bitstring
   i=0; while (i<8) begin	
		if (firstTrigFired==0 && triedtofire[i]>0) begin
			firstTrig<=i;
			firstTrigFired<=1;
			lastClockFired<=counter;
			break; // added apr 28
		end
		i=i+1;
	end
	
	// if first trigger to fire has finished dead time then add trigger bitstring to triggerFired list
	if(lastTrigFired > 0 && !syncClock2 && !resetOut2 && firstTrigFired==1 && triedtofire[firstTrig]==0) begin
	   triggerFired[triggerCounter] <= lastTrigFired;
		clockCounter[triggerCounter] <= lastClockFired;
		triggerCounter<=triggerCounter+1;
		firstTrigFired<=0;
		lastTrigFired <= 0;
		i=0; while (i<8) begin
			goodTrig[i]<=0;
			i=i+1;
		end
   end
	

	//rolling trigger (about 119.21 Hz)
	if (autocounter[20]) begin
		if (dorolling) ext_trig_out_counter <= 4;
		autocounter <= 0;
	end
	else begin
		if (ext_trig_out_counter>0) ext_trig_out_counter <= ext_trig_out_counter - 1;
		autocounter <= autocounter+1;
	end
	
	if (led[0]==1'b1) led[1]<=1'b1; // turn it off when the other led toggles, so we can see it turn back on
	
end

// triggers (from other boards) are read in and monitored
reg[5:0] Tin[64]; // 64 LVDS input buffers
reg[5:0] TinEx[16]; //16 SMA input buffers
always @(posedge clk_adc) begin	
	j=0; while (j<64) begin
		
		// buffer inputs
		if (coaxinreg[j]) begin
				Tin[j] <= coincidence_time; // set Tin high for this channel for this many clk ticks
				if (!resethist2) histos[0][j] <= histos[0][j]+1; // record the trigger for monitoring in histo 0 for each input channel
		end
		else begin				
			if (Tin[j]>0) Tin[j] <= Tin[j]-1; // count down how long the triggers have been active
		end		
		
		//buffer inputs from 16 extra sma inputs
		if(j<16) begin
			if(coax_in_extra[j]) begin
				TinEx[j] <= coincidence_time;
			end
			else begin
				if(TinEx[j]>0) TinEx[j] <= TinEx[j]-1;
			end
		end
		
		j=j+1;
	end
	
	// reset histos
	if (resethist2) begin
		i=0; while (i<8) begin
			histos[i][histostosend2] <= 0;
			i=i+1;
		end
	end
	
end


//for LEDs
reg[55:0] counter=0;
always@(posedge clk) begin
	if (ext_trig_out) begin
		if(!resetClock2) counter<=counter+1;
		if(resetClock2) counter<=0;
	end
	led[0]<=counter[26]; // flashing
	led[2]<=dorolling;
	led[3]<=clk_locked;
	ext_trig_out <= !ext_trig_out;

end

	
endmodule
