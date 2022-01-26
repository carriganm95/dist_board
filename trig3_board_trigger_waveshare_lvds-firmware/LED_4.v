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
	output reg[55:0] clockCounter,
	output reg[7:0] triggerFired
	//input resetClock
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
reg[7:0] lastTrigFired=0; //when a trigger fires set this equal to the trigger number
reg[7:0] triggerTemp=0;
//reg resetClock2;

always@(posedge clk_adc) begin
	triggeruse <= triggernumber;
	pass_prescale <= (randnum<=prescale2);
	resethist2<=resethist;
	//resetClock2<=resetClock;
	histostosend2<=histostosend;
	prescale2<=prescale;
	clockCounter<=counter;
	triggerFired<=lastTrigFired;
	//lastTrigFired <= 0;
	i=0; while (i<64) begin
		if (triggermask[i]) coaxinreg[i] <= ~coax_in[i]; // inputs are inverted (so that unconnected inputs are 0), then read into registers and buffered
		else coaxinreg[i] <= 0; // masked out inputs are set to 0 regardless of input
		if (i<8) histosout[i]<=histos[i][histostosend2]; // histo output
		if (i<16) begin // for output stuff
			coax_out[i] <= Tout[i]>0; // outputs fire while Tout is high
			//coax_out[i] <= coaxinreg[i]; // passthrough		
			if (Tout[i]>0) Tout[i] <= Tout[i]-1; // count down how long the triggers have been active
			if (triedtofire[i]>0) triedtofire[i] <= triedtofire[i]-1; // count down deadtime for outputs
		end
		i=i+1;
	end
	
	// see how many "groups" (a set of two bars) are active in each "row" of 4 groups (for projective triggers)
	// we ask for them to be >2 so that they will disappear before the calculated "vetos" will be gone
	i=0; while (i<16) begin
	   if (i==3) Nin[i] <= (Tin[4*i]>2) + (Tin[4*i+1]>2) + (Tin[4*i+2]>2); //special case to make sure Tin[15] is left for busy mcarrigan
		else Nin[i] <= (Tin[4*i]>2) + (Tin[4*i+1]>2) + (Tin[4*i+2]>2) + (Tin[4*i+3]>2);
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
	
	// fire the outputs (0 and 1) if there are >1 input groups active
	if (triggernumber==3 && triedtofire[0]==0 && (Nactive>1) ) begin
		if (pass_prescale) begin
			i=0; while (i<16) begin
				if (i==8) Tout[i] <= 16; // fire outputs for this long; changed output from 0,1 to 8 mcarrigan
				i=i+1;
			end
			lastTrigFired <= 3;
			triedtofire[0] <= dead_time; // will stay dead for this many clk ticks
		end
	end
	
	// fire the outputs (2 and 3) if there are >1 input groups active in any row
	if (triggernumber==3 && triedtofire[1]==0 && (Nin[0]>1||Nin[1]>1||Nin[2]>1||Nin[3]>1||Nin[4]>1||Nin[5]>1||Nin[6]>1||Nin[7]>1||Nin[8]>1||Nin[9]>1||Nin[10]>1||Nin[11]>1||Nin[12]>1||Nin[13]>1||Nin[14]>1||Nin[15]>1) ) begin
		if (pass_prescale) begin
			i=0; while (i<16) begin
				if (i==8) Tout[i] <= 16; // fire outputs for this long; changed output from 2,3 to 8 mcarrigan
				i=i+1;
			end
			lastTrigFired <= 3;
			triedtofire[1] <= dead_time; // will stay dead for this many clk ticks
		end
	end
	
	// fire the outputs (4 and 5) if there are >2 input groups active in any row
	if (triggernumber==3 && triedtofire[2]==0 && (Nin[0]>2||Nin[1]>2||Nin[2]>2||Nin[3]>2||Nin[4]>2||Nin[5]>2||Nin[6]>2||Nin[7]>2||Nin[8]>2||Nin[9]>2||Nin[10]>2||Nin[11]>2||Nin[12]>2||Nin[13]>2||Nin[14]>2||Nin[15]>2) ) begin
		if (pass_prescale) begin
			i=0; while (i<16) begin
				if (i==4 || i==5) Tout[i] <= 16; // fire outputs for this long
				i=i+1;
			end
			triedtofire[2] <= dead_time; // will stay dead for this many clk ticks
			lastTrigFired <= 3;
		end
	end
	
	// fire the outputs (6 and 7) if there are >2 input groups active in any row, and just 1 row with any input groups active
	if (triggernumber==3 && triedtofire[3]==0 && (Nin[0]>2||Nin[1]>2||Nin[2]>2||Nin[3]>2||Nin[4]>2||Nin[5]>2||Nin[6]>2||Nin[7]>2||Nin[8]>2||Nin[9]>2||Nin[10]>2||Nin[11]>2||Nin[12]>2||Nin[13]>2||Nin[14]>2||Nin[15]>2) 
								 && (Nactiverows<2) ) begin
		if (pass_prescale) begin
			i=0; while (i<16) begin
				if (i==6 || i==7) Tout[i] <= 16; // fire outputs for this long
				i=i+1;
			end
			lastTrigFired <= 3;
			triedtofire[3] <= dead_time; // will stay dead for this many clk ticks
		end
	end
	
	// fire the output (8) if there are >0 input groups active (good for testing inputs)
	// added busy veto Tin[15] mcarrigan
	// replace Tin[15] by coaxinreg for more acccurate veto + add trigger number //Antoine
	if ( triggernumber==2 && triedtofire[4]==0 && coaxinreg[15] > 0 && (Nactive>1) ) begin
		if (pass_prescale) begin
			i=0; while (i<16) begin
				if (i<3) Tout[i] <= 16; // fire outputs for this long, output to 4 coax outputs
				i=i+1;
			end
			lastTrigFired <= 2;
			triedtofire[4] <= dead_time; // will stay dead for this many clk ticks
			led[1] <= 1'b0; // turn on the LED
		end
	end	
	if ( triggernumber==2 && triedtofire[5]==0 && coaxinreg[15] > 0 && (Nactivetemp[0]>1) ) begin
		if (pass_prescale) begin
			i=0; while (i<16) begin
				if (i==3) Tout[i] <= 16; // fire outputs for this long, output to 4 coax outputs
				i=i+1;
			end
			lastTrigFired <= 2;
			triedtofire[5] <= dead_time; // will stay dead for this many clk ticks
			led[1] <= 1'b0; // turn on the LED
		end
	end
		//testing trigger number //Antoine
	if (triggernumber==1 && triedtofire[6]==0 && coaxinreg[15] > 0 && (Nactive>0) ) begin
		if (pass_prescale) begin
			i=0; while (i<16) begin
				if (i<4) Tout[i] <= 16; // fire outputs for this long, output to 4 coax outputs
				i=i+1;
			end
			lastTrigFired <= 1;
			triedtofire[6] <= dead_time; // will stay dead for this many clk ticks
			led[1] <= 1'b0; // turn on the LED
		end		
	end
	
	//Implementing coincidence triggers - Antoine
	if ( triggernumber==4 && triedtofire[7]==0 && coaxinreg[15] > 0 && (Nin_coin[0]>3||Nin_coin[1]>3||Nin_coin[2]>3||Nin_coin[3]>3||Nin_coin[4]>3||Nin_coin[5]>3||Nin_coin[6]>3||Nin_coin[7]>3)) begin // Antoine - 4 layers coincidence 
		if (pass_prescale) begin
			i=0; while (i<16) begin
				if (i<3) Tout[i] <= 16; // fire outputs for this long, output to 4 coax outputs
				i=i+1;
			end
			lastTrigFired <= 4;
			triedtofire[7] <= dead_time; // will stay dead for this many clk ticks
			led[1] <= 1'b0; // turn on the LED
		end
	end	

	if ( triggernumber==5 && triedtofire[8]==0 && coaxinreg[15] > 0  && (Nin_coin_3[0]>0||Nin_coin_3[1]>0||Nin_coin_3[2]>0||Nin_coin_3[3]>0||Nin_coin_3[4]>0||Nin_coin_3[5]>0||Nin_coin_3[6]>0||Nin_coin_3[7]>0)) begin // Antoine - 3 layers coincidence 
		if (pass_prescale) begin
			i=0; while (i<16) begin
				if (i<3) Tout[i] <= 16; // fire outputs for this long, output to 4 coax outputs
				i=i+1;
			end
			lastTrigFired <= 5;
			triedtofire[8] <= dead_time; // will stay dead for this many clk ticks
			led[1] <= 1'b0; // turn on the LED
		end
	end	

	if ( triggernumber==6 && triedtofire[9]==0 && coaxinreg[15] > 0) begin // mcarrigan, check clock in 
		//if (pass_prescale) begin
		//clockCounter<= clockCounter + 1;
		i=0; while (i<16) begin
			if (i==3) Tout[i] <= 1; // fire outputs for this long, output to 4 coax outputs
			i=i+1;
		end
		lastTrigFired <= 6;
		triedtofire[9] <= dead_time; // will stay dead for this many clk ticks
		led[1] <= 1'b0; // turn on the LED
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
	
	/*if(resetClock2) begin
		clockCounter <= 0;
	end*/
	
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
		counter<=counter+1;
	end
	led[0]<=counter[26]; // flashing
	led[2]<=dorolling;
	led[3]<=clk_locked;
	ext_trig_out <= !ext_trig_out;

end

	
endmodule
