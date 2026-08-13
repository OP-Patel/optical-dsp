module optical_tx_bringup_top #(
    parameter int unsigned SYMBOL_DIVISOR = 100_000
)(
    input logic clk_100mhz,
    input logic reset_btn,
    input logic tx_enable,
    input logic [1:0] mode,
    input logic daoki_rx_async,

    output logic fault,
    output logic laser_drive,
    output logic daoki_rx_led
);

logic rst;
logic tx_bit;
logic symbol_ce;
logic frame_start;
logic payload_start;
logic [15:0] frame_sequence;
logic tx_enable_meta;
logic tx_enable_sync;
logic [1:0] mode_meta;
logic [1:0] mode_sync;

always_ff @(posedge clk_100mhz) begin
    if (rst) begin
        tx_enable_meta <= 1'b0;
        tx_enable_sync <= 1'b0;
        mode_meta <= 2'b00;
        mode_sync <= 2'b00;
    end else begin
        tx_enable_meta <= tx_enable;
        tx_enable_sync <= tx_enable_meta;
        mode_meta <= mode;
        mode_sync <= mode_meta;
    end
end

reset_sync reset_sync_inst(
    .clk(clk_100mhz),
    .async_reset_in(reset_btn),
    .rst(rst)
);

async_input_sync daoki_receiver_sync_inst(
    .clk(clk_100mhz),
    .rst(rst),
    .async_in(daoki_rx_async),
    .sync_out(daoki_rx_led)
);

clock_enable_gen #(
    .DIVISOR(SYMBOL_DIVISOR)
) symbol_enable_inst(
    .clk(clk_100mhz),
    .rst(rst),
    .enable(symbol_ce)
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
    .tx_enable(tx_enable & tx_enable_sync),
    .fault(fault),
    .laser_drive(laser_drive)
);

endmodule
