`timescale 1ns/1ps

module tb_prbs15_check;

    localparam time CLK_PERIOD = 10ns;
    localparam int CLEAN_BITS = 100000;

    logic clk = 1'b0;
    logic rst = 1'b1;
    logic load_seed = 1'b0;
    logic bit_valid = 1'b0;
    logic corrupt_bit = 1'b0;
    logic source_bit;
    logic bit_in;
    logic error_pulse;
    logic [14:0] source_state;

    int compared_scoreboard = 0;
    int error_scoreboard = 0;
    int checks = 0;

    // Independent source instance drives the received bit stream. Its
    // convention is separately checked against a fixed vector and full period
    // in tb_prbs15_gen.
    prbs15_gen source (
        .clk       (clk),
        .rst       (rst),
        .load_seed (load_seed),
        .advance   (bit_valid && !load_seed),
        .bit_out   (source_bit),
        .state     (source_state)
    );

    assign bit_in = source_bit ^ corrupt_bit;

    prbs15_check dut (
        .clk         (clk),
        .rst         (rst),
        .load_seed   (load_seed),
        .bit_valid   (bit_valid),
        .bit_in      (bit_in),
        .error_pulse (error_pulse)
    );

    always #(CLK_PERIOD / 2) clk = ~clk;

    task automatic apply_reset;
        @(negedge clk);
        rst = 1'b1;
        load_seed = 1'b0;
        bit_valid = 1'b0;
        corrupt_bit = 1'b0;
        @(posedge clk);
        #1ns;
        assert (error_pulse === 1'b0)
        else $fatal(1, "error_pulse was not cleared by reset");
        checks++;
        compared_scoreboard = 0;
        error_scoreboard = 0;
        @(negedge clk);
        rst = 1'b0;
    endtask

    task automatic reload_seed;
        @(negedge clk);
        load_seed = 1'b1;
        bit_valid = 1'b1; // prove load_seed wins over a simultaneous valid bit
        corrupt_bit = 1'b1;
        @(posedge clk);
        #1ns;
        assert (error_pulse === 1'b0)
        else $fatal(1, "load_seed cycle incorrectly reported an error");
        assert (source_state === 15'h0001)
        else $fatal(1, "source did not reload its seed");
        assert (dut.expected_state === 15'h0001)
        else $fatal(1, "checker did not reload its expected seed");
        checks += 3;
        @(negedge clk);
        load_seed = 1'b0;
        bit_valid = 1'b0;
        corrupt_bit = 1'b0;
    endtask

    task automatic compare_one(input logic inject_error);
        @(negedge clk);
        bit_valid = 1'b1;
        corrupt_bit = inject_error;
        @(posedge clk);
        #1ns;

        compared_scoreboard++;
        if (inject_error)
            error_scoreboard++;

        assert (error_pulse === inject_error)
        else $fatal(1,
                    "comparison %0d: expected error_pulse=%0b, got %0b",
                    compared_scoreboard - 1, inject_error, error_pulse);
        checks++;
    endtask

    task automatic ignore_corrupted_input(input int gap_cycles);
        logic [14:0] held_source_state;
        logic [14:0] held_expected_state;
        int compared_before;
        int errors_before;

        @(negedge clk);
        bit_valid = 1'b0;
        corrupt_bit = 1'b1;
        held_source_state = source_state;
        held_expected_state = dut.expected_state;
        compared_before = compared_scoreboard;
        errors_before = error_scoreboard;

        repeat (gap_cycles) begin
            @(posedge clk);
            #1ns;
            assert (error_pulse === 1'b0)
            else $fatal(1, "invalid corrupted input produced an error pulse");
            assert (source_state === held_source_state)
            else $fatal(1, "source advanced while bit_valid was low");
            assert (dut.expected_state === held_expected_state)
            else $fatal(1, "checker advanced while bit_valid was low");
            checks += 3;
        end

        assert (compared_scoreboard == compared_before &&
                error_scoreboard == errors_before)
        else $fatal(1, "scoreboard changed during invalid input gap");
        checks++;
    endtask

    initial begin : stimulus
        int i;
        int errors_before_restart;

        apply_reset();
        reload_seed();

        // Long direct loopback: every valid received bit must agree with the
        // checker's independently maintained expected sequence.
        for (i = 0; i < CLEAN_BITS; i++)
            compare_one(1'b0);

        assert (compared_scoreboard == CLEAN_BITS && error_scoreboard == 0)
        else $fatal(1, "clean run totals incorrect: compared=%0d errors=%0d",
                    compared_scoreboard, error_scoreboard);
        checks++;

        // Deterministically restart, then flip exactly bits 0, 17, and 999.
        reload_seed();
        compared_scoreboard = 0;
        error_scoreboard = 0;
        for (i = 0; i < 1000; i++)
            compare_one((i == 0) || (i == 17) || (i == 999));

        assert (compared_scoreboard == 1000 && error_scoreboard == 3)
        else $fatal(1, "injection totals incorrect: compared=%0d errors=%0d",
                    compared_scoreboard, error_scoreboard);
        checks++;

        // The cycle following the last injected error is invalid and corrupt.
        // error_pulse must clear, and neither PRBS state may advance.
        ignore_corrupted_input(3);

        // A mid-run reload realigns both sides. Subsequent clean bits must not
        // add any new errors.
        errors_before_restart = error_scoreboard;
        reload_seed();
        repeat (64)
            compare_one(1'b0);
        assert (error_scoreboard == errors_before_restart)
        else $fatal(1, "clean comparisons after reload added errors");
        checks++;

        // Counter reset policy is represented by the external scoreboard
        // because this checker intentionally has no internal counters.
        apply_reset();
        assert (compared_scoreboard == 0 && error_scoreboard == 0)
        else $fatal(1, "testbench counters did not reset");
        checks++;

        $display("PASS: tb_prbs15_check verified %0d clean bits and exact flips at 0,17,999; checks=%0d",
                 CLEAN_BITS, checks);
        $finish;
    end

    initial begin
        #2ms;
        $fatal(1, "tb_prbs15_check timed out");
    end

endmodule
