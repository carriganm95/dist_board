// clock.v

// Generated using ACDS version 13.0sp1 232 at 2018.11.08.09:14:22

`timescale 1 ps / 1 ps
module clock (
		input  wire  clk_clk,                              //                            clk.clk
		output wire  clk_0_clk_reset_reset_n,              //                clk_0_clk_reset.reset_n
		input  wire  reset_reset_n,                        //                          reset.reset_n
		input  wire  altpll_0_inclk_interface_reset_reset, // altpll_0_inclk_interface_reset.reset
		output wire  altpll_0_c0_clk                       //                    altpll_0_c0.clk
	);

	clock_altpll_0 altpll_0 (
		.clk       (clk_clk),                              //       inclk_interface.clk
		.reset     (altpll_0_inclk_interface_reset_reset), // inclk_interface_reset.reset
		.read      (),                                     //             pll_slave.read
		.write     (),                                     //                      .write
		.address   (),                                     //                      .address
		.readdata  (),                                     //                      .readdata
		.writedata (),                                     //                      .writedata
		.c0        (altpll_0_c0_clk),                      //                    c0.clk
		.areset    (),                                     //        areset_conduit.export
		.locked    (),                                     //        locked_conduit.export
		.phasedone ()                                      //     phasedone_conduit.export
	);

	assign clk_0_clk_reset_reset_n = reset_reset_n;

endmodule