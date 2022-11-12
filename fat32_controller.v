module fat32_controller (
    input [63:0] filename, // 8 bytes for name
    input [23:0] extension, // 3 bytes for extension
    input integer file_size, // bytes
    input op_code,
    input execute,
    input clk,
    input [7:0] outgoing_byte,
    output [7:0] incoming_byte,
    output finished_byte,
    output finished_block,
    output busy,

    // pass-through (neither used nor modified at this level)
    input miso,
    output cs,
    output mosi,
    output spi_clk
);
    localparam [4:0] UNINITIALIZED = 5'h00;
    localparam [4:0] AWAIT_SD_CARD_INIT = 5'h01;
    localparam [4:0] READ_MBR = 5'h02; //

    // SDCC0 input deps
    reg sd_op_code = 1'b0;
    reg sd_execute = 1'b0;
    reg [31:0] block_address = {32{1'b0}};
    reg [7:0] sd_outgoing_byte = 8'haa; // this is dummy data
    reg init_sd_card_reg = 1'b0;
    reg p_init_sd_card = 1'b0;

    // other regs
    reg [4:0] cur_state = UNINITIALIZED;
    reg initialize_state = 1'b1;
    reg executing = 1'b0;
    
    // SDCC0 output deps
    wire [7:0] sd_incoming_byte;
    wire sd_finished_byte;
    wire sd_finished_block;
    wire sd_busy;

    // other wires
    wire init_sd_card;

    // Controller Logic - Start
    assign init_sd_card = ~(init_sd_card_reg ^ p_init_sd_card);
    assign busy = executing;

    sd_card_controller SDCC0 (
        .op_code(sd_op_code),
        .execute(sd_execute),
        .clk(clk),
        .block_address(block_address),
        .miso(miso),
        .outgoing_byte(sd_outgoing_byte),
        .btn(init_sd_card),
        .cs(cs),
        .incoming_byte(sd_incoming_byte),
        .mosi(mosi),
        .finished_byte(sd_finished_byte),
        .finished_block(sd_finished_block),
        .spi_clk(spi_clk),
        .busy(sd_busy)
    );

    always @(negedge clk) begin
        case (cur_state)
            UNINITIALIZED: begin
                if (execute) begin
                    init_sd_card_reg <= ~init_sd_card_reg; // kick off sd card init
                    executing <= 1'b1;
                    transition_to(AWAIT_SD_CARD_INIT);
                end
            end
            AWAIT_SD_CARD_INIT: begin
                if (!sd_busy) begin
                    transition_to(READ_MBR);
                end
            end
            READ_MBR: begin
            end
            default: begin
                transition_to(UNINITIALIZED);
            end
        endcase

        p_init_sd_card <= init_sd_card_reg;
    end

    task transition_to (input [4:0] next_state);
        cur_state <= next_state;
    endtask
endmodule