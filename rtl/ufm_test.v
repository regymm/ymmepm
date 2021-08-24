`timescale 1ns / 1ps

module ufm_test
(
	output nread,
	output wire dvalid,
	output wire nbusy,
	output wire osc
);
	ufm_ip ufm_ip_inst(
		.addr(0),
		.nread(nread),
		.oscena(1),
		.data_valid(dvalid),
		.nbusy(nbusy),
		.osc(osc)
	);
	//reg [2:0]rclk = 0;
	//always @ (posedge osc) begin
		//rclk <= rclk + 1;
	//end
	//wire clk = rclk == 3'b111;
	reg [15:0]cnt = 0;
	always @ (posedge osc) begin
		cnt <= cnt + 1;
	end
	assign nread = cnt[15:0] == 16'hfff ? 0 : 1;
endmodule
