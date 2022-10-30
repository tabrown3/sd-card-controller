
//=======================================================
//  This code is generated by Terasic System Builder
//=======================================================

module sd_card_controller_top_level(

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


reg op_code = 1'b0;
reg execute = 1'b0;
reg [25:0] sector_address = {26{1'b0}};
reg [7:0] outgoing_byte = 8'h00;
wire clk;
wire [7:0] incoming_byte;
wire mosi;
wire finished_byte;
wire finished_sector;
wire busy;

//=======================================================
//  Structural coding
//=======================================================

assign bottom[1] = mosi ? 1'bz : 1'b0;

sd_card_pll PLL0(
    .inclk0(CLOCK_50),
    .c0(clk)
);

sd_card_controller SDCC0 (
    .op_code(op_code),
    .execute(execute),
    .clk(clk),
    .sector_address(sector_address),
    .miso(bottom[5]), // weak pull-up enabled
    .outgoing_byte(outgoing_byte),
    .cs(bottom[0]),
    .incoming_byte(incoming_byte),
    .mosi(mosi),
    .finished_byte(finished_byte),
    .finished_sector(finished_sector),
    .spi_clk(bottom[3]),
    .busy(busy)
);

endmodule
