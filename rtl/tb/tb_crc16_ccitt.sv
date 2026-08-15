`timescale 1ns/1ps

module tb_crc16_ccitt;

localparam time CLK_PERIOD = 10ns;

logic clk = 1'b0;
logic rst = 1'b1;
logic clear = 1'b0;
logic data_valid = 1'b0;
logic [7:0] data_byte = 8'b0;
logic [15:0] crc;
int checks = 0;

crc16_ccitt dut(
    .clk(clk),
    .rst(rst),
    .clear(clear),
    .data_valid(data_valid),
    .data_byte(data_byte),
    .crc(crc)
);

always #(CLK_PERIOD / 2) clk = ~clk;

task automatic send_byte(input logic [7:0] value);
begin
    @(negedge clk);
    data_byte = value;
    data_valid = 1'b1;
    @(negedge clk);
    data_valid = 1'b0;
end
endtask

initial begin
    repeat (2) @(posedge clk);
    @(negedge clk);
    rst = 1'b0;
    @(posedge clk);
    #1ns;
    assert (crc == 16'hffff)
    else $fatal(1, "CRC reset value was incorrect");
    checks++;

    send_byte("1");
    send_byte("2");
    send_byte("3");
    send_byte("4");
    send_byte("5");
    send_byte("6");
    send_byte("7");
    send_byte("8");
    send_byte("9");
    @(posedge clk);
    #1ns;
    assert (crc == 16'h29b1)
    else $fatal(1, "CRC check vector mismatch expected=29b1 actual=%04h", crc);
    checks++;

    @(negedge clk);
    clear = 1'b1;
    @(negedge clk);
    clear = 1'b0;
    @(posedge clk);
    #1ns;
    assert (crc == 16'hffff)
    else $fatal(1, "CRC clear did not restore ffff");
    checks++;

    repeat (5) @(posedge clk);
    #1ns;
    assert (crc == 16'hffff)
    else $fatal(1, "CRC changed without data_valid");
    checks++;

    $display("PASS: tb_crc16_ccitt checks=%0d vector=123456789 crc=%04h", checks, 16'h29b1);
    $finish;
end

initial begin
    #10us;
    $fatal(1, "tb_crc16_ccitt timed out");
end

endmodule
