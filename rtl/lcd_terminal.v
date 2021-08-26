`timescale 1ns / 1ps

module lcd_terminal
(
	input clk,
	output [7:0]d,
	output rd,
	output wr,
	output rs,
	output cs,
	output rst,
	input rx,
	output rts
);
	assign rst = 1;
	assign rd = 1;
	assign rs = !(state == SEND_C);
	//assign cs = !(state == SEND_C | state == SEND_D);
	assign cs = 0;
	assign wr = !((state == SEND_C & cnt[0] == 0) | (state == SEND_D & cnt[0] == 0 & param_num != 0)); // 
	assign d = !rs ? command : param;

	reg [0:0]clk_reg = 0;
	always @ (posedge clk) begin
		clk_reg <= clk_reg + 1;
	end
	wire clk_en = (clk_reg[0] == 0);

	reg [22:0]cnt = 0;

	localparam RST = 0;
	localparam SLPOUT = 1;
	localparam DISPON = 2;
	localparam MAC = 3;
	localparam COLMOD = 4;
	localparam VOLT_1 = 5;
	localparam VOLT_2 = 6;
	localparam CLEAR_1 = 7;
	localparam CLEAR_2 = 8;
	localparam IDLE = 9;
	localparam CAS = 10;
	localparam PAS = 11;
	localparam SEND_C = 12;
	localparam SEND_D = 13;
	localparam WCHAR = 14;
	localparam CLR_LINE_1 = 15;
	localparam CLR_LINE_2 = 16;
	localparam DRAW_CURSOR = 17;
	localparam CLR_CURSOR = 18;
	localparam CURSOR_MEM = 19;
	localparam GAMMA_1 = 20;
	localparam GAMMA_2 = 21;
	localparam WCHAR_2 = 22;
	//localparam SCROLL = 22;
	reg [5:0]state = RST;
	reg [5:0]state_ret;
	reg [5:0]state_ret_stash;

	localparam SOFT_RESET = 8'h01;
	localparam SLEEP_OUT = 8'h11;
	localparam DISPLAY_ON = 8'h29;
	localparam MEM_ACCESS_CTRL = 8'h36;
	localparam IF_PIXEL_FMT = 8'h3A;
	localparam COLUMN_A_SET = 8'h2A;
	localparam PAGE_A_SET = 8'h2B;
	localparam MEM_WRITE = 8'h2C;
	//localparam VERTICAL_SCROLL = 8'h37;

	reg [7:0]command;
	reg [27:0]param_num;
	reg [7:0]param;

	// TODO: BUG: control character & charrol charrow, more than one/zero

	// 6x8 font terminal
	reg [6:0]charcol = 0;
	reg [5:0]charrow = 39; // begin from laaaast line

	wire [6:0]charcol_next = charcol == 79 ? 0 : (charcol + 1);
	wire [5:0]charrow_next = charcol == 79 ? (charrow == 39 ? 0 : charrow + 1) : charrow;
	wire clear_new_line = charcol == 79; // one position earlier, to avoid clear line clears the newly writen char
	//wire [15:0]scroll = 39 - charrow;
	// ^H
	wire [6:0]charcol_bs = charcol == 0 ? 0 : (charcol - 1);
	wire [5:0]charrow_bs = charrow;
	// ^M
	wire [6:0]charcol_cr = 0;
	wire [5:0]charrow_cr = charrow;
	// ^J
	wire [6:0]charcol_lf = charcol;
	wire [5:0]charrow_lf = charrow == 39 ? 0 : (charrow + 1);
	// ^I
	wire [6:0]charcol_ht = charcol > 76 ? 79 : {charcol[6:2]+5'b1, 2'b0}; // 4 tab
	wire [5:0]charrow_ht = charrow;
	// \033[A
	wire [5:0]charrow_up = charrow == 0 ? 0 : charrow - 1;

	//wire [5:0]charrow_below = charrow == 39 ? 0 : (charrow + 1);
	
	reg printable_char;
	wire [7:0]char = charrecv_r;
	wire [41:0]char_pixel = 
		char >= 8'h20 ? char_pixel_ufm :
		{char[7:4], 2'b10, char[3:0], 8'b10111110, 24'b0};
	wire curr_pixel = char_pixel[41-(cnt>>2)];

	wire [4:0]r = 5'b11111;
	wire [5:0]g = 6'b111111;
	wire [4:0]b = 5'b11111;

	reg [1:0]clearing = 0;
	reg clear_k = 0;
	reg d_cursor = 0; // drawing or cleaning cursor
	reg o_cursor = 0; // operation on cursor
	reg [15:0]cas_sc;
	reg [15:0]cas_ec;
	reg [15:0]pas_sp;
	reg [15:0]pas_ep;
	//wire [15:0]cas_sc = clearing != 0 ? 0 : charcol * 6;
	//wire [15:0]cas_ec = clearing != 0 ? 479 : charcol * 6 + 5;
	//wire [15:0]pas_sp = 
		//clearing == 1 ? 0  :
		//clearing == 2 ? charrow * 8 + 8 : charrow * 8 + o_cursor * 7;
	//wire [15:0]pas_ep =
		//clearing == 1 ? 319 : 
		//clearing == 2 ? charrow * 8 + 31 : charrow * 8 + 7;
	always @ (*) begin
		if (clearing == 1) begin
			if (clear_k) begin
				cas_sc = charcol * 6;
				cas_ec = 479;
				pas_sp = charrow * 8;
				pas_ep = charrow * 8 + 7;
			end else begin
				cas_sc = 0;
				cas_ec = 479;
				pas_sp = 0;
				pas_ep = 319;
			end
		end else if (clearing == 2) begin
			cas_sc = 0;
			cas_ec = 479;
			pas_sp = charrow * 8 + 8;
			pas_ep = charrow * 8 + 31;
		end else begin
			cas_sc = charcol * 6;
			cas_ec = charcol * 6 + 5;
			pas_sp = charrow * 8 + o_cursor * 7;
			pas_ep = charrow * 8 + 7;
		end
	end

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
			//8'hE0: begin case (param_num)
				//15: param = 8'h0F;
				//14: param = 8'h1F;
				//13: param = 8'h1C;
				//12: param = 8'h0C;
				//11: param = 8'h0F;
				//10: param = 8'h08;
				//9: param = 8'h48;
				//8: param = 8'h98;
				//7: param = 8'h37;
				//6: param = 8'h0A;
				//5: param = 8'h13;
				//4: param = 8'h04;
				//3: param = 8'h11;
				//2: param = 8'h0D;
				//1: param = 8'h00;
			//endcase end
			//8'hE1: begin case (param_num)
				//15: param = 8'h0F;
				//14: param = 8'h32;
				//13: param = 8'h2E;
				//12: param = 8'h0B;
				//11: param = 8'h0D;
				//10: param = 8'h05;
				//9: param = 8'h47;
				//8: param = 8'h75;
				//7: param = 8'h37;
				//6: param = 8'h06;
				//5: param = 8'h10;
				//4: param = 8'h03;
				//3: param = 8'h24;
				//2: param = 8'h20;
				//1: param = 8'h00;
			//endcase end
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
				param = clearing != 0 ? 8'h00 : 
					o_cursor ? (d_cursor&!cursorhide ? 8'h07 : 8'h00) :
					(curr_pixel ? 
					//8'hff
					cnt[0] == 0 ? {r, g[5:3]} : {g[2:0], b}
					: 8'h00);
			end
		endcase
	end

	reg [3:0]w_steps = 0;
	
	localparam DBG = 0;
	localparam N = DBG ? 1 : 800000;
	localparam CLEAR_W_COUNT = DBG ? 10 : 2*480*320;
	localparam CLEAR_K_COUNT = DBG ? 10 : 2*6*8*80; // overflow but doesn't matter
	localparam CLEAR_L_COUNT = DBG ? 5 : 2*6*8*80*3;
	localparam DRAW_C_COUNT = 2*6;

	wire hasrecv;
	wire [7:0]charrecv;
	reg [7:0]charrecv_r;
	reg nextchar = 0;

	// 0: normal
	// 1: ESC pressed
	// 2: [ pressed
	// ? or number dropped
	// return to 0 and execute consequence if a-zA-Z
	reg [1:0]escaped = 0;
	reg hasparam1;
	reg hasparam2;
	reg [7:0]csi_param1;
	reg [7:0]csi_param2;
	wire [7:0]param1 = hasparam1 ? csi_param1 : 1;
	wire [7:0]param2 = hasparam2 ? csi_param2 : 1;
	reg param_1or2;
	reg cursorhide = 0;

	always @ (posedge clk) begin
		if (nextchar) nextchar <= 0;
		else if (clk_en) begin
			case (state)
				RST: begin
					state <= SEND_C;
					command <= SOFT_RESET;
					param_num <= 0;
					state_ret <= SLPOUT;
					cnt <= 0;
				end
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
					state_ret <= VOLT_1; // VOLT_1
					cnt <= 0;
				end
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
					state_ret <= CLEAR_1; // GAMMA_1
					clear_k <= 0;
					cnt <= 0;
				end
				//GAMMA_1: begin
					//state <= SEND_C;
					//command <= 8'hE0;
					//param_num <= 15;
					//state_ret <= GAMMA_2;
					//cnt <= 0;
				//end
				//GAMMA_2: begin
					//state <= SEND_C;
					//command <= 8'hE1;
					//param_num <= 15;
					//state_ret <= CLEAR_1;
					//cnt <= 0;
				//end
				IDLE: begin
					clearing <= 0;
					o_cursor <= 0;
					cnt <= 0;
					state_ret <= IDLE;
					if (w_steps == 4'hf) begin
						state <= CAS;
						w_steps <= 1;
					end else if (w_steps == 1) begin // char processing
						state <= CAS;
						w_steps <= 4;
						if (escaped == 0) begin
							case (charrecv_r) // save resourc here!
								8'h07: begin
								end // bell, no
								8'h08: begin
									charcol <= charcol_bs;
									////charrow <= charrow_bs;
								end
								8'h09: begin
									charcol <= charcol_ht;
									//charrow <= charrow_ht;
								end
								8'h0a: begin
									//charcol <= charcol_lf;
									//charrow <= charrow_lf; // postponed
									state <= CLR_LINE_1;
									w_steps <= 2;
								end
								8'h0d: begin
									charcol <= charcol_cr;
									//charrow <= charrow_cr;
								end
								8'h0e: begin
								end
								8'h0f: begin
								end
								8'h1b: begin
									escaped <= 1;
									csi_param1 <= 0;
									csi_param2 <= 0;
									hasparam1 <= 0;
									hasparam2 <= 0;
									param_1or2 <= 0;
								end
								// 8'h1b
								default: begin
									state <= WCHAR;
									w_steps <= 3;
								end
							endcase
						end else if (escaped == 1) begin
							if (charrecv_r == 8'h5b) escaped <= 2;
							else escaped <= 0;
						end else if (escaped == 2) begin
							if (charrecv_r >= 8'h30 & charrecv_r <= 8'h39) begin
								if (param_1or2 == 0) begin
									csi_param1 <= csi_param1 * 10 + (charrecv_r - 8'h30);
									hasparam1 <= 1;
								end else begin
									csi_param2 <= csi_param2 * 10 + (charrecv_r - 8'h30);
									hasparam2 <= 1;
								end
								escaped <= 2;
							end else if (charrecv_r == 8'h3B) begin
								param_1or2 <= 1; // param 3+ not supported
								escaped <= 2;
							end else if (charrecv_r >= 8'h30 & charrecv_r <= 8'h3f) begin
								escaped <= 2;
							end else begin
								escaped <= 0;
								case (charrecv_r)
									8'h41: charrow <= charrow_up; // A
									8'h42: charrow <= charrow_lf; // B
									8'h43: charcol <= charcol_next; // C
									8'h44: charcol <= charcol_bs; // D
									8'h47: charcol <= param1; // G
									8'h4A: begin // ^[[2J
										//if (csi_param1 == 2) begin
											state <= CLEAR_1;
											clear_k <= 0;
										//end
									end
									8'h4B: begin // ^[[K
										if (!hasparam1) begin
											state <= CLEAR_1;
											clear_k <= 1;
										end
									end
									8'h48: begin
										charrow <= param1 - 1;
										charcol <= param2 - 1; end // H
									8'h64: charrow <= param1; // d
									8'h6c: if (csi_param1 == 25) cursorhide <= 1; // l
									8'h68: if (csi_param1 == 25) cursorhide <= 0; // h
								endcase
							end
						end
					end else if (w_steps == 2) begin // returned from CLR_LINE_2
						charrow <= charrow_lf; // I bet, if cursor moves to next line, it must be 1 line below. Then we can correctly clear lingering memory.
						// have to make sure charrow increase after CLR_LINE
						state <= CAS;
						w_steps <= 4;
					end else if (w_steps == 3) begin // returned from WC
						charcol <= charcol_next;
						charrow <= charrow_next;
						state <= CAS;
						w_steps <= 4;
					end else if (w_steps == 4) begin
						state <= DRAW_CURSOR;
						w_steps <= 5;
					end else if (w_steps == 5) begin
						state <= CAS;
						w_steps <= 0;
					end else if (hasrecv) begin // clear cursor, latch char
						charrecv_r <= charrecv;
						nextchar <= 1;
						w_steps <= 4'hf;
						state <= CLR_CURSOR;
					end
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
					param_num <= clear_k ? CLEAR_K_COUNT : CLEAR_W_COUNT;
					state_ret <= IDLE;
					cnt <= 0;
				end
				CLR_LINE_1: begin
					clearing <= 2;
					state <= CAS;
					state_ret <= CLR_LINE_2;
					cnt <= 0;
				end
				CLR_LINE_2: begin
					state <= SEND_C;
					command <= MEM_WRITE;
					param_num <= CLEAR_L_COUNT;
					state_ret <= IDLE;
					cnt <= 0;
				end
				DRAW_CURSOR: begin
					o_cursor <= 1;
					d_cursor <= 1;
					state <= CAS;
					state_ret <= CURSOR_MEM;
					cnt <= 0;
				end
				CLR_CURSOR: begin
					o_cursor <= 1;
					d_cursor <= 0;
					state <= CAS;
					state_ret <= CURSOR_MEM;
					cnt <= 0;
				end
				CURSOR_MEM: begin
					state <= SEND_C;
					command <= MEM_WRITE;
					param_num <= DRAW_C_COUNT;
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
				WCHAR: begin // always return to IDLE
					if (ufmread_done) begin
						state <= WCHAR_2;
					end
				end
				WCHAR_2: begin
					state <= SEND_C;
					state_ret <= IDLE;
					command <= MEM_WRITE;
					param_num <= 84; // 6*7 * 2
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
					end else begin
						cnt <= cnt + 1;
						if (cnt[0] == 1) begin
							param_num <= param_num - 1;
						end
					end
				end
			endcase
		end
	end

	reg [41:0]char_pixel_ufm;
	reg ufmread_done = 0; // 0 at idle time
	reg ufmreadchar = 0;
	reg [4:0]ufmcnt = 0;
	reg [1:0]ufmxfercnt = 0;
	reg [2:0]ufmstate = 0;
	wire osc;
	wire ufm_dvalid;
	wire ufm_nbusy;
	reg ufm_dvalid_r1 = 0;
	reg ufm_nbusy_r1 = 0;
	reg ufm_dvalid_r2 = 0;
	reg ufm_nbusy_r2 = 0;
	always @ (posedge clk) begin
		ufm_dvalid_r1 <= ufm_dvalid;
		ufm_dvalid_r2 <= ufm_dvalid_r1;
		ufm_nbusy_r1 <= ufm_nbusy;
		ufm_nbusy_r2 <= ufm_nbusy_r1;
	end
	wire [8:0]ufm_addr = ((charrecv_r - 8'h20) << 2) + {7'b0, ufmxfercnt};
	wire [15:0]ufm_dout;
	reg ufm_nread = 1;
	always @ (posedge clk) begin
		case (ufmstate)
			0: begin
				ufmcnt <= 0;
				ufmread_done <= 0;
				if (state == WCHAR) begin
					ufm_nread <= 0;
					ufmstate <= 1;
				end
			end
			1: begin
				ufmcnt <= ufmcnt + 1;
				if (ufmcnt == 25) begin
					ufm_nread <= 1;
					ufmstate <= 2;
				end
			end
			2: begin
				ufmcnt <= 0;
				if (ufm_dvalid_r2 & ufm_nbusy_r2) begin
					char_pixel_ufm <= {char_pixel_ufm[25:0], ufm_dout};
					ufmxfercnt <= ufmxfercnt + 1;
					if (ufmxfercnt == 2) begin // 3 xfers
						ufmstate <= 3;
					end else begin
						ufmstate <= 1;
						ufm_nread <= 0;
					end
				end
			end
			3: begin // wait till WCHAR gets it
				ufmread_done <= 1;
				if (state == WCHAR_2) ufmstate <= 0;
			end
			default: ufmstate <= 0;
		endcase
	end
	ufm_ip ufm_ip_inst(
		.addr(ufm_addr),
		.nread(ufm_nread),
		.oscena(1),
		.data_valid(ufm_dvalid),
		.dataout(ufm_dout),
		.nbusy(ufm_nbusy),
		.osc(osc) // 5.x MHz internal osc
	);

	wire rxclk_en;
	wire newrecv;
	wire [7:0]uartchar;
	baud_rate_gen #(
		.CLOCK_FREQ(30000000),
		.BAUD_RATE(19200),
		.SAMPLE_MULTIPLIER(16)
	) baud_rate_gen_inst_r(
		.clk(clk),
		.txclk_en(txclk_en),
		.rxclk_en(rxclk_en)
	);
	uart_rx uart_rx_inst(
		.clk(clk),
		.rxclk_en(rxclk_en),
		.rx(rx),
		.newrecv(newrecv),
		.charrecv(uartchar)
	);
	wire nonewchar;
	assign hasrecv = !nonewchar;
	// the fifo is buggy, or full as rts is not good
	ufifo ufifo_inst(
		.clk(clk),
		.enq(newrecv),
		.din(uartchar),
		.deq(nextchar),
		.dout(charrecv),
		.empty(nonewchar)
		//.full(rts)
	);
	assign rts = hasrecv;
endmodule

module ufifo // lamed uart fifo
(
	input clk,
	input enq,
	input [7:0]din,
	input deq,
	output [7:0]dout,
	output empty,
	output full
);
	reg [3:0]head = 0;
	reg [3:0]tail = 0;
	assign empty = head == tail;
	assign full = tail+1 == head;

	reg [7:0]d[15:0]; // 32(31 used) buffer

	assign dout = d[head];

	always @ (posedge clk) begin
		if (deq & !empty) begin
			head <= head + 1;
		end
		if (enq & !full) begin
			tail <= tail + 1;
			d[tail] <= din;
		end
	end
endmodule

module uart_rx
(
	input clk,
	input rxclk_en,
	input rx,
	output newrecv,
	output [7:0]charrecv
);
    localparam RX_STATE_START = 2'b01;
    localparam RX_STATE_DATA = 2'b10;
    localparam RX_STATE_STOP = 2'b11;
    reg [1:0]state_rx = RX_STATE_START;
    reg [3:0]sample = 0;
    reg [3:0]bitpos_rx = 0;
    reg [7:0]scratch = 8'b0;

    reg [7:0]data_rx = 0;
	assign charrecv = data_rx;

	reg data_rx_ready = 0;
	reg data_rx_ready_old = 0;
	always @ (posedge clk) begin
		data_rx_ready_old <= data_rx_ready;
	end
	assign newrecv = !data_rx_ready_old & data_rx_ready;

	always @ (posedge clk) begin if (rxclk_en) begin
		case(state_rx)
			RX_STATE_START: begin
				data_rx_ready <= 0;
				if (!rx || sample != 0) sample <= sample + 1;
				if (sample == 15) begin
					state_rx <= RX_STATE_DATA;
					bitpos_rx <= 0;
					sample <= 0;
					scratch <= 0;
				end
			end
			RX_STATE_DATA: begin
				sample <= sample + 1;
				if (sample == 8) begin //
					scratch[bitpos_rx[2:0]] <= rx;
					bitpos_rx <= bitpos_rx + 1;
				end
				if (bitpos_rx == 8 && sample == 15) state_rx <= RX_STATE_STOP;
			end
			RX_STATE_STOP: begin
				if (sample == 15 || (sample >= 8 && !rx)) begin //
					state_rx <= RX_STATE_START;
					data_rx <= scratch;
					data_rx_ready <= 1;
					sample <= 0;
				end else begin
					sample <= sample + 1;
				end
			end
			default: state_rx <= RX_STATE_START;
		endcase
	end end

endmodule
