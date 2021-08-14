`timescale 1ns / 1ps

module io_test
(
	output reg [114:0]io_all
);
	wire [1:0]outbit = 2'b01;
	always @ (*) begin
		io_all = {58{outbit}};
		io_all[56] = io_all[55];
	end
endmodule
