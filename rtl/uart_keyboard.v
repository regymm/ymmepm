`timescale 1ns / 1ps

module uart_keyboard
(
	input clk,
	output [4:0]x,
	input [14:0]y,
	output xa,
	input [10:0]ya,
	output led0,
	output led1,
	output tx
);
	wire kpress_raw;
	wire [13:0]kcodebase;
	keyscan keyscan_inst (
		.clk(clk),
		.x(x),
		.y(y),
		.xa(xa),
		.ya(ya),
		.nopress(led0),
		.dbg(led1),
		.kpress(kpress_raw),
		.kcodebase(kcodebase)
	);
	wire [7:0]kcode_raw;
	keydecode keydecode_inst(
		.kcodebase(kcodebase),
		.kcodereal(kcode_raw)
	);
	wire kpress;
	wire [7:0]kcode;
	keycodedebounce keycodedebounce_inst (
		.clk(clk),
		.kpressi(kpress_raw),
		.kcodei(kcode_raw),
		.kpresso(kpress),
		.kcodeo(kcode)
	);
	wire usend;
	wire [7:0]ucode;
	keycode2uart keycode2uart_inst(
		.clk(clk),
		.kpress(kpress),
		.kcode(kcode),
		.usend(usend),
		.ucode(ucode)
	);
	wire txclk_en;
	wire rxclk_en;
	baud_rate_gen #(
		.CLOCK_FREQ(30000000),
		.BAUD_RATE(19200),
		.SAMPLE_MULTIPLIER(8)
	) baud_rate_gen_inst(
		.clk(clk),
		.txclk_en(txclk_en),
		.rxclk_en(rxclk_en)
	);
	uarttx uarttx_inst(
		.clk(clk),
		.clken(txclk_en),
		.send(usend),
		.ucode(ucode),
		.tx(tx)
	);
endmodule

module keyscan
(
	input clk,
	(* mark_debug = "true" *)output [4:0]x,
	(* mark_debug = "true" *)input [14:0]y,
	output xa,
	input [10:0]ya,
	output nopress,
	output dbg,

	(* mark_debug = "true" *)output kpress,
	(* mark_debug = "true" *)output reg [13:0]kcodebase
);
	//reg [3:0]clken = 0;
	reg [4:0]sftreg = 5'b01111;
	reg [4:0]sftreg_npress = 5'b11111;
	assign x = sftreg;
	//assign nopress = &y[14:0];
	assign nopress = &y_r2[14:0];
	reg [4:0]x_r1;
	reg [4:0]x_r2;
	reg [14:0]y_r1;
	reg [14:0]y_r2;
	always @ (posedge clk) begin
		//clken <= clken + 1;
		//if (clken[3]) begin
			sftreg <= {sftreg[3:0], sftreg[4]};
			sftreg_npress <= {sftreg_npress[3:0], nopress};
			//if (nopress) sftreg <= {sftreg[3:0], sftreg[4]};
		//end
		x_r1 <= sftreg;
		x_r2 <= x_r1;
		y_r1 <= y;
		y_r2 <= y_r1;
	end

	assign dbg = y_r2[9];

	assign xa = 0;
	wire m_nopress = &ya;

	//assign kpress = !nopress | (0 & !m_nopress);
	assign kpress = !(&sftreg_npress) | (0 & !m_nopress);
	wire [2:0]kcodebase_x =
		x_r2[0] == 0 ? 3'b001 :
		x_r2[1] == 0 ? 3'b010 : 
		x_r2[2] == 0 ? 3'b011 : 
		x_r2[3] == 0 ? 3'b100 : 
		x_r2[4] == 0 ? 3'b101 : 3'b000;
	wire [3:0]kcodebase_y = 
		y_r2[0] == 0 ? 4'b0000 : 
		y_r2[1] == 0 ? 4'b0001 :
		y_r2[2] == 0 ? 4'b0010 :
		y_r2[3] == 0 ? 4'b0011 :
		y_r2[4] == 0 ? 4'b0100 :
		y_r2[5] == 0 ? 4'b0101 :
		y_r2[6] == 0 ? 4'b0110 :
		y_r2[7] == 0 ? 4'b0111 :
		y_r2[8] == 0 ? 4'b1000 :
		y_r2[9] == 0 ? 4'b1001 :
		y_r2[10] == 0 ? 4'b1010 :
		y_r2[11] == 0 ? 4'b1011 :
		y_r2[12] == 0 ? 4'b1100 :
		y_r2[13] == 0 ? 4'b1101 : 4'b1111;
	always @ (posedge clk) begin
		if (!nopress) kcodebase <= {3'b0, 
		!ya[10], !ya[8], !ya[1], !ya[0], 
		kcodebase_y, kcodebase_x};
	end
	//+ 
		//((!ya[0]*1)<<7) + 
		//((!ya[1]*1)<<8) + 
		//((!ya[2]*1)<<9) + 
		//((!ya[3]*1)<<10) + 
		//((!ya[4]*1)<<11) + 
		//((!ya[5]*1)<<12);
endmodule

module keydecode
(
	input [13:0]kcodebase,
	(* mark_debug = "true" *)output reg [7:0]kcodereal
);
	//assign kcodereal = kcodebase;
	wire [2:0]x = kcodebase[2:0];
	wire [3:0]y = kcodebase[6:3];
	wire shift = kcodebase[7] | kcodebase[9];
	wire ctrl = kcodebase[8] | kcodebase[10];
	//wire supr = kcodebase[9];
	//wire alt = kcodebase[10];
	//wire fn = kcodebase[11];
	reg [7:0]kcr_1;
	always @ (*) begin
		kcr_1 = 8'h00;
		case (x) 
			3'b001: begin
				case (y)
					4'b0001: kcr_1 = 8'h31; // 1
					4'b0010: kcr_1 = 8'h32; // 2
					4'b0011: kcr_1 = 8'h33; // 3
					4'b0100: kcr_1 = 8'h34; // 4
					4'b0101: kcr_1 = 8'h35; // 5
					4'b0110: kcr_1 = 8'h36; // 6
					4'b0111: kcr_1 = 8'h37; // 7
					4'b1000: kcr_1 = 8'h38; // 8
					4'b1001: kcr_1 = 8'h39; // 9
					4'b1010: kcr_1 = 8'h30; // 0
					4'b1011: kcr_1 = 8'h2D; // -
					4'b1100: kcr_1 = 8'h3D; // =
					4'b1101: kcr_1 = 8'h08; // BS
				endcase
			end
			3'b010: begin
				case (y)
					4'b0000: kcr_1 = 8'h60; // `
					4'b0001: kcr_1 = 8'h71; // q
					4'b0010: kcr_1 = 8'h77; // w
					4'b0011: kcr_1 = 8'h65; // e
					4'b0100: kcr_1 = 8'h72; // r
					4'b0101: kcr_1 = 8'h74; // t
					4'b0110: kcr_1 = 8'h79; // y
					4'b0111: kcr_1 = 8'h75; // u
					4'b1000: kcr_1 = 8'h69; // i
					4'b1001: kcr_1 = 8'h6F; // o
					4'b1010: kcr_1 = 8'h70; // p
					4'b1011: kcr_1 = 8'h5B; // [
					4'b1100: kcr_1 = 8'h5D; // ]
					4'b1101: kcr_1 = 8'h5C; // \
				endcase
			end
			3'b011: begin
				case (y)
					4'b0000: kcr_1 = 8'h09; // TAB
					4'b0001: kcr_1 = 8'h61; // a
					4'b0010: kcr_1 = 8'h73; // s
					4'b0011: kcr_1 = 8'h64; // d
					4'b0100: kcr_1 = 8'h66; // f
					4'b0101: kcr_1 = 8'h67; // g
					4'b0110: kcr_1 = 8'h68; // h
					4'b0111: kcr_1 = 8'h6A; // j
					4'b1000: kcr_1 = 8'h6B; // k
					4'b1001: kcr_1 = 8'h6C; // l
					4'b1010: kcr_1 = 8'h3B; // ;
					4'b1011: kcr_1 = 8'h27; // '
					4'b1100: kcr_1 = 8'h0D; // Return
				endcase
			end
			3'b100: begin
				case (y)
					4'b0000: kcr_1 = 8'h1B; // ESC
					4'b0001: kcr_1 = 8'h7A; // z
					4'b0010: kcr_1 = 8'h78; // x
					4'b0011: kcr_1 = 8'h63; // c
					4'b0100: kcr_1 = 8'h76; // v
					4'b0101: kcr_1 = 8'h62; // b
					4'b0110: kcr_1 = 8'h6E; // n
					4'b0111: kcr_1 = 8'h6D; // m
					4'b1000: kcr_1 = 8'h2C; // ,
					4'b1001: kcr_1 = 8'h2E; // .
					4'b1010: kcr_1 = 8'h2F; // /
				endcase
			end
			3'b101: begin
				case (y)
					4'b0100: kcr_1 = 8'h20; // SPACE
				endcase
			end
		endcase
	end
	always @ (*) begin
		kcodereal = kcr_1;
		if (ctrl) kcodereal = {3'b0, kcr_1[4:0]};
		else if (shift) begin
			if (kcr_1 >= 8'h61 & kcr_1 <= 8'h7D) kcodereal = kcr_1 - 8'h20;
			else if (kcr_1 == 8'h31) kcodereal = 8'h21;
			else if (kcr_1 == 8'h32) kcodereal = 8'h40;
			else if (kcr_1 == 8'h33) kcodereal = 8'h23;
			else if (kcr_1 == 8'h34) kcodereal = 8'h24;
			else if (kcr_1 == 8'h35) kcodereal = 8'h25;
			else if (kcr_1 == 8'h36) kcodereal = 8'h5E;
			else if (kcr_1 == 8'h37) kcodereal = 8'h26;
			else if (kcr_1 == 8'h38) kcodereal = 8'h2A;
			else if (kcr_1 == 8'h39) kcodereal = 8'h28;
			else if (kcr_1 == 8'h30) kcodereal = 8'h29;
			else if (kcr_1 == 8'h2D) kcodereal = 8'h5F;
			else if (kcr_1 == 8'h3D) kcodereal = 8'h2B;

			else if (kcr_1 == 8'h5B) kcodereal = 8'h7B;
			else if (kcr_1 == 8'h5D) kcodereal = 8'h7D;
			else if (kcr_1 == 8'h5C) kcodereal = 8'h7C;
			
			else if (kcr_1 == 8'h60) kcodereal = 8'h7E;
			else if (kcr_1 == 8'h3B) kcodereal = 8'h3A;
			else if (kcr_1 == 8'h27) kcodereal = 8'h22;

			else if (kcr_1 == 8'h2C) kcodereal = 8'h3C;
			else if (kcr_1 == 8'h2E) kcodereal = 8'h3E;
			else if (kcr_1 == 8'h2F) kcodereal = 8'h3F;
		end
	end
endmodule

module debounce
#(
	parameter N = 1,
	parameter CNT_UP = 20,
	parameter CNT_DOWN = 20,
	parameter INIT = 0
)
(
	input clk,
	input [N-1:0]i,
	output reg [N-1:0]o = INIT
);
	reg [N-1:0]sync_0 = 0;
	reg [N-1:0]sync_1 = 0;
    always @(posedge clk) sync_0 <= i;
    always @(posedge clk) sync_1 <= sync_0;

	reg [15:0]cnt = 0;
	wire idle = (o == sync_1);
	always @(posedge clk) begin
		if (idle) cnt <= 0;
		else begin
			cnt <= cnt + 1;
			if (N == 1) begin
				if (o == 0) begin if (cnt == CNT_UP) o <= sync_1; end
				else if (cnt == CNT_DOWN) o <= sync_1;
			end else begin
				if (cnt == CNT_UP) o <= sync_1;
			end
		end
	end
endmodule

module keycodedebounce
(
	input clk,
	input kpressi,
	input [7:0]kcodei,
	(* mark_debug = "true" *)output kpresso,
	(* mark_debug = "true" *)output [7:0]kcodeo
);
	debounce #(
		.N(1),
		.CNT_UP(2000),
		.CNT_DOWN(0),
		.INIT(0)
	) debounce_1 (
		.clk(clk),
		.i(kpressi),
		.o(kpresso)
	);
	debounce #(
		.N(8),
		.CNT_UP(400)
	) debounce_2 (
		.clk(clk),
		.i(kcodei),
		.o(kcodeo)
	);
endmodule

module keycode2uart
(
	input clk,
	input kpress,
	input [7:0]kcode,
	(* mark_debug = "true" *)output usend,
	(* mark_debug = "true" *)output [7:0]ucode
);
	assign ucode = kcode;
	reg kpress_old;
	always @ (posedge clk) begin
		kpress_old <= kpress;
	end
	reg [15:0]cnth; // 0x131, 0x1f
	reg [15:0]cntl;
	wire cntlovfl = (cntl == 16'hffff);
	always @ (posedge clk) begin
		if (kpress_old) begin
			cntl <= cntl + 1;
			if (cntlovfl) cnth <= cnth + 1;
		end else begin
			cntl <= 0;
			cnth <= 0;
		end
	end
	assign usend = (kpress & cnth == 16'h18 & cntlovfl) | 
		(cnth > 16'h100 & cnth[4:0] == 5'b11111 & cntlovfl);
endmodule

module uarttx
(
	input clk,
	input clken,
	input send,
	input [7:0]ucode,
	(* mark_debug = "true" *)output reg tx
);
    localparam IDLE = 2'b00;
    localparam START = 2'b01;
    localparam DATA = 2'b10;
    localparam STOP = 2'b11;
    reg [1:0]state_tx = IDLE;
    reg [7:0]data_tx = 8'h00;
    reg [2:0]bitpos_tx = 3'b0;

	always @ (posedge clk) begin
		case (state_tx)
			IDLE: if (send) begin
				data_tx <= ucode;
				state_tx <= START;
				bitpos_tx <= 3'b0;
			end
			START: if (clken) begin
				tx <= 1'b0;
				state_tx <= DATA;
			end
			DATA: if (clken) begin
				if (bitpos_tx == 3'h7) state_tx <= STOP;
				else bitpos_tx <= bitpos_tx + 1;
				tx <= data_tx[bitpos_tx];
			end
			STOP: if (clken) begin
				tx <= 1'b1;
				state_tx <= IDLE;
			end
		endcase
	end
endmodule
