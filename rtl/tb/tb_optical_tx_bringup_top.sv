`timescale 1ns/1ps

module tb_optical_tx_bringup_top;

localparam time CLK_PERIOD = 10ns;
localparam int SYMBOL_DIVISOR = 4;
localparam logic [1:0] MODE_OFF = 2'b00;
localparam logic [1:0] MODE_ON = 2'b01;
localparam logic [1:0] MODE_TRAINING = 2'b10;
localparam logic [1:0] MODE_FRAMED = 2'b11;

logic clk_100mhz = 1'b0;
logic reset_btn = 1'b1;
logic tx_enable = 1'b0;
logic [1:0] mode = MODE_OFF;
logic daoki_rx_async = 1'b0;
logic fault;
logic laser_drive;
logic daoki_rx_led;
int checks = 0;

optical_tx_bringup_top #(
    .SYMBOL_DIVISOR(SYMBOL_DIVISOR)
) dut(
    .clk_100mhz(clk_100mhz),
    .reset_btn(reset_btn),
    .tx_enable(tx_enable),
    .mode(mode),
    .daoki_rx_async(daoki_rx_async),
    .fault(fault),
    .laser_drive(laser_drive),
    .daoki_rx_led(daoki_rx_led)
);

always #(CLK_PERIOD / 2) clk_100mhz = ~clk_100mhz;

task automatic wait_symbol;
begin
    do begin
        @(negedge clk_100mhz);
    end while (!dut.symbol_ce);
    @(posedge clk_100mhz);
    #1ns;
    @(negedge clk_100mhz);
end
endtask

task automatic release_reset;
begin
    repeat (2) @(posedge clk_100mhz);
    @(negedge clk_100mhz);
    reset_btn = 1'b0;
    wait (dut.rst == 1'b0);
    @(negedge clk_100mhz);
end
endtask

task automatic settle_switches;
begin
    repeat (3) @(posedge clk_100mhz);
    #1ns;
end
endtask

initial begin : stimulus
    logic previous_bit;
    logic expected_preamble;
    int i;

    // Raw reset must immediately force the internal reset and guarded output.
    #1ns;
    assert (dut.rst && !laser_drive && !fault)
    else $fatal(1, "power-up reset did not produce a safe output");
    checks++;
    release_reset();

    // The asynchronous DAOKI diagnostic input appears at the LED only after
    // the two synchronizer stages and changes only on a clock edge.
    @(negedge clk_100mhz);
    daoki_rx_async = 1'b1;
    #2ns;
    assert (!daoki_rx_led)
    else $fatal(1, "diagnostic input changed without a clock edge");
    checks++;
    @(posedge clk_100mhz);
    #1ns;
    assert (!daoki_rx_led)
    else $fatal(1, "diagnostic input skipped the second synchronizer stage");
    checks++;
    @(posedge clk_100mhz);
    #1ns;
    assert (daoki_rx_led)
    else $fatal(1, "diagnostic input did not propagate through two stages");
    checks++;

    @(negedge clk_100mhz);
    daoki_rx_async = 1'b0;
    repeat (2) @(posedge clk_100mhz);
    #1ns;
    assert (!daoki_rx_led)
    else $fatal(1, "diagnostic input did not return low through two stages");
    checks++;

    // SW0 disabled: every mode must remain physically off.
    tx_enable = 1'b0;
    for (int selected_mode = 0; selected_mode < 4; selected_mode++) begin
        mode = selected_mode;
        settle_switches();
        for (i = 0; i < 12; i++) begin
            wait_symbol();
            #1ns;
            assert (!laser_drive)
            else $fatal(1, "disabled output went high in mode %0d", selected_mode);
            assert (fault === dut.tx_bit)
            else $fatal(1, "fault did not report blocked tx_bit in mode %0d", selected_mode);
            checks += 2;
        end
    end

    // OFF: safe low even when SW0 enables the output.
    tx_enable = 1'b1;
    mode = MODE_OFF;
    settle_switches();
    repeat (12) begin
        wait_symbol();
        #1ns;
        assert (!laser_drive && !fault)
        else $fatal(1, "OFF mode was not low and fault-free");
        checks++;
    end

    // ON: high continuously while enabled.
    mode = MODE_ON;
    settle_switches();
    assert (laser_drive && !fault)
    else $fatal(1, "ON mode did not drive high");
    checks++;
    repeat (12) begin
        wait_symbol();
        #1ns;
        assert (laser_drive && !fault)
        else $fatal(1, "ON mode did not remain high");
        checks++;
    end

    // TRAINING: starts at one and changes at every symbol enable.
    mode = MODE_TRAINING;
    settle_switches();
    assert (laser_drive)
    else $fatal(1, "TRAINING did not start at one");
    checks++;
    previous_bit = laser_drive;
    for (i = 0; i < 20; i++) begin
        wait_symbol();
        #1ns;
        assert (laser_drive === ~previous_bit)
        else $fatal(1, "TRAINING did not alternate at symbol %0d", i);
        assert (!fault)
        else $fatal(1, "enabled TRAINING asserted fault");
        previous_bit = laser_drive;
        checks += 2;
    end

    // FRAMED: leaving TRAINING parks the framer, so entering mode 11 starts
    // with the exact alternating preamble on the first 32 symbol events.
    mode = MODE_OFF;
    settle_switches();
    @(negedge clk_100mhz);
    while (dut.symbol_ce)
        @(negedge clk_100mhz);
    mode = MODE_FRAMED;
    settle_switches();
    for (i = 0; i < 32; i++) begin
        expected_preamble = (i % 2) == 0;
        #1ns;
        assert (laser_drive === expected_preamble)
        else $fatal(1, "FRAMED preamble mismatch at bit %0d", i);
        assert (!fault)
        else $fatal(1, "enabled FRAMED asserted fault");
        checks += 2;
        wait_symbol();
    end

    // Turning SW0 off must suppress an ON request immediately, without waiting
    // for symbol_ce, and light the live fault indicator.
    mode = MODE_ON;
    tx_enable = 1'b1;
    settle_switches();
    assert (laser_drive)
    else $fatal(1, "mode-change setup failed");
    tx_enable = 1'b0;
    #1ns;
    assert (!laser_drive && fault)
    else $fatal(1, "SW0 did not block the output immediately");
    checks++;

    // BTN0 must also suppress the output immediately and clear the live fault.
    reset_btn = 1'b1;
    #1ns;
    assert (!laser_drive && !fault && dut.rst)
    else $fatal(1, "BTN0 did not force a safe output immediately");
    checks++;

    $display("PASS: tb_optical_tx_bringup_top checks=%0d divisor=%0d", checks, SYMBOL_DIVISOR);
    $finish;
end

initial begin
    #100us;
    $fatal(1, "tb_optical_tx_bringup_top timed out");
end

endmodule
