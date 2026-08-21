module dc_removal_bringup_top #(
    parameter int unsigned CAPTURE_DEPTH = 1024,
    parameter int unsigned XADC_TIMEOUT_CYCLES = 256,
    parameter int unsigned UART_CLOCK_HZ = 100_000_000,
    parameter int unsigned UART_BAUD = 115_200,
    parameter int unsigned SYMBOL_DIVISOR_1K = 100_000,
    parameter int unsigned SYMBOL_DIVISOR_10K = 10_000,
    parameter int unsigned DC_K = 10
)(
    input logic clk_100mhz,
    input logic reset_btn,
    input logic arm_btn,
    input logic trigger_btn,
    input logic capture_view_btn,
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
    output logic capture_fault_led,
    output logic capture_raw_led,
    output logic capture_estimate_led,
    output logic capture_centered_led
);

localparam int unsigned CAPTURE_ADDRESS_WIDTH = (CAPTURE_DEPTH <= 1) ? 1 : $clog2(CAPTURE_DEPTH);
localparam logic [1:0] CAPTURE_RAW = 2'b00;
localparam logic [1:0] CAPTURE_ESTIMATE = 2'b01;
localparam logic [1:0] CAPTURE_CENTERED = 2'b10;
localparam logic [1:0] CAPTURE_FILTERED = 2'b11;

logic rst;
logic arm_sync;
logic trigger_sync;
logic capture_view_sync;
logic arm_previous;
logic trigger_previous;
logic capture_view_previous;
logic arm_pulse;
logic trigger_pulse;
logic capture_view_pulse;
logic accepted_arm_pulse;
logic control_rejected;
logic [1:0] requested_capture_view;
logic [1:0] armed_capture_view;

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

logic dc_out_valid;
logic signed [12:0] centered_sample;
logic [11:0] dc_estimate_dbg;
logic estimate_fault;
logic [11:0] raw_sample_delay;
logic [11:0] estimate_sample_delay;
logic [63:0] sample_index_delay;
logic [11:0] raw_capture_delay;
logic [11:0] estimate_capture_delay;
logic signed [12:0] centered_capture_delay;
logic [63:0] sample_index_capture_delay;
logic [11:0] raw_capture_alignment [0:4];
logic [11:0] estimate_capture_alignment [0:4];
logic signed [12:0] centered_capture_alignment [0:4];
logic [63:0] sample_index_capture_alignment [0:4];
logic fir_out_valid;
logic signed [15:0] filtered_sample;
logic fir_saturation_pulse;
logic [1:0] fir_active_coeff_bank;
logic signed [13:0] centered_biased;
logic [11:0] centered_capture_sample;
logic centered_capture_saturated;
logic signed [16:0] filtered_biased;
logic [11:0] filtered_capture_sample;
logic filtered_capture_saturated;
logic capture_saturation_fault;
logic [11:0] selected_capture_sample;

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
assign capture_view_pulse = capture_view_sync && !capture_view_previous;
assign accepted_arm_pulse = arm_pulse && !streamer_busy && !packet_busy;
assign symbol_ce = rate_10k_sync ? symbol_ce_10k : symbol_ce_1k;

assign capture_armed_led = capture_armed;
assign capture_busy_led = capture_busy;
assign capture_done_led = capture_done;
assign capture_fault_led =
    xadc_fault || trigger_rejected || control_rejected || packet_error ||
    estimate_fault ||
    capture_saturation_fault;

assign capture_raw_led = requested_capture_view == CAPTURE_RAW;
assign capture_estimate_led =
    requested_capture_view == CAPTURE_ESTIMATE ||
    requested_capture_view == CAPTURE_FILTERED;
assign capture_centered_led =
    requested_capture_view == CAPTURE_CENTERED ||
    requested_capture_view == CAPTURE_FILTERED;

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

