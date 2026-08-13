`timescale 1ns/1ps

module tb_optical_framer_waveform;

logic clk = 1'b0;
logic rst = 1'b1;
logic symbol_ce = 1'b0;
logic [1:0] mode = 2'b00;
logic tx_bit;
logic frame_start;
logic payload_start;
logic [15:0] frame_sequence;

optical_framer dut (
    .clk(clk),
    .rst(rst),
    .symbol_ce(symbol_ce),
    .mode(mode),
    .tx_bit(tx_bit),
    .frame_start(frame_start),
    .payload_start(payload_start),
    .frame_sequence(frame_sequence)
);

always #5ns clk = ~clk;

initial begin
    repeat (2) @(posedge clk);
    @(negedge clk);
    rst = 1'b0;
    mode = 2'b11;

    repeat (36) begin
        symbol_ce = 1'b1;
        @(posedge clk);
        #1ns;
        @(negedge clk);
    end

    symbol_ce = 1'b0;
    repeat (3) @(posedge clk);
    @(negedge clk);

    repeat (34) begin
        symbol_ce = 1'b1;
        @(posedge clk);
        #1ns;
        @(negedge clk);
    end

    symbol_ce = 1'b0;
    repeat (3) @(posedge clk);
    $finish;
end

endmodule
