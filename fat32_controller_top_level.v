
//=======================================================
//  This code is generated by Terasic System Builder
//=======================================================

module fat32_controller_top_level(

	//////////// CLOCK //////////
	CLOCK_50,

	//////////// KEY //////////
	KEY,

	//////////// SW //////////
	SW,

	//////////// SDRAM //////////
	DRAM_ADDR,
	DRAM_BA,
	DRAM_CAS_N,
	DRAM_CKE,
	DRAM_CLK,
	DRAM_CS_N,
	DRAM_DQ,
	DRAM_DQM,
	DRAM_RAS_N,
	DRAM_WE_N,

	//////////// GPIO_1, GPIO_1 connect to GPIO Default //////////
	bottom,
	bottom_IN 
);

//=======================================================
//  PARAMETER declarations
//=======================================================


//=======================================================
//  PORT declarations
//=======================================================

//////////// CLOCK //////////
input 		          		CLOCK_50;

//////////// KEY //////////
input 		     [1:0]		KEY;

//////////// SW //////////
input 		     [3:0]		SW;

//////////// SDRAM //////////
output		    [12:0]		DRAM_ADDR;
output		     [1:0]		DRAM_BA;
output		          		DRAM_CAS_N;
output		          		DRAM_CKE;
output		          		DRAM_CLK;
output		          		DRAM_CS_N;
inout 		    [15:0]		DRAM_DQ;
output		     [1:0]		DRAM_DQM;
output		          		DRAM_RAS_N;
output		          		DRAM_WE_N;

//////////// GPIO_1, GPIO_1 connect to GPIO Default //////////
inout 		    [33:0]		bottom;
input 		     [1:0]		bottom_IN;


//=======================================================
//  REG/WIRE declarations
//=======================================================

reg [63:0] filename = {
    8'd114, // r
    8'd111, // o
    8'd109, // m
    {5{8'd32}} // SPACE x5
};
reg [23:0] extension = {
    8'd98, // b
    8'd105, // i
    8'd110 // n
};
reg [31:0] file_size = 100; // bytes
reg op_code = 1'b0;
reg execute = 1'b0;
reg [31:0] block_address = {32{1'b0}};
reg [7:0] outgoing_byte = 8'haa;
reg prev_btn = 1'b0;
wire clk;
wire [7:0] incoming_byte;
wire finished_byte;
wire finished_block;
wire busy;
wire debug_clk;
wire miso;

//=======================================================
//  Structural coding
//=======================================================

assign miso = bottom[5];
assign bottom[5] = 1'bz;
wire btn = !KEY[1];

always @(negedge clk) begin
	prev_btn <= btn;
end

sd_card_pll PLL0(
    .inclk0(CLOCK_50),
    .c0(clk),
    .c1(debug_clk)
);

fat32_controller F32C0 (
    .filename(filename),
    .extension(extension),
    .file_size(file_size),
    .op_code(op_code),
    .execute(btn && btn != prev_btn),
    .clk(clk),
    .outgoing_byte(outgoing_byte),
    .incoming_byte(incoming_byte),
    .finished_byte(finished_byte),
    .finished_block(finished_block),
    .busy(busy),

    .miso(miso),
    .cs(bottom[0]),
    .mosi(bottom[1]),
    .spi_clk(bottom[3])
);

endmodule
