`timescale 1ns/1ps

module tb_async_input_sync;

logic clk = 1'b0;
logic rst = 1'b1;
logic async_in = 1'b0;
logic sync_out;
int checks = 0;

async_input_sync dut(
    .clk(clk),
    .rst(rst),
    .async_in(async_in),
    .sync_out(sync_out)
);

always #5ns clk = ~clk;

initial begin
    repeat (2) @(posedge clk);
    #1ns;
    assert (!sync_out)
    else $fatal(1, "reset output was not low");
    checks++;

    @(negedge clk);
    rst = 1'b0;
    #2ns;
    async_in = 1'b1;
    #1ns;
    assert (!sync_out)
    else $fatal(1, "output changed asynchronously");
    checks++;

    @(posedge clk);
    #1ns;
    assert (!sync_out)
    else $fatal(1, "output changed after only one stage");
    checks++;

    @(posedge clk);
    #1ns;
    assert (sync_out)
    else $fatal(1, "high did not propagate after two stages");
    checks++;

    @(negedge clk);
    async_in = 1'b0;
    @(posedge clk);
    #1ns;
    assert (sync_out)
    else $fatal(1, "low changed after only one stage");
    checks++;

    @(posedge clk);
    #1ns;
    assert (!sync_out)
    else $fatal(1, "low did not propagate after two stages");
    checks++;

    rst = 1'b1;
    @(posedge clk);
    #1ns;
    assert (!sync_out)
    else $fatal(1, "reset did not clear synchronized output");
    checks++;

    $display("PASS: tb_async_input_sync checks=%0d", checks);
    $finish;
end

endmodule
