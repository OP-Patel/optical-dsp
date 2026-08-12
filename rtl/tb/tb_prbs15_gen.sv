`timescale 1ns/1ps

module tb_prbs15_gen;

    localparam time CLK_PERIOD = 10ns;
    localparam logic [14:0] SEED = 15'h0001;
    localparam int PERIOD = 32767;

    // Frozen convention: output state[14] before advancing, shift toward
    // state[14], and insert state[14] XOR state[13] into state[0]. This fixed
    // vector was calculated independently of the DUT implementation.
    localparam logic [0:63] GOLDEN_BITS =
        64'b0000000000000010000000000000110000000000001010000000000011110000;

    logic clk = 1'b0;
    logic rst = 1'b1;
    logic load_seed = 1'b0;
    logic advance = 1'b0;
    logic bit_out;
    logic [14:0] state;

    int checks = 0;

    prbs15_gen #(
        .SEED(SEED)
    ) dut (
        .clk       (clk),
        .rst       (rst),
        .load_seed (load_seed),
        .advance   (advance),
        .bit_out   (bit_out),
        .state     (state)
    );

    always #(CLK_PERIOD / 2) clk = ~clk;

    task automatic expect_state(
        input logic [14:0] expected,
        input string message
    );
        assert (state === expected)
        else $fatal(1, "%s: expected state=%h, got %h at %0t",
                    message, expected, state, $time);
        checks++;
    endtask

    task automatic load_frozen_seed;
        @(negedge clk);
        rst = 1'b0;
        load_seed = 1'b1;
        advance = 1'b0;
        @(posedge clk);
        #1ns;
        expect_state(SEED, "load_seed did not load the frozen seed");
        @(negedge clk);
        load_seed = 1'b0;
    endtask

    initial begin : stimulus
        logic [14:0] held_state;
        int i;

        // Synchronous reset loads the nonzero seed.
        @(posedge clk);
        #1ns;
        expect_state(SEED, "reset did not load the seed");

        @(negedge clk);
        rst = 1'b0;

        // Compare the first 64 pre-shift output bits with a frozen vector.
        for (i = 0; i < 64; i++) begin
            assert (bit_out === GOLDEN_BITS[i])
            else $fatal(1, "golden mismatch at bit %0d: expected %0b, got %0b",
                        i, GOLDEN_BITS[i], bit_out);
            checks++;

            advance = 1'b1;
            @(posedge clk);
            #1ns;
            @(negedge clk);
        end
        advance = 1'b0;

        // State and output must hold over irregular gaps in advance.
        held_state = state;
        repeat (1) begin
            @(posedge clk);
            #1ns;
            expect_state(held_state, "state changed during one-cycle hold");
        end
        repeat (4) begin
            @(posedge clk);
            #1ns;
            expect_state(held_state, "state changed during multi-cycle hold");
        end
        assert (bit_out === held_state[14])
        else $fatal(1, "bit_out changed while state was held");
        checks++;

        // Documented priority: rst, then load_seed, then zero recovery, then
        // advance. Reset must win when every control is asserted.
        @(negedge clk);
        rst = 1'b1;
        load_seed = 1'b1;
        advance = 1'b1;
        @(posedge clk);
        #1ns;
        expect_state(SEED, "reset did not win simultaneous controls");

        // With reset low, load_seed must win over advance.
        @(negedge clk);
        rst = 1'b0;
        load_seed = 1'b0;
        advance = 1'b1;
        @(posedge clk);
        #1ns;
        assert (state !== SEED)
        else $fatal(1, "setup advance did not leave the seed");
        checks++;

        @(negedge clk);
        load_seed = 1'b1;
        advance = 1'b1;
        @(posedge clk);
        #1ns;
        expect_state(SEED, "load_seed did not win over advance");

        // Emulate a corrupted all-zero register. The next clock must reseed
        // even without advance. Force/release is testbench-only behavior.
        @(negedge clk);
        load_seed = 1'b0;
        advance = 1'b0;
        force dut.state = 15'b0;
        @(posedge clk);
        #0;
        release dut.state;
        #1ns;
        expect_state(SEED, "illegal zero state did not recover to the seed");

        // Reload, then prove the maximal period. No zero state or premature
        // recurrence of the seed is permitted.
        load_frozen_seed();
        advance = 1'b1;
        for (i = 1; i <= PERIOD; i++) begin
            @(posedge clk);
            #1ns;

            assert (state !== 15'b0)
            else $fatal(1, "zero state visited after %0d advances", i);
            checks++;

            if (i < PERIOD) begin
                assert (state !== SEED)
                else $fatal(1, "seed recurred early after %0d advances", i);
            end else begin
                assert (state === SEED)
                else $fatal(1, "seed did not recur at the full period");
            end
            checks++;
        end

        $display("PASS: tb_prbs15_gen verified 64 golden bits, period=%0d, checks=%0d",
                 PERIOD, checks);
        $finish;
    end

    initial begin
        #1ms;
        $fatal(1, "tb_prbs15_gen timed out");
    end

endmodule
