module bpw34_characterization_top #(
    parameter int unsigned CAPTURE_DEPTH = 1024,
    parameter int unsigned XADC_TIMEOUT_CYCLES = 256,
    parameter int unsigned UART_CLOCK_HZ = 100_000_000,
    parameter int unsigned UART_BAUD = 115_200,
    parameter int unsigned SYMBOL_DIVISOR_1K = 100_000,
    parameter int unsigned SYMBOL_DIVISOR_10K = 10_000
)(
    input logic clk_100mhz,
    input logic reset_btn,
    input logic arm_btn,
    input logic trigger_btn,
    input logic tx_enable,
    input logic [1:0] mode,
    input logic rate_10k,
    input logic vaux4_p,
    input logic vaux4_n,

    output logic laser_drive,
    output logic uart_tx_out,
    output logic capture_armed_led,
    output logic capture_busy_led,
    output logic capture_done_led,
    output logic capture_fault_led
);

localparam int unsigned CAPTURE_ADDRESS_WIDTH = (CAPTURE_DEPTH <= 1) ? 1 : $clog2(CAPTURE_DEPTH);

logic rst;
logic arm_sync;
logic trigger_sync;
logic arm_previous;
logic trigger_previous;
logic arm_pulse;
logic trigger_pulse;
logic accepted_arm_pulse;
logic control_rejected;

logic tx_enable_meta;
logic tx_enable_sync;
logic [1:0] mode_meta;
logic [1:0] mode_sync;
logic rate_10k_meta;
logic rate_10k_sync;
logic symbol_ce_1k;
logic symbol_ce_10k;
logic symbol_ce;
logic tx_bit;
logic frame_start;
logic payload_start;
logic [15:0] frame_sequence;
logic laser_blocked;

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

logic capture_armed;
logic capture_busy;
logic capture_done;
logic trigger_rejected;
logic [63:0] capture_start_index;
logic [15:0] capture_count;
logic [CAPTURE_ADDRESS_WIDTH-1:0] capture_read_address;
logic [11:0] capture_read_data;

logic request_valid;
logic [7:0] request_type;
logic [15:0] request_length;
logic [15:0] request_sequence;
logic request_ready;
logic payload_valid;
logic [7:0] payload_byte;
logic payload_ready;
logic packet_output_valid;
logic [7:0] packet_output_byte;
logic packet_output_ready;
logic packet_busy;
logic packet_done;
logic packet_error;
logic streamer_busy;
logic uart_busy;

assign arm_pulse = arm_sync && !arm_previous;
assign trigger_pulse = trigger_sync && !trigger_previous;
assign accepted_arm_pulse = arm_pulse && !streamer_busy && !packet_busy;
assign symbol_ce = rate_10k_sync ? symbol_ce_10k : symbol_ce_1k;

assign capture_armed_led = capture_armed;
assign capture_busy_led = capture_busy;
assign capture_done_led = capture_done;
assign capture_fault_led = xadc_fault || trigger_rejected || control_rejected || packet_error;

reset_sync reset_sync_inst(
    .clk(clk_100mhz),
    .async_reset_in(reset_btn),
    .rst(rst)
);

async_input_sync arm_button_sync_inst(
    .clk(clk_100mhz),
    .rst(rst),
    .async_in(arm_btn),
    .sync_out(arm_sync)
);

async_input_sync trigger_button_sync_inst(
    .clk(clk_100mhz),
    .rst(rst),
    .async_in(trigger_btn),
    .sync_out(trigger_sync)
);

always_ff @(posedge clk_100mhz) begin
    if (rst) begin
        tx_enable_meta <= 1'b0;
        tx_enable_sync <= 1'b0;
        mode_meta <= 2'b00;
        mode_sync <= 2'b00;
        rate_10k_meta <= 1'b0;
        rate_10k_sync <= 1'b0;
    end else begin
        tx_enable_meta <= tx_enable;
        tx_enable_sync <= tx_enable_meta;
        mode_meta <= mode;
        mode_sync <= mode_meta;
        rate_10k_meta <= rate_10k;
        rate_10k_sync <= rate_10k_meta;
    end
