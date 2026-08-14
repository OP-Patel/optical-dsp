`timescale 1ns/1ps

module tb_xadc_drp_controller;

localparam time CLK_PERIOD = 10ns;
localparam int unsigned TIMEOUT_CYCLES = 12;
localparam int unsigned INDEX_WIDTH = 8;

logic clk = 1'b0;
logic rst = 1'b1;
logic model_conversion_valid = 1'b0;
logic [11:0] model_code = 12'b0;
logic [7:0] response_delay = 8'b0;
logic stall_drdy = 1'b0;
logic xadc_eoc;
logic xadc_drdy;
logic [15:0] xadc_do;
logic xadc_den;
logic [6:0] xadc_daddr;
logic model_busy;
logic model_protocol_error;
logic [11:0] sample_u12;
logic sample_valid;
logic [INDEX_WIDTH-1:0] sample_index;
logic xadc_busy;
logic xadc_fault;
int checks = 0;
int valid_pulses = 0;
int den_pulses = 0;
logic previous_sample_valid = 1'b0;

xadc_model model_inst(
    .clk(clk),
    .rst(rst),
    .model_conversion_valid(model_conversion_valid),
    .model_code(model_code),
    .response_delay(response_delay),
    .stall_drdy(stall_drdy),
    .drp_den(xadc_den),
    .drp_daddr(xadc_daddr),
    .xadc_eoc(xadc_eoc),
    .xadc_drdy(xadc_drdy),
    .xadc_do(xadc_do),
    .model_busy(model_busy),
    .model_protocol_error(model_protocol_error)
);

xadc_drp_controller #(
    .TIMEOUT_CYCLES(TIMEOUT_CYCLES),
    .INDEX_WIDTH(INDEX_WIDTH)
) dut(
    .clk(clk),
    .rst(rst),
    .xadc_eoc(xadc_eoc),
    .xadc_drdy(xadc_drdy),
    .xadc_do(xadc_do),
    .xadc_den(xadc_den),
    .xadc_daddr(xadc_daddr),
    .sample_u12(sample_u12),
    .sample_valid(sample_valid),
    .sample_index(sample_index),
    .xadc_busy(xadc_busy),
    .xadc_fault(xadc_fault)
);

always #(CLK_PERIOD / 2) clk = ~clk;

always @(posedge clk) begin
    #1ns;
    if (rst)
        previous_sample_valid = 1'b0;

    if (sample_valid)
        valid_pulses++;
    if (xadc_den)
        den_pulses++;

    if (!rst) begin
        assert (!(sample_valid && previous_sample_valid))
        else $fatal(1, "sample_valid lasted more than one clock");
        assert (!xadc_den || xadc_daddr == 7'h14)
        else $fatal(1, "controller requested the wrong DRP address");
    end

    previous_sample_valid = sample_valid;
end

task automatic apply_reset;
begin
    @(negedge clk);
    rst = 1'b1;
    repeat (2) @(posedge clk);
    @(negedge clk);
    rst = 1'b0;
    @(posedge clk);
    #1ns;
end
endtask

task automatic start_conversion(
    input logic [11:0] code,
    input logic [7:0] delay
);
begin
    @(negedge clk);
    model_code = code;
    response_delay = delay;
    model_conversion_valid = 1'b1;
    @(negedge clk);
    model_conversion_valid = 1'b0;
end
endtask

task automatic expect_sample(
    input logic [11:0] expected_code,
    input logic [INDEX_WIDTH-1:0] expected_index
);
begin
    wait (sample_valid == 1'b1);
    #1ns;
    assert (sample_u12 == expected_code)
    else $fatal(1, "sample mismatch expected=%03h actual=%03h", expected_code, sample_u12);
    assert (sample_index == expected_index)
    else $fatal(1, "index mismatch expected=%0d actual=%0d", expected_index, sample_index);
    assert (xadc_do[15:4] == expected_code && xadc_do[3:0] == 4'b0)
    else $fatal(1, "model returned incorrectly packed XADC data");
    assert (!model_protocol_error)
    else $fatal(1, "model detected a DRP protocol error");
    checks += 4;
    @(posedge clk);
    #1ns;
    assert (!sample_valid)
    else $fatal(1, "sample_valid did not clear after one clock");
    checks++;
end
endtask

initial begin : stimulus
    int valid_before;
    int den_before;

    apply_reset();
    assert (!sample_valid && !xadc_busy && !xadc_fault && sample_index == 0)
    else $fatal(1, "reset state was incorrect");
    checks++;

    start_conversion(12'h000, 0);
    expect_sample(12'h000, 0);

    start_conversion(12'h001, 1);
    expect_sample(12'h001, 1);

    start_conversion(12'h800, 4);
    expect_sample(12'h800, 2);

    start_conversion(12'hfff, TIMEOUT_CYCLES-3);
    expect_sample(12'hfff, 3);

    valid_before = valid_pulses;
    den_before = den_pulses;
    for (int i = 0; i < 300; i++) begin
        start_conversion((i * 37) & 12'hfff, i % 5);
        expect_sample((i * 37) & 12'hfff, i + 4);
    end
    assert (valid_pulses == valid_before + 300)
    else $fatal(1, "long run duplicated or dropped valid events");
    assert (den_pulses == den_before + 300)
    else $fatal(1, "long run issued an incorrect number of DRP reads");
    assert (sample_index == 8'd47)
    else $fatal(1, "8-bit index did not follow the documented rollover policy");
    checks += 3;

    // A second EOC while waiting for one DRP response must set sticky fault.
    start_conversion(12'h123, 6);
    wait (xadc_busy);
    start_conversion(12'h456, 1);
    @(posedge clk);
    #1ns;
    assert (xadc_fault)
    else $fatal(1, "overrun did not set sticky fault");
    checks++;

    apply_reset();
    assert (!xadc_fault && !xadc_busy && !sample_valid)
    else $fatal(1, "reset did not clear overrun state");
    checks++;

    // Missing DRDY must time out and remain visible until reset.
    stall_drdy = 1'b1;
    start_conversion(12'habc, 2);
    wait (xadc_busy);
    repeat (TIMEOUT_CYCLES + 2) @(posedge clk);
    #1ns;
    assert (xadc_fault && !xadc_busy && !sample_valid)
    else $fatal(1, "DRP stall did not produce a sticky timeout fault");
    checks++;
    stall_drdy = 1'b0;

    apply_reset();

    // Reset during an outstanding read must cancel it without a late sample.
    start_conversion(12'h789, 10);
    wait (xadc_busy);
    valid_before = valid_pulses;
    @(negedge clk);
    rst = 1'b1;
    repeat (2) @(posedge clk);
    @(negedge clk);
    rst = 1'b0;
    repeat (14) @(posedge clk);
    #1ns;
    assert (!xadc_busy && !xadc_fault && !sample_valid)
    else $fatal(1, "reset during a read did not restore idle state");
    assert (valid_pulses == valid_before)
    else $fatal(1, "a canceled read produced a late sample");
    assert (sample_index == 0)
    else $fatal(1, "reset did not restart sample indexing");
    assert (!model_protocol_error)
    else $fatal(1, "model protocol error occurred");
    checks += 4;

    $display("PASS: tb_xadc_drp_controller checks=%0d valid_pulses=%0d den_pulses=%0d", checks, valid_pulses, den_pulses);
    $finish;
end

initial begin
    #250us;
    $fatal(1, "tb_xadc_drp_controller timed out");
end

endmodule
