`timescale 1ns/1ps

module tb_laser_output_guard;

logic rst;
logic tx_bit;
logic tx_enable;
logic fault;
logic laser_drive;
int checks = 0;

laser_output_guard dut(
    .rst(rst),
    .tx_bit(tx_bit),
    .tx_enable(tx_enable),
    .fault(fault),
    .laser_drive(laser_drive)
);

task automatic check_guard(
    input logic test_rst,
    input logic test_enable,
    input logic test_bit
);
    logic expected_fault;
    logic expected_drive;
begin
    rst = test_rst;
    tx_enable = test_enable;
    tx_bit = test_bit;
    #1ns;

    expected_fault = ~test_rst & ~test_enable & test_bit;
    expected_drive = ~test_rst & test_enable & test_bit;

    assert (fault === expected_fault)
    else $fatal(1, "fault mismatch: rst=%0b enable=%0b bit=%0b expected=%0b got=%0b",
                test_rst, test_enable, test_bit, expected_fault, fault);
    assert (laser_drive === expected_drive)
    else $fatal(1, "drive mismatch: rst=%0b enable=%0b bit=%0b expected=%0b got=%0b",
                test_rst, test_enable, test_bit, expected_drive, laser_drive);
    assert (!(laser_drive && (!tx_enable || rst)))
    else $fatal(1, "forbidden condition produced laser_drive=1");
    checks += 3;
end
endtask

initial begin
    for (int reset_value = 0; reset_value < 2; reset_value++) begin
        for (int enable_value = 0; enable_value < 2; enable_value++) begin
            for (int bit_value = 0; bit_value < 2; bit_value++) begin
                check_guard(reset_value, enable_value, bit_value);
            end
        end
    end

    // Prove the guard reacts combinationally without waiting for a clock.
    rst = 1'b0;
    tx_enable = 1'b1;
    tx_bit = 1'b0;
    #1ns;
    tx_bit = 1'b1;
    #1ns;
    assert (laser_drive && !fault)
    else $fatal(1, "tx_bit did not propagate combinationally while enabled");
    checks++;

    tx_enable = 1'b0;
    #1ns;
    assert (!laser_drive && fault)
    else $fatal(1, "disable did not block combinationally");
    checks++;

    rst = 1'b1;
    #1ns;
    assert (!laser_drive && !fault)
    else $fatal(1, "reset did not force the safe combinational state");
    checks++;

    $display("PASS: tb_laser_output_guard checks=%0d combinations=8", checks);
    $finish;
end

endmodule
