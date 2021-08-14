`timescale 1ns / 1ps

module blinky_test
(
	input clk_40m,
	input [1:0]jpr,
	output reg [1:0]led
);
	reg [31:0]cnt;
	always @ (posedge clk_40m) begin
		cnt <= cnt + 1;
		case (jpr)
			2'b00: led <= cnt[24:23];
			2'b01: led <= cnt[22:21];
			2'b10: led <= cnt[20:19];
			2'b11: led <= 2'b11;
		endcase
	end
endmodule
