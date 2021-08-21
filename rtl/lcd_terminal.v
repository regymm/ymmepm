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
	//assign rst = 1;
	//reg [3:0]clk_reg = 0;
	//always @ (posedge clk) begin
		//clk_reg <= clk_reg + 1;
	//end
	//wire clk_div = clk_reg[3];
	//wire clk_en = (clk_reg[3:0] == 4'b0000);
	
	//wire [15:0]d_out_16;
	//LCD_Config LCD_Config_inst(
		//.clk(clk_div),
		//.rst_n(1),
		//.data_in(32'hF0F0),
		//.cs(cs),
		//.rs(rs),
		//.wr(wr),
		//.rd(rd),
		//.data_out(d_out_16)
	//);
	//assign d = d_out_16[7:0];

	//assign rst = !(state == RST);
	assign rst = 1;
	assign rd = 1;
	assign rs = !(state == SEND_C);
	////assign cs = !(state == SEND_C | state == SEND_D);
	assign cs = 0;
	assign wr = !((state == SEND_C & cnt[0] == 0) | (state == SEND_D & cnt[0] == 0 & param_num != 0)); // 
	assign d = !rs ? command : param;

	reg [3:0]clk_reg = 0;
	always @ (posedge clk) begin
		clk_reg <= clk_reg + 1;
	end
	wire clk_en = (clk_reg[3:0] == 4'b0000);

	reg [22:0]cnt = 0;

	localparam RST = 0;
	localparam DISPON = 1;
	localparam IDLE = 2;
	localparam SEND_C = 3;
	localparam SEND_D = 4;
	localparam CAS = 5;
	localparam PAS = 6;
	localparam WCHAR = 7;
	localparam SLPOUT = 8;
	localparam COLMOD = 9;
	localparam DISCTRL = 11;
	localparam MAC = 12;
	localparam CLEAR_1 = 13;
	localparam CLEAR_2 = 14;
	localparam BRIGHT = 15;
	localparam GAMMA_1 = 16;
	localparam GAMMA_2 = 17;
	localparam VOLT_1 = 18;
	localparam VOLT_2 = 19;
	reg [5:0]state = RST;
	reg [5:0]state_ret;
	reg [5:0]state_ret_stash;

	localparam SOFT_RESET = 8'h01;
	localparam SLEEP_OUT = 8'h11;
	//localparam NORM_DISP_ON = 8'h13;
	localparam DISPLAY_ON = 8'h29;
	localparam MEM_ACCESS_CTRL = 8'h36;
	localparam IF_PIXEL_FMT = 8'h3A;
	localparam DISP_FUNC_CTRL = 8'hB6;
	localparam COLUMN_A_SET = 8'h2A;
	localparam PAGE_A_SET = 8'h2B;
	localparam MEM_WRITE = 8'h2C;
	localparam WRITE_BRIGHT = 8'h51;
	//localparam DISP_INVERT = 8'h21;

	reg [7:0]command;
	reg [27:0]param_num;
	reg [7:0]param;

	reg [7:0]char = 0;
	wire curr_pixel;

	// 6x8 font terminal
	reg [6:0]charcol = 0;
	reg [5:0]charrow = 0;

	reg clearing = 0;
	wire [15:0]cas_sc = clearing ? 0 : charcol * 6;
	wire [15:0]cas_ec = clearing ? 479 : charcol * 6 + 5;
	wire [15:0]pas_sp = clearing ? 0 : charrow * 8;
	wire [15:0]pas_ep = clearing ? 319 : charrow * 8 + 7;
	//wire [15:0]cas_sc = 0;
	//wire [15:0]cas_ec = 16'h13f;
	//wire [15:0]pas_sp = 0;
	//wire [15:0]pas_ep = 16'h13f;
	
	wire [4:0]r = 0;
	wire [5:0]g = 6'b111111;
	wire [4:0]b = 0;

	always @ (*) begin
		param = 8'h00;
		case (command)
			MEM_ACCESS_CTRL: param = 8'h28;
			IF_PIXEL_FMT: param = 8'h55;
			8'hC1: param = 8'h41;
			8'hC5: begin case (param_num)
				4: param = 8'h00;
				3: param = 8'h91;
				2: param = 8'h80;
				1: param = 8'h00;
			endcase end
			8'hE0: begin case (param_num)
				15: param = 8'h0F;
				14: param = 8'h1F;
				13: param = 8'h1C;
				12: param = 8'h0C;
				11: param = 8'h0F;
				10: param = 8'h08;
				9: param = 8'h48;
				8: param = 8'h98;
				7: param = 8'h37;
				6: param = 8'h0A;
				5: param = 8'h13;
				4: param = 8'h04;
				3: param = 8'h11;
				2: param = 8'h0D;
				1: param = 8'h00;
			endcase end
			8'hE1: begin case (param_num)
				15: param = 8'h0F;
				14: param = 8'h32;
				13: param = 8'h2E;
				12: param = 8'h0B;
				11: param = 8'h0D;
				10: param = 8'h05;
				9: param = 8'h47;
				8: param = 8'h75;
				7: param = 8'h37;
				6: param = 8'h06;
				5: param = 8'h10;
				4: param = 8'h03;
				3: param = 8'h24;
				2: param = 8'h20;
				1: param = 8'h00;
			endcase end
			COLUMN_A_SET: begin case (param_num)
				4: param = cas_sc[15:8];
				3: param = cas_sc[7:0];
				2: param = cas_ec[15:8];
				1: param = cas_ec[7:0];
			endcase end
			PAGE_A_SET: begin case (param_num)
				4: param = pas_sp[15:8];
				3: param = pas_sp[7:0];
				2: param = pas_ep[15:8];
				1: param = pas_ep[7:0];
			endcase end
			MEM_WRITE: begin
				param = clearing ? 8'h00 : 
					//cnt[0] == 0 ? charcol + charrow * 80 : 8'hFF;
					cnt[0] == 0 ? {r, g[5:3]} : {g[2:0], b};
			end
		endcase
	end

	reg [3:0]test = 0;
	
	//localparam N = 1;
	localparam N = 100000;

	always @ (posedge clk) begin if (clk_en) begin
		case (state)
			RST: begin
				state <= SEND_C;
				command <= SOFT_RESET;
				param_num <= 0;
				state_ret <= SLPOUT;
				cnt <= 0;
			end
			// COLMOD
			SLPOUT: begin
				if (cnt > 5*N) begin
					state <= SEND_C;
					command <= SLEEP_OUT;
					param_num <= 0;
					state_ret <= DISPON;
					cnt <= 0;
				end else begin
					cnt <= cnt + 1;
				end
			end
			DISPON: begin
				if (cnt > 5*N) begin
					state <= SEND_C;
					command <= DISPLAY_ON;
					param_num <= 0;
					state_ret <= MAC;
					cnt <= 0;
				end else begin
					cnt <= cnt + 1;
				end
			end
			MAC: begin
				state <= SEND_C;
				command <= MEM_ACCESS_CTRL;
				param_num <= 1;
				state_ret <= COLMOD;
				cnt <= 0;
			end
			COLMOD: begin
				state <= SEND_C;
				command <= IF_PIXEL_FMT;
				param_num <= 1;
				state_ret <= VOLT_1;
				cnt <= 0;
			end
			//DISCTRL: begin
				//state <= SEND_C;
				//command <= DISP_FUNC_CTRL;
				//param_num <= 3;
				//state_ret <= GAMMA_1;
				//cnt <= 0;
			//end
			//BRIGHT: begin
				//state <= SEND_C;
				//command <= WRITE_BRIGHT;
				//param_num <= 1;
				//state_ret <= VOLT_1;
				//cnt <= 0;
			//end
			VOLT_1: begin
				state <= SEND_C;
				command <= 8'hC1;
				param_num <= 1;
				state_ret <= VOLT_2;
				cnt <= 0;
			end
			VOLT_2: begin
				state <= SEND_C;
				command <= 8'hC5;
				param_num <= 4;
				state_ret <= GAMMA_1;
				cnt <= 0;
			end
			GAMMA_1: begin
				state <= SEND_C;
				command <= 8'hE0;
				param_num <= 15;
				state_ret <= GAMMA_2;
				cnt <= 0;
			end
			GAMMA_2: begin
				state <= SEND_C;
				command <= 8'hE1;
				param_num <= 15;
				state_ret <= CLEAR_1;
				cnt <= 0;
			end
			IDLE: begin
				clearing <= 0;
				//if (test == 0) begin
					//state <= SEND_C;
					//command <= DISP_INVERT;
					//param_num <= 0;
					//state_ret <= IDLE;
					//cnt <= 0;
					//test <= 1;
				//end
				if (test == 0) begin
					test <= 1;
				end
				if (test == 1) begin
					if (charcol == 79) begin
						charcol <= 0;
						if (charrow == 39) begin
							charrow <= 0;
						end else charrow <= charrow + 1;
					end else charcol <= charcol + 1;
					state <= CAS;
					state_ret <= IDLE;
					cnt <= 0;
					test <= 2;
				end
				else if (test == 2) begin
					//test <= 3;
					if (cnt > 25000) begin
						state <= WCHAR;
						state_ret <= IDLE;
						cnt <= 0;
						test <= 1;
					end else
						cnt <= cnt + 1;
				end
				//if (cnt > 10*N) begin
					//state <= WCHAR;
					//cnt <= 0;
				//end else begin
					//cnt <= cnt + 1;
				//end
			end
			CLEAR_1: begin
				clearing <= 1;
				state <= CAS;
				state_ret <= CLEAR_2;
				cnt <= 0;
			end
			CLEAR_2: begin
				state <= SEND_C;
				command <= MEM_WRITE;
				param_num <= 307199;
				state_ret <= IDLE;
				cnt <= 0;
			end
			CAS: begin
				state <= SEND_C;
				command <= COLUMN_A_SET;
				param_num <= 4;
				state_ret_stash <= state_ret;
				state_ret <= PAS;
				cnt <= 0;
			end
			PAS: begin
				state <= SEND_C;
				command <= PAGE_A_SET;
				param_num <= 4;
				state_ret <= state_ret_stash;
				cnt <= 0;
			end
			WCHAR: begin
				state <= SEND_C;
				command <= MEM_WRITE;
				param_num <= 96; // 6*8 * 2
				cnt <= 0;
			end
			SEND_C: begin
				if (cnt == 1) begin // 
					cnt <= 0;
					if (param_num == 0) state <= state_ret;
					else state <= SEND_D;
				end else 
					cnt <= cnt + 1;
			end
			SEND_D: begin
				if (param_num == 0) begin
					state <= state_ret;
					cnt <= 0;
				end else if (cnt[0] == 1) begin
					param_num <= param_num - 1;
					cnt <= cnt + 1;
				end else
					cnt <= cnt + 1;
			end
		endcase
	end end

endmodule




//module LCD_Config(
    //input wire clk,
    //input wire rst_n,
    //input wire [15:0] data_in,

    //output reg cs,
    //output reg rs,
    //output reg wr,
    //output reg rd,
    //output reg [15:0] data_out
    //);

    //parameter total_px = 18'd153600;
    //parameter total_dl = 13'd5120;
    //reg [5:0] cnt=0;
    //reg [12:0] delay=0;
    //reg [17:0] px_cnt=0;

    //always@ (posedge clk)
    //begin
        //if(~rst_n)
        //begin
            //cnt <= 0;
            //delay <= 0;
            //px_cnt <= 0;
        //end
        //rd <= 1;
        //cs <= 0;
        //case(cnt)
        ////cmd//sw reset
        //0:
        //begin
            //rs <= 0;
            //wr <= 0;
            //data_out[7:0] <= 8'h1;  
            //cnt <= cnt + 1'd1;
        //end
        //1:
        //begin
            //wr <= 1'd1;
            //cnt <= cnt + 1'd1;
        //end
        ////delay ~5ms
        //2:
        //begin
            //if(delay == total_dl - 1'd1)
            //begin
                //delay <= 13'd0;
                //cnt <= cnt + 1'd1;
            //end
            //else
                //delay <= delay + 1'd1;
        //end
        ////cmd//Sleep OUT
        //3:      
        //begin
            //rs <= 0;
            //wr <= 0;
            //data_out[7:0] <= 8'h11; 
            //cnt <= cnt + 1'd1;
        //end
        //4:      
        //begin
            //wr <= 1'd1;
            //cnt <= cnt + 1'd1;
        //end
        ////delay ~5ms
        //5:      
        //begin
            //if(delay == total_dl - 1'd1)
            //begin
                //delay <= 13'd0;
                //cnt <= cnt + 1'd1;
            //end
            //else
                //delay <= delay + 1'd1;
        //end
        ////cmd//Normal Display Mode ON
        //6:      
        //begin
            //rs <= 0;
            //wr <= 0;
            //data_out[7:0] <= 8'h13; 
            //cnt <= cnt + 1'd1;
        //end
        //7:
        //begin
            //wr <= 1'd1;
            //cnt <= cnt + 1'd1;
        //end
        ////cmd//Display ON
        //8:      
        //begin
            //rs <= 0;
            //wr <= 0;
            //data_out[7:0] <= 8'h29; 
            //cnt <= cnt + 1'd1;
        //end
        //9:
        //begin
            //wr <= 1'd1;
            //cnt <= cnt + 1'd1;
        //end
        ////cmd//Column Address Set
        //10: 
        //begin
            //rs <= 0;
            //wr <= 0;
            //data_out[7:0] <= 8'h2A; 
            //cnt <= cnt + 1'd1;
        //end
        //11:
        //begin
            //wr <= 1'd1;
            //cnt <= cnt + 1'd1;
        //end 
        //12: //arg//sc[15:8]
        //begin
            //rs <= 1;
            //wr <= 0;
            //data_out[7:0] <= 8'h0;  
            //cnt <= cnt + 1'd1;
        //end
        //13:
        //begin
            //wr <= 1'd1;
            //cnt <= cnt + 1'd1;  
        //end
        //14: //arg//sc[7:0]
        //begin
            //rs <= 1;
            //wr <= 0;
            //data_out[7:0] <= 8'h0;  
            //cnt <= cnt + 1'd1;
        //end
        //15:
        //begin
            //wr <= 1'd1;
            //cnt <= cnt + 1'd1;  
        //end
        //16: //arg//ec[15:8]
        //begin
            //rs <= 1;
            //wr <= 0;
            //data_out[7:0] <= 8'h1;  
            //cnt <= cnt + 1'd1;
        //end
        //17:
        //begin
            //wr <= 1'd1;
            //cnt <= cnt + 1'd1;  
        //end
        //18: //arg//ec[7:0]
        //begin
            //rs <= 1;
            //wr <= 0;
            //data_out[7:0] <= 8'h3F; 
            //cnt <= cnt + 1'd1;
        //end
        //19:
        //begin
            //wr <= 1'd1;
            //cnt <= cnt + 1'd1;  
        //end
        ////cmd//Page Address Set
        //20: 
        //begin
            //rs <= 0;
            //wr <= 0;
            //data_out[7:0] <= 8'h2B; 
            //cnt <= cnt + 1'd1;
        //end
        //21:
        //begin
            //wr <= 1'd1;
            //cnt <= cnt + 1'd1;  
        //end
        //22: //arg//sp[15:8]
        //begin
            //rs <= 1;
            //wr <= 0;
            //data_out[7:0] <= 8'h0;  
            //cnt <= cnt + 1'd1;
        //end
        //23:
        //begin
            //wr <= 1'd1;
            //cnt <= cnt + 1'd1;  
        //end
        //24: //arg//sp[7:0]
        //begin
            //rs <= 1;
            //wr <= 0;
            //data_out[7:0] <= 8'h0;  
            //cnt <= cnt + 1'd1;
        //end
        //25:
        //begin
            //wr <= 1'd1;
            //cnt <= cnt + 1'd1;  
        //end
        //26: //arg//ep[15:8]
        //begin
            //rs <= 1;
            //wr <= 0;
            //data_out[7:0] <= 8'h1;  
            //cnt <= cnt + 1'd1;
        //end
        //27:
        //begin
            //wr <= 1'd1;
            //cnt <= cnt + 1'd1;  
        //end
        //28: //arg//ec[7:0]
        //begin
            //rs <= 1;
            //wr <= 0;
            //data_out[7:0] <= 8'hDF; 
            //cnt <= cnt + 1'd1;
        //end
        //29:
        //begin
            //wr <= 1'd1;
            //cnt <= cnt + 1'd1;  
        //end
        ////cmd//Memory Access Contrl
        //30: 
        //begin
            //rs <= 0;
            //wr <= 0;
            //data_out[7:0] <= 8'h36; 
            //cnt <= cnt + 1'd1;
        //end
        //31:
        //begin
            //wr <= 1'd1;
            //cnt <= cnt + 1'd1;  
        //end
        //32: //arg
        //begin
            //rs <= 1;
            //wr <= 0;
            //data_out[7:0] <= 8'h0;  
            //cnt <= cnt + 1'd1;
        //end
        //33:
        //begin
            //wr <= 1'd1;
            //cnt <= cnt + 1'd1;  
        //end
        ////cmd//Interface Pixel Format
        //34: 
        //begin
            //rs <= 0;
            //wr <= 0;
            //data_out[7:0] <= 8'h3A; 
            //cnt <= cnt + 1'd1;
        //end
        //35:
        //begin
            //wr <= 1'd1;
            //cnt <= cnt + 1'd1;  
        //end
        //36: //arg
        //begin
            //rs <= 1;
            //wr <= 0;
            //data_out[7:0] <= 8'b0101_x_101; 
            //cnt <= cnt + 1'd1;
        //end
        //37:
        //begin
            //wr <= 1'd1;
            //cnt <= cnt + 1'd1;  
        //end
        ////cmd//Frame Rate Control
        //38: 
        //begin
            //rs <= 0;
            //wr <= 0;
            //data_out[7:0] <= 8'hB1; 
            //cnt <= cnt + 1'd1;
        //end
        //39:
        //begin
            //wr <= 1'd1;
            //cnt <= cnt + 1'd1;  
        //end
        //40: //arg
        //begin
            //rs <= 1;
            //wr <= 0;
            //data_out[7:0] <= 8'hB0; 
            //cnt <= cnt + 1'd1;
        //end
        //41:
        //begin
            //wr <= 1'd1;
            //cnt <= cnt + 1'd1;  
        //end
        //42: //arg
        //begin
            //rs <= 1;
            //wr <= 0;
            //data_out[7:0] <= 8'h11; 
            //cnt <= cnt + 1'd1;
        //end
        //43:
        //begin
            //wr <= 1'd1;
            //cnt <= cnt + 1'd1;  
        //end
        ////cmd//Display Function Control
        //44: 
        //begin
            //rs <= 0;
            //wr <= 0;
            //data_out[7:0] <= 8'hB6; 
            //cnt <= cnt + 1'd1;
        //end
        //45:
        //begin
            //wr <= 1'd1;
            //cnt <= cnt + 1'd1;  
        //end
        //46: //arg1
        //begin
            //rs <= 1;
            //wr <= 0;
            //data_out[7:0] <= 8'h0;  
            //cnt <= cnt + 1'd1;
        //end
        //47:
        //begin
            //wr <= 1'd1;
            //cnt <= cnt + 1'd1;  
        //end
        //48: //arg2
        //begin
            //rs <= 1;
            //wr <= 0;
            //data_out[7:0] <= 8'h1;  
            //cnt <= cnt + 1'd1;
        //end
        //49:
        //begin
            //wr <= 1'd1;
            //cnt <= cnt + 1'd1;  
        //end
        //50: //arg3
        //begin
            //rs <= 1;
            //wr <= 0;
            //data_out[7:0] <= 8'h3B; 
            //cnt <= cnt + 1'd1;
        //end
        //51:
        //begin
            //wr <= 1'd1;
            //cnt <= cnt + 1'd1;  
        //end
        ////cmd//Memory Write 
        //52: 
        //begin
            //rs <= 0;
            //wr <= 0;
            //data_out[7:0] <= 8'h2C; 
            //cnt <= cnt + 1'd1;
        //end
        //53:
        //begin
            //wr <= 1'd1;
            //cnt <= cnt + 1'd1;  
        //end
        //54: //arg
        //begin
            //rs <= 1;
            //wr <= 0;
            //data_out <= data_in;    
            //cnt <= cnt + 1'd1;
        //end
        //55:
        //begin
            //wr <= 1'd1;
            ////memory is full
            //if(px_cnt == total_px - 1'd1)
            //begin
                //px_cnt <= 0;
                //cnt <= 6'd52; 
            //end
            //else
            //begin
                //px_cnt <= px_cnt + 1'd1;
                //cnt <= 6'd54; 
            //end 

        //end
        //endcase
    //end

//endmodule
