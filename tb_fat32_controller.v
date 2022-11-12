`timescale 1us/100ns
module tb_fat32_controller ();
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
    integer file_size = 100; // bytes
    reg op_code = 1'b0;
    reg execute = 1'b0;
    reg clk = 1'b0;
    reg [7:0] outgoing_byte = 8'h00;
    wire [7:0] incoming_byte;
    wire finished_byte;
    wire finished_block;
    wire busy;

    reg miso = 1'b0;
    wire cs;
    wire mosi;
    wire spi_clk;

    integer clk_cnt = 0;

    fat32_controller F32C0 (
        .filename(filename),
        .extension(extension),
        .file_size(file_size),
        .op_code(op_code),
        .execute(execute),
        .clk(clk),
        .outgoing_byte(outgoing_byte),
        .incoming_byte(incoming_byte),
        .finished_byte(finished_byte),
        .finished_block(finished_block),
        .busy(busy),

        .miso(miso),
        .cs(cs),
        .mosi(mosi),
        .spi_clk(spi_clk)
    );

    initial begin
        #20000;
        $stop;
    end

    always begin
        #0.5;
        clk = ~clk;
        #0.5;
        clk = ~clk;
    end

    always @(negedge clk) begin
        // if (clk_cnt > 4450 && clk_cnt < 4920) begin
        //     miso <= 1'b0;
        // end else if (clk_cnt > 6795 && clk_cnt < 6803) begin
        //     miso <= 1'b1;
        // end else if (clk_cnt > 17722 && clk_cnt < 17729) begin
        //     miso <= 1'b1;
        // end else if (clk_cnt >= 17729 && clk_cnt < 17731) begin
        //     miso <= 1'b0;
        // end else if (clk_cnt > 17864) begin
        //     miso <= 1'b1;
        // end else begin
            miso <= $random;
        // end

        if (clk_cnt == 50) begin
            execute <= 1'b1;
        // end else if (clk_cnt == 5870) begin
        //     execute <= 1'b1;
        // end else if (clk_cnt == 12015) begin
        //     execute <= 1'b1;
        //     op_code <= 1'b1;
        end else begin
            execute <= 1'b0;
        end

        clk_cnt <= clk_cnt + 1;
    end
endmodule