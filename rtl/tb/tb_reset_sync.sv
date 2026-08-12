`timescale 1ns/1ps

module tb_reset_sync;

    localparam time CLK_PERIOD = 10ns;

    logic clk = 1'b0;
    logic async_reset_in = 1'b0;
    logic rst;

    int checks = 0;

    reset_sync dut (
        .clk            (clk),
        .async_reset_in (async_reset_in),
        .rst            (rst)
    );

    always #(CLK_PERIOD / 2) clk = ~clk;

    task automatic expect_rst(input logic expected, input string message);
        #1ns;
        assert (rst === expected)
        else $fatal(1, "%s: expected rst=%0b, got %0b at %0t",
                    message, expected, rst, $time);
        checks++;
    endtask

    // Exercise asynchronous assertion at a chosen offset after a falling edge.
    task automatic check_assertion(input time offset);
        @(negedge clk);
        #(offset);
        async_reset_in = 1'b1;
        expect_rst(1'b1, "reset did not assert asynchronously");

        // Hold reset through a clock edge to confirm it stays asserted.
        @(posedge clk);
        expect_rst(1'b1, "reset did not remain asserted");
    endtask

    // Release at a chosen offset after a falling edge. Regardless of phase,
    // rst must stay high through the first rising edge and fall on the second.
    task automatic check_release(input time offset);
        @(negedge clk);
        #(offset);
        async_reset_in = 1'b0;

        expect_rst(1'b1, "reset deasserted without a clock edge");
        @(posedge clk);
        expect_rst(1'b1, "reset deasserted before stage two");
        @(posedge clk);
        expect_rst(1'b0, "reset did not deassert after two stages");

        // A deassert/reassert glitch would be visible during these cycles.
        repeat (4) begin
            @(posedge clk);
            expect_rst(1'b0, "reset glitched after deassertion");
        end
    endtask

    initial begin
        // Assertions occur 4 ns before, 1 ns before, and 1 ns after a rising
        // edge. Releases exercise both sides of a rising edge as well.
        check_assertion(1ns);
        check_release(3ns);

        check_assertion(4ns);
        check_release(6ns);

        check_assertion(6ns);
        check_release(3ns);

        $display("PASS: tb_reset_sync completed %0d checks", checks);
        $finish;
    end

    initial begin
        #2us;
        $fatal(1, "tb_reset_sync timed out");
    end

endmodule
