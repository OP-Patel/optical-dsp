`timescale 1ns/1ps

module tb_sample_capture;

localparam time CLK_PERIOD = 10ns;
localparam int unsigned DEPTH = 16;
localparam int unsigned INDEX_WIDTH = 16;

logic clk = 1'b0;
logic rst = 1'b1;
logic arm = 1'b0;
logic trigger = 1'b0;
logic sample_valid = 1'b0;
logic [11:0] sample_u12 = 12'b0;
logic [INDEX_WIDTH-1:0] sample_index = 16'b0;
logic [$clog2(DEPTH)-1:0] read_address = '0;
logic [11:0] read_data;
logic capture_armed;
logic capture_busy;
logic capture_done;
logic trigger_rejected;
logic [INDEX_WIDTH-1:0] capture_start_index;
logic [15:0] capture_count;
int checks = 0;

sample_capture #(
    .DEPTH(DEPTH),
    .INDEX_WIDTH(INDEX_WIDTH)
) dut(
    .clk(clk),
    .rst(rst),
    .arm(arm),
    .trigger(trigger),
    .sample_valid(sample_valid),
    .sample_u12(sample_u12),
    .sample_index(sample_index),
    .read_address(read_address),
    .read_data(read_data),
    .capture_armed(capture_armed),
    .capture_busy(capture_busy),
    .capture_done(capture_done),
    .trigger_rejected(trigger_rejected),
    .capture_start_index(capture_start_index),
    .capture_count(capture_count)
);

always #(CLK_PERIOD / 2) clk = ~clk;

task automatic pulse_arm;
begin
    @(negedge clk);
    arm = 1'b1;
    @(negedge clk);
    arm = 1'b0;
end
endtask

task automatic pulse_trigger;
begin
    @(negedge clk);
    trigger = 1'b1;
    @(negedge clk);
    trigger = 1'b0;
end
endtask

task automatic send_sample(
    input logic [11:0] value,
    input logic [INDEX_WIDTH-1:0] index_value,
    input int gap_clocks
);
begin
    repeat (gap_clocks) @(posedge clk);
    @(negedge clk);
    sample_u12 = value;
    sample_index = index_value;
    sample_valid = 1'b1;
    @(negedge clk);
    sample_valid = 1'b0;
end
endtask

initial begin
    repeat (2) @(posedge clk);
    @(negedge clk);
    rst = 1'b0;

    // Triggering before arm is rejected and does not begin capture.
    pulse_trigger();
    assert (trigger_rejected && !capture_busy && !capture_done)
    else $fatal(1, "unarmed trigger was not rejected");
    checks++;

    pulse_arm();
    assert (capture_armed && !trigger_rejected)
    else $fatal(1, "arm did not prepare an empty capture");
    checks++;
    pulse_trigger();
    assert (capture_busy)
    else $fatal(1, "trigger did not begin capture");
    checks++;

    for (int sample_number = 0; sample_number < DEPTH; sample_number++) begin
        send_sample(12'h100 + sample_number, 16'd500 + sample_number, sample_number % 3);

        if (sample_number == 3) begin
            pulse_trigger();
            assert (trigger_rejected && capture_busy)
            else $fatal(1, "trigger during capture was not rejected safely");
            checks++;
        end
    end

    @(posedge clk);
    #1ns;
    assert (capture_done && !capture_busy && capture_count == DEPTH)
    else $fatal(1, "capture did not freeze at the configured depth");
    assert (capture_start_index == 500)
    else $fatal(1, "capture start index was incorrect");
    checks += 2;

    for (int address = 0; address < DEPTH; address++) begin
        @(negedge clk);
        read_address = address;
        @(posedge clk);
        #1ns;
        assert (read_data == 12'h100 + address)
        else $fatal(1, "capture memory mismatch at address %0d", address);
        checks++;
    end

    // Reset from complete returns to idle and clears visible status.
    rst = 1'b1;
    @(posedge clk);
    #1ns;
    assert (!capture_armed && !capture_busy && !capture_done && !trigger_rejected)
    else $fatal(1, "reset from complete did not clear capture status");
    checks++;
    repeat (2) @(posedge clk);
    @(negedge clk);
    rst = 1'b0;

    // Reset while armed and while capturing.
    pulse_arm();
    rst = 1'b1;
    @(posedge clk);
    #1ns;
    assert (!capture_armed)
    else $fatal(1, "reset while armed failed");
    checks++;
    @(negedge clk);
    rst = 1'b0;
    pulse_arm();
    pulse_trigger();
    send_sample(12'habc, 16'd900, 0);
    rst = 1'b1;
    @(posedge clk);
    #1ns;
    assert (!capture_busy && !capture_done && capture_count == 0)
    else $fatal(1, "reset while capturing failed");
    checks++;

    $display("PASS: tb_sample_capture checks=%0d depth=%0d", checks, DEPTH);
    $finish;
end

initial begin
    #100us;
    $fatal(1, "tb_sample_capture timed out");
end

endmodule
