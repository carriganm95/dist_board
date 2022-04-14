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
	input [16-1:0] coax_in_extra, output [16-1:0] coax_out_extra, input [14-1:0] io_extra, output [28-1:0] ep4ce10_io_extra,
	input [63:0] triggermask,
	input [7:0] triggernumber,
	output reg[55:0] clockCounter[8],
	output reg[7:0] triggerFired[8],
	input resetClock,
	input resetOut,
	input triggerMask,
	input syncClock,
	output reg[55:0] startTimeOut
	);

reg[7:0] i;
reg[7:0] j;
reg[31:0] histos[8][64]; // for monitoring, 8 ints for each channel
reg [64-1:0] coaxinreg; // for buffering input triggers
reg pass_prescale;
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
reg[7:0] triggeruse;
reg[7:0] lastTrigFired[8]; //when a trigger fires set this equal to the trigger number
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
reg[2:0] hitsInRow=0;
reg goodTrig[8];
reg[2:0] firstTrig;
reg firstTrigFired=0;
reg[55:0] lastClockFired;

always@(posedge clk_adc) begin
	triggeruse <= triggernumber;
	pass_prescale <= (randnum<=prescale2);
	resethist2<=resethist;
	resetClock2<=resetClock;
	resetOut2<=resetOut;
	histostosend2<=histostosend;
	prescale2<=prescale;
	triggerMask2<=triggerMask;
	syncClock2<=syncClock;
	startTimeOut<=startTime;
	//clockCounter<=clocksFired;
	//triggerFired<=lastTrigFired;
	//lastTrigFired <= ;
	isFiring <= 0;
	hitsInRow<=0;
	
	
	i=0; while (i<64) begin
		if (triggermask[i]) coaxinreg[i] <= ~coax_in[i]; // inputs are inverted (so that unconnected inputs are 0), then read into registers and buffered
		else coaxinreg[i] <= 0; // masked out inputs are set to 0 regardless of input
		if (i<8) begin
		    histosout[i]<=histos[i][histostosend2]; // histo output
			 /*if (triedtofire[i]>0 && trigSet[i]==0 && triggerMask2==0) begin
				lastTrigFired[triggerCounter][i] <= 1'b1;
				trigSet[i]<=1;
			 end
			 if (triedtofire[i]==0) trigSet[i]<=0; //reset to allow triggerFired to output this trigger again*/
		end
		if (i<16) begin // for output stuff
			coax_out[i] <= Tout[i]>0; // outputs fire while Tout is high
			//coax_out[i] <= coaxinreg[i]; // passthrough		
			if (Tout[i]>0) Tout[i] <= Tout[i]-1; // count down how long the triggers have been active
			if (triedtofire[i]>0) triedtofire[i] <= triedtofire[i]-1; // count down deadtime for outputs
		   if (triedtofire[i]>0) isFiring <=1; // don't fire any trigger within the coincidence time
		end
		i=i+1;
	end
	/*if(lastTrigFired[triggerCounter]>0 && !syncClock2) begin
	    triggerFired[triggerCounter] <= lastTrigFired[triggerCounter];
		 clockCounter[triggerCounter] <= counter;
	    triggerCounter<=triggerCounter+1;
   end*/
	
	if(coaxinreg[14] > 0) startTime<=counter;
	
	if(resetOut2 || resetClock2) begin
		i=0; while (i<8) begin
			lastTrigFired[i]<=0;
			clockCounter[i]<=0;
			triggerFired[i]<=0;
			i=i+1;
		end
		triggerCounter<=0;
	end
	
	// see how many "groups" (a set of two bars) are active in each "row" of 4 groups (for projective triggers)
	// we ask for them to be >2 so that they will disappear before the calculated "vetos" will be gone
	i=0; while (i<16) begin
	   if (i==3) begin
			Nin[i] <= (Tin[4*i]>2) + (Tin[4*i+1]>2); //special case to make sure Tin[15] is left for busy and Tin[14] is left for run signal mcarrigan
			if( (Tin[4*i]>2) + (Tin[4*i+1]>2) > hitsInRow) hitsInRow <= (Tin[4*i]>2) + (Tin[4*i+1]>2);
		end
		else begin
			Nin[i] <= (Tin[4*i]>2) + (Tin[4*i+1]>2) + (Tin[4*i+2]>2) + (Tin[4*i+3]>2);
			if ((Tin[4*i]>2) + (Tin[4*i+1]>2) + (Tin[4*i+2]>2) + (Tin[4*i+3]>2) > hitsInRow) hitsInRow <= (Tin[4*i]>2) + (Tin[4*i+1]>2) + (Tin[4*i+2]>2) + (Tin[4*i+3]>2);
		end
		if (i<4) Nactivetemp[i] <= Nin[4*i]+Nin[4*i+1]+Nin[4*i+2]+Nin[4*i+3]; // pipelined for timing closure
		if (i<4) Nactiverowstemp[i] <= (Nin[4*i]>0)+(Nin[4*i+1]>0)+(Nin[4*i+2]>0)+(Nin[4*i+3]>0); // pipelined for timing closure
		i=i+1;
	end
	Nactive <= Nactivetemp[0]+Nactivetemp[1]+Nactivetemp[2]+Nactivetemp[3]; // pipelined for timing closure
	Nactiverows <= Nactiverowstemp[0]+Nactiverowstemp[1]+Nactiverowstemp[2]+Nactiverowstemp[3]; // pipelined for timing closure
	//Note that it's important that we use "<=" here, since these will be updated at the _end_ of this always block and then ready to use in the _next_ clock cycle
	//The "vetos" in each trigger below will be calculated in _this_ clock cycle and so should be present _earlier_
	
	
	//Implement signal trigger - Antoine
	i=0; while (i<8) begin // Antoine
      Nin_coin[i] <= (Tin[i]>2)+(Tin[i+8]>2)+(Tin[i+2*8]>2)+(Tin[i+3*8]>2); // Antoine - Coincident layer if 32 first LVDS inputs are from the CAEN boards associated to the scintillator bars
	   if (((Tin[i+3*8]==0) && (Tin[i]>2) && (Tin[i+8]>2) && (Tin[i+2*8]>2)) || ((Tin[i]==0) && (Tin[i+8]>2) && (Tin[i+2*8]>2) && (Tin[i+3*8]>2))) begin; // 3 layers coincidence
		   Nin_coin_3[i]<=1;
	   end
		else begin;
		   Nin_coin_3[i]<=0;
      end
		i=i+1;
	end
	
	//Start Checking the 8 triggers
	if(isFiring == 0 && coaxinreg[15] > 0) begin
	
		// fire the outputs if there are >1 input groups active
		if (triggernumber[0]>0 && triedtofire[0]==0 && (Nactive>0)) begin
			if (pass_prescale) begin
				if(isFiring == 0) begin
					i=0; while (i<16) begin
						if (i<16) Tout[i] <= 16; // fire outputs for this long; changed output from 0,1 to 8 mcarrigan
						i=i+1;
					end
				end
				triedtofire[0] <= dead_time; // will stay dead for this many clk ticks
				isFiring<=1;
				goodTrig[0] <= 1;
				if(goodTrig[0]==0) lastTrigFired[triggerCounter][0] <= 1'b1;
			end
		end
		
				// fire the outputs if there are >1 input groups active
		if (triggernumber[1]>0 && triedtofire[1]==0 && (Nactive>1) ) begin
			if (pass_prescale) begin
				if(isFiring == 0) begin
					i=0; while (i<16) begin
						if (i<16) Tout[i] <= 16; // fire outputs for this long; changed output from 0,1 to 8 mcarrigan
						i=i+1;
					end
				end
				triedtofire[1] <= dead_time; // will stay dead for this many clk ticks
				isFiring<=1;
				goodTrig[1] <= 1;
				if(goodTrig[1]==0) lastTrigFired[triggerCounter][1] <= 1'b1;
			end
		end
		
		if (triggernumber[2]>0 && triedtofire[2]==0 && (Nactive>2) ) begin
			if (pass_prescale) begin
				if(isFiring == 0) begin
					i=0; while (i<16) begin
						if (i<16) Tout[i] <= 16; // fire outputs for this long; changed output from 0,1 to 8 mcarrigan
						i=i+1;
					end
				end
				triedtofire[2] <= dead_time; // will stay dead for this many clk ticks
				isFiring<=1;
				goodTrig[2] <= 1;
				if(goodTrig[2]==0) lastTrigFired[triggerCounter][2] <= 1'b1;
			end
		end
		
		if (triggernumber[3]>0 && triedtofire[3]==0 && (Nactive>3) ) begin
			if (pass_prescale) begin
				if(isFiring == 0) begin
					i=0; while (i<16) begin
						if (i<16) Tout[i] <= 16; // fire outputs for this long; changed output from 0,1 to 8 mcarrigan
						i=i+1;
					end
				end
				triedtofire[3] <= dead_time; // will stay dead for this many clk ticks
				isFiring<=1;
				goodTrig[3] <= 1;
				if(goodTrig[3]==0) lastTrigFired[triggerCounter][3] <= 1'b1;
			end
		end
		
	end
	
		// fire the outputs if there are >1 input groups active in any row
		/*if (triggernumber[1]>0 && triedtofire[1]==0 && (Nin[0]>3||Nin[1]>3||Nin[2]>3||Nin[3]>3||Nin[4]>3||Nin[5]>3||Nin[6]>3||Nin[7]>3||Nin[8]>3||Nin[9]>3||Nin[10]>3||Nin[11]>3||Nin[12]>3||Nin[13]>3||Nin[14]>3||Nin[15]>3) ) begin
			if (pass_prescale) begin
				if(isFiring==0) begin
					i=0; while (i<16) begin
						if (i<16) Tout[i] <= 16; // fire outputs for this long; changed output from 2,3 to 8 mcarrigan
						i=i+1;
					end
				end
				triedtofire[1] <= dead_time; // will stay dead for this many clk ticks
				isFiring<=1;
			end
		end
	end*/
	
	// fire the outputs if there are >2 input groups active in any row
	/*if (triggernumber[2]>0 && triedtofire[2]==0 && (Nin[0]>2||Nin[1]>2||Nin[2]>2||Nin[3]>2||Nin[4]>2||Nin[5]>2||Nin[6]>2||Nin[7]>2||Nin[8]>2||Nin[9]>2||Nin[10]>2||Nin[11]>2||Nin[12]>2||Nin[13]>2||Nin[14]>2||Nin[15]>2) ) begin
		if (pass_prescale) begin
			i=0; while (i<16) begin
				//if (i==4 || i==5) Tout[i] <= 16; // fire outputs for this long
				if(i<16) Tout[i] <= 16;
				i=i+1;
			end
			triedtofire[2] <= dead_time; // will stay dead for this many clk ticks
		end
	end
	
	// fire the outputs if there are >2 input groups active in any row, and just 1 row with any input groups active
	if (triggernumber[3]>0 && triedtofire[3]==0 && (Nin[0]>2||Nin[1]>2||Nin[2]>2||Nin[3]>2||Nin[4]>2||Nin[5]>2||Nin[6]>2||Nin[7]>2||Nin[8]>2||Nin[9]>2||Nin[10]>2||Nin[11]>2||Nin[12]>2||Nin[13]>2||Nin[14]>2||Nin[15]>2) 
								 && (Nactiverows<2) ) begin
		if (pass_prescale) begin
			i=0; while (i<16) begin
				if (i<16) Tout[i] <= 16; // fire outputs for this long
				i=i+1;
			end
			triedtofire[3] <= dead_time; // will stay dead for this many clk ticks
		end
	end
	
	// fire the output (8) if there are >0 input groups active (good for testing inputs)
	// added busy veto Tin[15] mcarrigan
	// replace Tin[15] by coaxinreg for more acccurate veto + add trigger number //Antoine
	if ( triggernumber[4]>0 && triedtofire[4]==0 && (Nactive>2) ) begin
		if (pass_prescale) begin
			i=0; while (i<16) begin
				if (i<16) Tout[i] <= 16; // fire outputs for this long, output to 4 coax outputs
				i=i+1;
			end
			triedtofire[4] <= dead_time; // will stay dead for this many clk ticks
			//led[1] <= 1'b0; // turn on the LED
		end
	end	
	if ( triggernumber[5]>0 && triedtofire[5]==0 && (Nactivetemp[0]>1) ) begin
		if (pass_prescale) begin
			i=0; while (i<16) begin
				if (i<16) Tout[i] <= 16; // fire outputs for this long, output to 4 coax outputs
				i=i+1;
			end
			triedtofire[5] <= dead_time; // will stay dead for this many clk ticks
			//led[1] <= 1'b0; // turn on the LED
		end
	end
	
	//Implementing coincidence triggers - Antoine
	if ( triggernumber[6]>0 && triedtofire[6]==0 && (Nin_coin[0]>3||Nin_coin[1]>3||Nin_coin[2]>3||Nin_coin[3]>3||Nin_coin[4]>3||Nin_coin[5]>3||Nin_coin[6]>3||Nin_coin[7]>3)) begin // Antoine - 4 layers coincidence 
		if (pass_prescale) begin
			i=0; while (i<16) begin
				if (i<16) Tout[i] <= 16; // fire outputs for this long, output to 4 coax outputs
				i=i+1;
			end
			triedtofire[6] <= dead_time; // will stay dead for this many clk ticks
			//led[1] <= 1'b0; // turn on the LED
		end
	end	

	if ( triggernumber[7]>0 && triedtofire[7]==0 && (Nin_coin_3[0]>0||Nin_coin_3[1]>0||Nin_coin_3[2]>0||Nin_coin_3[3]>0||Nin_coin_3[4]>0||Nin_coin_3[5]>0||Nin_coin_3[6]>0||Nin_coin_3[7]>0)) begin // Antoine - 3 layers coincidence 
		if (pass_prescale) begin
			i=0; while (i<16) begin
				if (i<16) Tout[i] <= 16; // fire outputs for this long, output to 4 coax outputs
				i=i+1;
			end
			triedtofire[7] <= dead_time; // will stay dead for this many clk ticks
			//led[1] <= 1'b0; // turn on the LED
		end
	end
	end*/

	/*if ( triggernumber[6]>0 && triedtofire[9]==0 && isFiring==0 && coaxinreg[15] > 0) begin // mcarrigan, check clock in 
		//if (pass_prescale) begin
		//clockCounter<= clockCounter + 1;
		i=0; while (i<16) begin
			if (i>3) Tout[i] <= 1; // fire outputs for this long, output to 4 coax outputs
			i=i+1;
		end
		//lastTrigFired <= 6;
		triedtofire[9] <= dead_time; // will stay dead for this many clk ticks
		led[1] <= 1'b0; // turn on the LED
	end*/
	
	//testing trigger number //Antoine
	/*if (triggernumber[1]>0 && triedtofire[6]==0 && isFiring==0 && coaxinreg[15] > 0 && (Nactive>3) ) begin
		if (pass_prescale) begin
			i=0; while (i<16) begin
				if (i<16) Tout[i] <= 16; // fire outputs for this long, output to 4 coax outputs
				i=i+1;
			end
			triedtofire[6] <= dead_time; // will stay dead for this many clk ticks
			//led[1] <= 1'b0; // turn on the LED
		end		
	end*/
	
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

	//lastTrigFired[triggerCounter][0] <= (triedtofire[0]>0 && trigSet[0]==0 &&triggerMask2) ? 1'b1 : 1'b0; 
	//lastTrigFired[triggerCounter][1] <= (triedtofire[1]>0 && trigSet[1]==0 &&triggerMask2) ? 1'b1 : 1'b0; 
	
	//lastTrigFired[triggerCounter] <= goodTrig[7] << 7 | goodTrig[6] << 6 | goodTrig[5] << 5 | goodTrig[4] << 4 | goodTrig[3] << 3 | goodTrig[2] << 2 | goodTrig[1] << 1 | goodTrig[0];

   i=0; while (i<8) begin	
		if (triedtofire[i]>0 && trigSet[i]==0 && triggerMask2==0) begin
		//if (triedtofire[i]>0 && triggerMask2==0) begin
			//lastTrigFired[triggerCounter][i] <= 1'b1;
			trigSet[i]<=1;
		end
		if (triedtofire[i]==0) trigSet[i]<=0; //reset to allow triggerFired to output this trigger again
		if(firstTrigFired==0) begin
			firstTrig<=i;
			firstTrigFired<=1;
			lastClockFired<=counter;
		end
		i=i+1;
	end
		
	if(lastTrigFired[triggerCounter]>0 && !syncClock2 && firstTrigFired==1 && triedtofire[firstTrig]==0) begin
	   triggerFired[triggerCounter] <= lastTrigFired[triggerCounter];
		clockCounter[triggerCounter] <= lastClockFired;
		triggerCounter<=triggerCounter+1;
		firstTrigFired<=0;
		i=0; while (i<8) begin
			goodTrig[i]<=0;
			i=i+1;
		end
   end
end

// triggers (from other boards) are read in and monitored
reg[5:0] Tin[64];
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
reg[51:0] counter=0;
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