async_input_sync capture_view_button_sync_inst(
    .clk(clk_100mhz),
    .rst(rst),
    .async_in(capture_view_btn),
    .sync_out(capture_view_sync)
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

always_ff @(posedge clk_100mhz) begin
    if (rst || accepted_arm_pulse) begin
        capture_saturation_fault <= 1'b0;
    end else if (
        capture_busy && fir_out_valid &&
        (
            fir_saturation_pulse ||
            (armed_capture_view == CAPTURE_CENTERED && centered_capture_saturated) ||
            (armed_capture_view == CAPTURE_FILTERED && filtered_capture_saturated)
        )
    ) begin
        capture_saturation_fault <= 1'b1;
    end
end

always_ff @(posedge clk_100mhz) begin
    if (rst) begin
        arm_previous <= 1'b0;
        trigger_previous <= 1'b0;
        capture_view_previous <= 1'b0;
        control_rejected <= 1'b0;
        requested_capture_view <= CAPTURE_RAW;
        armed_capture_view <= CAPTURE_RAW;
    end else begin
        arm_previous <= arm_sync;
        trigger_previous <= trigger_sync;
        capture_view_previous <= capture_view_sync;

        if (capture_view_pulse) begin
            if (capture_armed || capture_busy || streamer_busy || packet_busy) begin
                control_rejected <= 1'b1;
            end else begin
                case (requested_capture_view)
                    CAPTURE_RAW: requested_capture_view <= CAPTURE_ESTIMATE;
                    CAPTURE_ESTIMATE: requested_capture_view <= CAPTURE_CENTERED;
                    CAPTURE_CENTERED: requested_capture_view <= CAPTURE_FILTERED;
                    default: requested_capture_view <= CAPTURE_RAW;
                endcase
            end
        end

        if (arm_pulse && (streamer_busy || packet_busy))
            control_rejected <= 1'b1;
        else if (accepted_arm_pulse) begin
            control_rejected <= 1'b0;
            armed_capture_view <= requested_capture_view;
        end
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

dc_removal #(
    .K(DC_K),
    .FRACTIONAL_BITS(10)
) dc_removal_inst(
    .clk(clk_100mhz),
    .rst(rst),
    .in_valid(sample_valid),
    .in_sample(sample_u12),
    .clear_estimate(1'b0),
    .freeze_estimate(1'b0),
    .out_valid(dc_out_valid),
    .out_sample(centered_sample),
    .dc_estimate_dbg(dc_estimate_dbg),
    .estimate_fault(estimate_fault)
);

fir_filter #(
    .TAPS(16)
) fir_filter_inst(
    .clk(clk_100mhz),
    .rst(rst),
    .clear_history(1'b0),
    .in_valid(dc_out_valid),
    .in_sample(centered_sample),
    .filter_enable(1'b1),
    .coeff_bank(2'b10),
    .out_valid(fir_out_valid),
    .out_sample(filtered_sample),
    .saturation_pulse(fir_saturation_pulse),
    .active_coeff_bank(fir_active_coeff_bank)
);

always_ff @(posedge clk_100mhz) begin
    if (rst) begin
        raw_sample_delay <= 12'b0;
        estimate_sample_delay <= 12'b0;
        sample_index_delay <= 64'b0;
    end else if (sample_valid) begin
        raw_sample_delay <= sample_u12;
        estimate_sample_delay <= dc_estimate_dbg;
        sample_index_delay <= sample_index;
    end
end

always_ff @(posedge clk_100mhz) begin
    if (rst) begin
        raw_capture_delay <= 12'b0;
        estimate_capture_delay <= 12'b0;
        centered_capture_delay <= '0;
        sample_index_capture_delay <= 64'b0;
    end else if (dc_out_valid) begin
        raw_capture_delay <= raw_sample_delay;
        estimate_capture_delay <= estimate_sample_delay;
        centered_capture_delay <= centered_sample;
        sample_index_capture_delay <= sample_index_delay;
    end
end

always_ff @(posedge clk_100mhz) begin
    if (rst) begin
        for (int stage = 0; stage < 5; stage++) begin
            raw_capture_alignment[stage] <= 12'b0;
            estimate_capture_alignment[stage] <= 12'b0;
            centered_capture_alignment[stage] <= '0;
            sample_index_capture_alignment[stage] <= 64'b0;
        end
    end else begin
        raw_capture_alignment[0] <= raw_capture_delay;
        estimate_capture_alignment[0] <= estimate_capture_delay;
        centered_capture_alignment[0] <= centered_capture_delay;
        sample_index_capture_alignment[0] <= sample_index_capture_delay;

        for (int stage = 1; stage < 5; stage++) begin
            raw_capture_alignment[stage] <= raw_capture_alignment[stage - 1];
            estimate_capture_alignment[stage] <= estimate_capture_alignment[stage - 1];
            centered_capture_alignment[stage] <= centered_capture_alignment[stage - 1];
            sample_index_capture_alignment[stage] <= sample_index_capture_alignment[stage - 1];
        end
    end
end

always_comb begin
    centered_biased = $signed(centered_capture_alignment[4]) + 14'sd2048;
    centered_capture_saturated = 1'b0;

    if (centered_biased < 0) begin
        centered_capture_sample = 12'b0;
        centered_capture_saturated = 1'b1;
    end else if (centered_biased > 4095) begin
        centered_capture_sample = 12'hfff;
        centered_capture_saturated = 1'b1;
    end else begin
        centered_capture_sample = centered_biased[11:0];
    end

    filtered_biased = $signed(filtered_sample) + 17'sd2048;
    filtered_capture_saturated = 1'b0;

    if (filtered_biased < 0) begin
        filtered_capture_sample = 12'b0;
        filtered_capture_saturated = 1'b1;
    end else if (filtered_biased > 4095) begin
        filtered_capture_sample = 12'hfff;
        filtered_capture_saturated = 1'b1;
    end else begin
        filtered_capture_sample = filtered_biased[11:0];
    end

    case (armed_capture_view)
        CAPTURE_ESTIMATE: selected_capture_sample = estimate_capture_alignment[4];
        CAPTURE_CENTERED: selected_capture_sample = centered_capture_sample;
        CAPTURE_FILTERED: selected_capture_sample = filtered_capture_sample;
        default: selected_capture_sample = raw_capture_alignment[4];
    endcase
end

sample_capture #(
    .DEPTH(CAPTURE_DEPTH),
    .INDEX_WIDTH(64)
) sample_capture_inst(
    .clk(clk_100mhz),
    .rst(rst),
    .arm(accepted_arm_pulse),
    .trigger(trigger_pulse),
    .sample_valid(fir_out_valid),
    .sample_u12(selected_capture_sample),
    .sample_index(sample_index_capture_alignment[4]),
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