end

always_ff @(posedge clk_100mhz or posedge rst) begin
    if (rst) begin
        arm_previous <= 1'b0;
        trigger_previous <= 1'b0;
        control_rejected <= 1'b0;
    end else begin
        arm_previous <= arm_sync;
        trigger_previous <= trigger_sync;

        if (arm_pulse && (streamer_busy || packet_busy))
            control_rejected <= 1'b1;
        else if (accepted_arm_pulse)
            control_rejected <= 1'b0;
    end
end

clock_enable_gen #(
    .DIVISOR(SYMBOL_DIVISOR_1K)
) symbol_enable_1k_inst(
    .clk(clk_100mhz),
    .rst(rst),
    .enable(symbol_ce_1k)
);

clock_enable_gen #(
    .DIVISOR(SYMBOL_DIVISOR_10K)
) symbol_enable_10k_inst(
    .clk(clk_100mhz),
    .rst(rst),
    .enable(symbol_ce_10k)
);

optical_framer optical_framer_inst(
    .clk(clk_100mhz),
    .rst(rst),
    .symbol_ce(symbol_ce),
    .mode(mode_sync),
    .tx_bit(tx_bit),
    .frame_start(frame_start),
    .payload_start(payload_start),
    .frame_sequence(frame_sequence)
);

laser_output_guard laser_output_guard_inst(
    .rst(rst),
    .tx_bit(tx_bit),
    .tx_enable(tx_enable && tx_enable_sync),
    .fault(laser_blocked),
    .laser_drive(laser_drive)
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

sample_capture #(
    .DEPTH(CAPTURE_DEPTH),
    .INDEX_WIDTH(64)
) sample_capture_inst(
    .clk(clk_100mhz),
    .rst(rst),
    .arm(accepted_arm_pulse),
    .trigger(trigger_pulse),
    .sample_valid(sample_valid),
    .sample_u12(sample_u12),
    .sample_index(sample_index),
    .read_address(capture_read_address),
    .read_data(capture_read_data),
    .capture_armed(capture_armed),
    .capture_busy(capture_busy),
    .capture_done(capture_done),
    .trigger_rejected(trigger_rejected),
    .capture_start_index(capture_start_index),
    .capture_count(capture_count)
);

capture_streamer #(
    .CAPTURE_DEPTH(CAPTURE_DEPTH),
    .INDEX_WIDTH(64)
) capture_streamer_inst(
    .clk(clk_100mhz),
    .rst(rst),
    .capture_done(capture_done),
    .capture_start_index(capture_start_index),
    .capture_count(capture_count),
    .capture_read_address(capture_read_address),
    .capture_read_data(capture_read_data),
    .request_valid(request_valid),
    .request_type(request_type),
    .request_length(request_length),
    .request_sequence(request_sequence),
    .request_ready(request_ready),
    .payload_valid(payload_valid),
    .payload_byte(payload_byte),
    .payload_ready(payload_ready),
    .packet_done(packet_done),
    .streamer_busy(streamer_busy)
);

packet_tx packet_tx_inst(
    .clk(clk_100mhz),
    .rst(rst),
    .request_valid(request_valid),
    .request_type(request_type),
    .request_length(request_length),
    .request_sequence(request_sequence),
    .request_ready(request_ready),
    .payload_valid(payload_valid),
    .payload_byte(payload_byte),
    .payload_ready(payload_ready),
    .output_valid(packet_output_valid),
    .output_byte(packet_output_byte),
    .output_ready(packet_output_ready),
    .packet_busy(packet_busy),
    .packet_done(packet_done),
    .packet_error(packet_error)
);

uart_tx #(
    .CLOCK_HZ(UART_CLOCK_HZ),
    .BAUD(UART_BAUD)
) uart_tx_inst(
    .clk(clk_100mhz),
    .rst(rst),
    .data_valid(packet_output_valid),
    .data_byte(packet_output_byte),
    .data_ready(packet_output_ready),
    .tx(uart_tx_out),
    .busy(uart_busy)
);

endmodule

