module xadc_bringup_top #(
    parameter int unsigned XADC_TIMEOUT_CYCLES = 256,
    parameter int unsigned ACTIVITY_TOGGLE_SAMPLES = 65_536
)(
    input logic clk_100mhz,
    input logic reset_btn,
    input logic vaux4_p,
    input logic vaux4_n,

    output logic sample_seen_led,
    output logic sample_activity_led,
    output logic xadc_fault_led,
    output logic sample_level_led
);

localparam int unsigned ACTIVITY_COUNTER_WIDTH = (ACTIVITY_TOGGLE_SAMPLES <= 1) ? 1 : $clog2(ACTIVITY_TOGGLE_SAMPLES);

logic rst;
logic xadc_eoc;
logic xadc_drdy;
logic [15:0] xadc_do;
logic xadc_den;
logic [6:0] xadc_daddr;
logic xadc_primitive_busy;
logic xadc_controller_busy;
logic [11:0] sample_u12;
logic sample_valid;
logic [63:0] sample_index;
logic xadc_fault;
logic [ACTIVITY_COUNTER_WIDTH-1:0] activity_counter;

reset_sync reset_sync_inst(
    .clk(clk_100mhz),
    .async_reset_in(reset_btn),
    .rst(rst)
);

xadc_single_channel xadc_single_channel_inst(
    .clk(clk_100mhz),
    .rst(rst),
    .vaux4_p(vaux4_p),
    .vaux4_n(vaux4_n),
    .drp_den(xadc_den),
    .drp_daddr(xadc_daddr),
    .xadc_eoc(xadc_eoc),
    .xadc_drdy(xadc_drdy),
    .xadc_do(xadc_do),
    .xadc_primitive_busy(xadc_primitive_busy)
);

xadc_drp_controller #(
    .TIMEOUT_CYCLES(XADC_TIMEOUT_CYCLES),
    .INDEX_WIDTH(64)
) xadc_drp_controller_inst(
    .clk(clk_100mhz),
    .rst(rst),
    .xadc_eoc(xadc_eoc),
    .xadc_drdy(xadc_drdy),
    .xadc_do(xadc_do),
    .xadc_den(xadc_den),
    .xadc_daddr(xadc_daddr),
    .sample_u12(sample_u12),
    .sample_valid(sample_valid),
    .sample_index(sample_index),
    .xadc_busy(xadc_controller_busy),
    .xadc_fault(xadc_fault)
);

assign xadc_fault_led = xadc_fault;

always_ff @(posedge clk_100mhz or posedge rst) begin
    if (rst) begin
        sample_seen_led <= 1'b0;
        sample_activity_led <= 1'b0;
        sample_level_led <= 1'b0;
        activity_counter <= '0;
    end else if (sample_valid) begin
        sample_seen_led <= 1'b1;
        sample_level_led <= sample_u12[11];

        if (activity_counter == ACTIVITY_TOGGLE_SAMPLES-1) begin
            activity_counter <= '0;
            sample_activity_led <= ~sample_activity_led;
        end else begin
            activity_counter <= activity_counter + 1'b1;
        end
    end
end

endmodule
