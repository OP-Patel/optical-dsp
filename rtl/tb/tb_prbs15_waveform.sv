`timescale 1ns/1ps

// Short evidence-only simulation used to capture the Milestone 03 waveform.
module tb_prbs15_waveform;

    logic clk = 1'b0;
    logic rst = 1'b1;
    logic load_seed = 1'b0;
    logic bit_valid = 1'b0;
    logic corrupt_bit = 1'b0;
    logic source_bit;
    logic bit_in;
    logic error_pulse;
    logic [14:0] source_state;

    prbs15_gen source (
        .clk       (clk),
        .rst       (rst),
        .load_seed (load_seed),
        .advance   (bit_valid && !load_seed),
        .bit_out   (source_bit),
        .state     (source_state)
    );

    assign bit_in = source_bit ^ corrupt_bit;

    prbs15_check dut_checker (
        .clk         (clk),
        .rst         (rst),
        .load_seed   (load_seed),
        .bit_valid   (bit_valid),
        .bit_in      (bit_in),
        .error_pulse (error_pulse)
    );

    always #5ns clk = ~clk;

    initial begin
        // Reset, then explicitly align both generators to the frozen seed.
        @(negedge clk);
        rst = 1'b0;
        load_seed = 1'b1;
        @(negedge clk);
        load_seed = 1'b0;

        // Hold for two clocks, advance twice, then hold for one clock.
        repeat (2) @(negedge clk);
        bit_valid = 1'b1;
        repeat (2) @(negedge clk);
        bit_valid = 1'b0;
        @(negedge clk);

        // Advance with a deliberately corrupted bit to produce one error pulse.
        bit_valid = 1'b1;
        corrupt_bit = 1'b1;
        @(negedge clk);
        bit_valid = 1'b0;
        corrupt_bit = 1'b0;
        repeat (2) @(negedge clk);

        $finish;
    end

endmodule
