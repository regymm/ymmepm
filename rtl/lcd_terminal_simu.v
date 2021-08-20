`timescale 1ns / 1ps

module lcd_simu();
	reg clk = 0;
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end
	lcd_terminal lcd_terminal_inst(
		.clk(clk)
	);
endmodule
