`timescale 1ns / 1ps

module top
(
	input clk,
	output [4:0]x,
	input [14:0]y,
	output xa,
	input [10:0]ya,
	output led0,
	output led1,
	output tx,

	output [7:0]d,
	output rd,
	output wr,
	output rs,
	output cs,
	output rst,
	input rx,
	output dtr
);
	uart_keyboard uart_keyboard_inst(
		.clk(clk),
		.x(x),
		.y(y),
		.xa(xa),
		.ya(ya),
		.led0(led0),
		.led1(led1),
		.tx(tx)
	);
	lcd_terminal lcd_terminal_isnt(
		.clk(clk),
		.d(d),
		.rd(rd),
		.wr(wr),
		.rs(rs),
		.cs(cs),
		.rst(rst),
		.rx(rx)
	);
endmodule
