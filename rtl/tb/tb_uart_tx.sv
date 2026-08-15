`timescale 1ns/1ps

module tb_uart_tx;

localparam time CLK_PERIOD = 10ns;
localparam int unsigned CLOCK_HZ = 100;
localparam int unsigned BAUD = 10;
localparam int unsigned CLKS_PER_BIT = 10;

logic clk = 1'b0;
logic rst = 1'b1;
logic data_valid = 1'b0;
logic [7:0] data_byte = 8'b0;
logic data_ready;
logic tx;
logic busy;
int checks = 0;

uart_tx #(
    .CLOCK_HZ(CLOCK_HZ),
    .BAUD(BAUD)
) dut(
    .clk(clk),
    .rst(rst),
    .data_valid(data_valid),
    .data_byte(data_byte),
    .data_ready(data_ready),
    .tx(tx),
    .busy(busy)
);

always #(CLK_PERIOD / 2) clk = ~clk;

task automatic expect_level_for_clocks(
    input logic expected_level,
    input int clock_count,
    input string field_name
);
begin
    for (int cycle = 0; cycle < clock_count; cycle++) begin
        @(negedge clk);
        #1ns;
        assert (tx == expected_level)
        else $fatal(1, "%s duration/data mismatch at cycle %0d", field_name, cycle);
        checks++;
    end
end
endtask

task automatic send_and_decode(input logic [7:0] value);
begin
    @(negedge clk);
    data_byte = value;
    data_valid = 1'b1;
    wait (data_ready);
    @(posedge clk);
    @(negedge clk);
    data_valid = 1'b0;
    #1ns;
    assert (busy && !tx)
    else $fatal(1, "UART did not enter start bit for %02h", value);
    checks++;

    for (int cycle = 1; cycle < CLKS_PER_BIT; cycle++) begin
        @(negedge clk);
        #1ns;
        assert (!tx)
        else $fatal(1, "start bit was not exactly %0d clocks", CLKS_PER_BIT);
        checks++;
    end

    for (int bit_number = 0; bit_number < 8; bit_number++) begin
        expect_level_for_clocks(value[bit_number], CLKS_PER_BIT, "data bit");
    end

    expect_level_for_clocks(1'b1, CLKS_PER_BIT, "stop bit");
    @(posedge clk);
    #1ns;
    assert (data_ready && !busy && tx)
    else $fatal(1, "UART did not return to idle after %02h", value);
    checks++;
end
endtask

task automatic decode_wire_byte(input logic [7:0] expected_value);
begin
    @(negedge tx);
    repeat (CLKS_PER_BIT / 2) @(posedge clk);
    #1ns;
    assert (!tx)
    else $fatal(1, "independent decoder missed start bit");
    checks++;

    for (int bit_number = 0; bit_number < 8; bit_number++) begin
        repeat (CLKS_PER_BIT) @(posedge clk);
        #1ns;
        assert (tx == expected_value[bit_number])
        else $fatal(1, "independent decoder mismatch bit=%0d expected_byte=%02h", bit_number, expected_value);
        checks++;
    end

    repeat (CLKS_PER_BIT) @(posedge clk);
    #1ns;
    assert (tx)
    else $fatal(1, "independent decoder saw an invalid stop bit");
    checks++;
end
endtask

initial begin
    repeat (2) @(posedge clk);
    @(negedge clk);
    rst = 1'b0;
    @(posedge clk);
    #1ns;
    assert (data_ready && tx && !busy)
    else $fatal(1, "UART reset/idle contract failed");
    checks++;

    send_and_decode(8'h00);
    send_and_decode(8'hff);
    send_and_decode(8'h55);
    send_and_decode(8'ha6);

    // Hold valid while busy. The independent decoder must receive both bytes
    // in order, proving that the first registered byte cannot be overwritten.
    fork
        begin
            @(negedge clk);
            data_byte = 8'h3c;
            data_valid = 1'b1;
            @(posedge clk);
            @(negedge clk);
            data_byte = 8'hc3;
            wait (data_ready);
            @(posedge clk);
            @(negedge clk);
            data_valid = 1'b0;
        end
        begin
            decode_wire_byte(8'h3c);
            decode_wire_byte(8'hc3);
        end
    join

    // Asynchronous reset during a byte must immediately restore idle-high TX.
    @(negedge clk);
    data_byte = 8'ha6;
    data_valid = 1'b1;
    wait (data_ready);
    @(posedge clk);
    @(negedge clk);
    data_valid = 1'b0;
    repeat (4) @(posedge clk);
    #1ns;
    rst = 1'b1;
    #1ns;
    assert (tx && !busy && data_ready)
    else $fatal(1, "reset during a byte did not force idle-high");
    checks++;
    repeat (2) @(posedge clk);
    @(negedge clk);
    rst = 1'b0;

    $display("PASS: tb_uart_tx checks=%0d clocks_per_bit=%0d bytes=6", checks, CLKS_PER_BIT);
    $finish;
end

initial begin
    #200us;
    $fatal(1, "tb_uart_tx timed out");
end

endmodule
