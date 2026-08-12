`timescale 1ns/1ps

module tb_clock_enable_gen;

    localparam time CLK_PERIOD = 10ns;
    localparam int DIVISOR_A = 4;
    localparam int DIVISOR_B = 7;
    localparam int REQUIRED_PULSES = 21; // first pulse plus 20 intervals

    logic clk = 1'b0;
    logic rst = 1'b1;
    logic enable_a;
    logic enable_b;

    int checks = 0;

    clock_enable_gen #(
        .DIVISOR(DIVISOR_A)
    ) dut_div4 (
        .clk    (clk),
        .rst    (rst),
        .enable (enable_a)
    );

    clock_enable_gen #(
        .DIVISOR(DIVISOR_B)
    ) dut_div7 (
        .clk    (clk),
        .rst    (rst),
        .enable (enable_b)
    );

    always #(CLK_PERIOD / 2) clk = ~clk;

    task automatic check_restart(
        input int divisor,
        input bit select_a,
        input string instance_name
    );
        int cycles;
        begin
            cycles = 0;
            while (!(select_a ? enable_a : enable_b)) begin
                @(posedge clk);
                #1ns;
                cycles++;
                assert (cycles <= divisor)
                else $fatal(1, "%s missed its first pulse after reset", instance_name);
            end
            assert (cycles == divisor)
            else $fatal(1, "%s restarted after %0d cycles; expected %0d",
                        instance_name, cycles, divisor);
            checks++;
        end
    endtask

    initial begin : stimulus_and_scoreboard
        int cycle;
        int pulses_a;
        int pulses_b;
        int last_pulse_a;
        int last_pulse_b;
        logic previous_a;
        logic previous_b;

        // Establish reset, then release it away from a rising clock edge.
        #1ns;
        assert (enable_a === 1'b0 && enable_b === 1'b0)
        else $fatal(1, "enables were not cleared by reset");
        @(negedge clk);
        rst = 1'b0;

        // Interrupt both counters mid-count. This design uses asynchronous
        // active-high reset, so both enables must clear immediately. After
        // release, the first pulse must take a complete DIVISOR interval.
        repeat (2) @(posedge clk);
        #2ns rst = 1'b1;
        #1ns;
        assert (enable_a === 1'b0 && enable_b === 1'b0)
        else $fatal(1, "mid-count reset did not immediately clear enables");
        checks++;

        @(negedge clk);
        rst = 1'b0;

        fork
            check_restart(DIVISOR_A, 1'b1, "DIVISOR=4");
            check_restart(DIVISOR_B, 1'b0, "DIVISOR=7");
        join

        // Restart once more so both scoreboards share a precise cycle zero.
        #2ns rst = 1'b1;
        #1ns;
        @(negedge clk);
        rst = 1'b0;

        cycle = 0;
        pulses_a = 0;
        pulses_b = 0;
        last_pulse_a = 0;
        last_pulse_b = 0;
        previous_a = 1'b0;
        previous_b = 1'b0;

        while (pulses_a < REQUIRED_PULSES || pulses_b < REQUIRED_PULSES) begin
            @(posedge clk);
            #1ns; // sample after nonblocking assignments update
            cycle++;

            assert (!(enable_a && previous_a))
            else $fatal(1, "DIVISOR=4 enable was high on adjacent cycles");
            assert (!(enable_b && previous_b))
            else $fatal(1, "DIVISOR=7 enable was high on adjacent cycles");
            checks += 2;

            if (enable_a) begin
                pulses_a++;
                assert ((cycle - last_pulse_a) == DIVISOR_A)
                else $fatal(1, "DIVISOR=4 interval was %0d, expected %0d",
                            cycle - last_pulse_a, DIVISOR_A);
                checks++;
                last_pulse_a = cycle;
            end

            if (enable_b) begin
                pulses_b++;
                assert ((cycle - last_pulse_b) == DIVISOR_B)
                else $fatal(1, "DIVISOR=7 interval was %0d, expected %0d",
                            cycle - last_pulse_b, DIVISOR_B);
                checks++;
                last_pulse_b = cycle;
            end

            previous_a = enable_a;
            previous_b = enable_b;
        end

        assert (pulses_a >= REQUIRED_PULSES && pulses_b >= REQUIRED_PULSES)
        else $fatal(1, "scoreboard ended before collecting enough pulses");

        $display("PASS: tb_clock_enable_gen checked %0d DIV4 pulses, %0d DIV7 pulses, %0d assertions",
                 pulses_a, pulses_b, checks);
        $finish;
    end

    initial begin
        #5us;
        $fatal(1, "tb_clock_enable_gen timed out");
    end

endmodule
