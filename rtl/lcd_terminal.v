`timescale 1ns / 1ps

module lcd_terminal
(
	input clk,
	output [7:0]d,
	output rd,
	output wr,
	output rs,
	output cs,
	output rst
	//input rx
);
	//assign rst = !(state == RST);
	assign rst = 1;
	assign rd = 1;
	assign rs = !(state == SEND_C);
	assign cs = !(state == SEND_C | state == SEND_D);
	assign wr = !(state == SEND_C & cnt == 0); // 
	assign d = !rs ? command : param;

	reg [1:0]clk_reg = 0;
	always @ (posedge clk) begin
		clk_reg <= clk_reg + 1;
	end
	wire clk_en = clk_reg[1];

	reg [15:0]cnt = 0;

	localparam RST = 0;
	localparam INIT = 1;
	localparam IDLE = 2;
	localparam SEND_C = 3;
	localparam SEND_D = 4;
	reg [3:0]state = RST;
	reg [3:0]state_ret;

	reg [7:0]command;
	reg [7:0]param_num;
	wire [7:0]param;

	always @ (posedge clk) begin if (clk_en) begin
		case (state)
			RST: begin
				if (cnt > 500) begin
					cnt <= 0;
					state <= INIT;
				end else
					cnt <= cnt + 1;
			end
			INIT: begin
				state <= SEND_C;
				command <= 8'h29;
				param_num <= 0;
				state_ret <= IDLE;
				cnt <= 0;
			end
			IDLE: begin
			end
			SEND_C: begin
				if (cnt == 1) begin
					cnt <= 0;
					if (param_num == 0) state <= state_ret;
					else state <= SEND_D;
				end else 
					cnt <= cnt + 1;
			end
			SEND_D: begin
			end
		endcase
	end end

endmodule
