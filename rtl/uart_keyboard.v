`timescale 1ns / 1ps

module uart_keyboard
(
	input clk,
	output [3:0]x,
	input [14:0]y,
	output xa,
	input [10:0]ya,
	output tx
);
	wire kpress_raw;
	wire [7:0]kcodebase;
	keyscan keyscan_inst (
		.clk(clk),
		.x(x),
		.y(y),
		.xa(xa),
		.ya(ya),
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
		.CLOCK_FREQ(40000000),
		.BAUD_RATE(115200),
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
	output [3:0]x,
	input [14:0]y,
	output xa,
	input [10:0]ya,

	output kpress,
	output [7:0]kcodebase
);
	reg [3:0]sftreg = 4'b0111;
	assign x = sftreg;
	wire nopress = &y;
	always @ (posedge clk) begin
		if (nopress) sftreg <= {sftreg[2:0], sftreg[3]};
	end

	assign xa = 0;
	wire m_nopress = &ya;

	assign kpress = !nopress | (0 & !m_nopress);
	assign kcodebase = y[0]*0 + y[1]*1 + y[2]*2 + y[3]*3 + 
		y[4]*4 + y[5]*5 + y[6]*6 + y[7]*7 + y[8]*8 + y[9]*9 
		+ y[10]*10 + y[11]*11 + y[12]*12 + y[13]*13 + y[14]*14 +
		((ya[0]*0 + ya[1]*1 + ya[2]*2 + ya[3]*3 + ya[4]*4)<<4);
endmodule

module keydecode
(
	input [7:0]kcodebase,
	output [7:0]kcodereal
);
	assign kcodereal = kcodebase;
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

	reg [9:0]cnt = 0;
	wire idle = (o == sync_1);
	always @(posedge clk) begin
		if (idle) cnt <= 0;
		else begin
			cnt <= cnt + 1;
			if (N == 1) begin
				if (sync_1 == 0) begin if (cnt == CNT_UP) o <= sync_1; end
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
	output kpresso,
	output [7:0]kcodeo
);
	debounce #(
		.N(1),
		.CNT_UP(50),
		.CNT_DOWN(20),
		.INIT(0)
	) debounce_1 (
		.clk(clk),
		.i(kpressi),
		.o(kpresso)
	);
	debounce #(
		.N(8),
		.CNT_UP(35)
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
	output usend,
	output [7:0]ucode
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
	assign usend = (kpress & !kpress_old) | 
		(cnth > 16'h131 & cnth[4:0] == 6'b11111 & cntlovfl);
endmodule

module uarttx
(
	input clk,
	input clken,
	input send,
	input [7:0]ucode,
	output reg tx
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

module baud_rate_gen
	#(
		parameter CLOCK_FREQ = 0,
		parameter BAUD_RATE = 0,
		parameter SAMPLE_MULTIPLIER = 0
	)
    (
        input wire clk,
        output wire rxclk_en,
        output wire txclk_en
    );

    parameter RX_ACC_MAX = CLOCK_FREQ / (BAUD_RATE * SAMPLE_MULTIPLIER) + 1;
    parameter TX_ACC_MAX = CLOCK_FREQ / BAUD_RATE;
    parameter RX_ACC_WIDTH = 16;
    parameter TX_ACC_WIDTH = 16;
    //parameter RX_ACC_WIDTH = $clog2(RX_ACC_MAX);
    //parameter TX_ACC_WIDTH = $clog2(TX_ACC_MAX);
    reg [RX_ACC_WIDTH - 1:0] rx_acc = 0;
    reg [TX_ACC_WIDTH - 1:0] tx_acc = 0;

    assign rxclk_en = (rx_acc == 0);
    assign txclk_en = (tx_acc == 0);

    always @(posedge clk) begin
        if (rx_acc == RX_ACC_MAX[RX_ACC_WIDTH - 1:0])
            rx_acc <= 0;
        else
            rx_acc <= rx_acc + 1;
    end

    always @(posedge clk) begin
        if (tx_acc == TX_ACC_MAX[TX_ACC_WIDTH - 1:0])
            tx_acc <= 0;
        else
            tx_acc <= tx_acc + 1;
    end

endmodule
