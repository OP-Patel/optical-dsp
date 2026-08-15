`timescale 1ns/1ps

module tb_capture_streamer;

localparam time CLK_PERIOD = 10ns;
localparam int unsigned DEPTH = 4;

logic clk = 1'b0;
logic rst = 1'b1;
logic arm = 1'b0;
logic trigger = 1'b0;
logic sample_valid = 1'b0;
logic [11:0] sample_u12 = 12'b0;
logic [63:0] sample_index = 64'b0;
logic [$clog2(DEPTH)-1:0] read_address;
logic [11:0] read_data;
logic capture_armed;
logic capture_busy;
logic capture_done;
logic trigger_rejected;
logic [63:0] capture_start_index;
logic [15:0] capture_count;
logic request_valid;
logic [7:0] request_type;
logic [15:0] request_length;
logic [15:0] request_sequence;
logic request_ready;
logic payload_valid;
logic [7:0] payload_byte;
logic payload_ready;
logic output_valid;
logic [7:0] output_byte;
logic output_ready = 1'b0;
logic packet_busy;
logic packet_done;
logic packet_error;
logic streamer_busy;
logic [7:0] captured_bytes [0:63];
logic [7:0] fixture_bytes [0:28];
logic [11:0] source_samples [0:DEPTH-1];
int captured_byte_count = 0;
int ready_cycle = 0;
int checks = 0;

sample_capture #(
    .DEPTH(DEPTH),
    .INDEX_WIDTH(64)
) capture_inst(
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

capture_streamer #(
    .CAPTURE_DEPTH(DEPTH),
    .INDEX_WIDTH(64)
) streamer_inst(
    .clk(clk),
    .rst(rst),
    .capture_done(capture_done),
    .capture_start_index(capture_start_index),
    .capture_count(capture_count),
    .capture_read_address(read_address),
    .capture_read_data(read_data),
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

packet_tx #(
    .MAX_PAYLOAD_BYTES(64)
) packet_inst(
    .clk(clk),
    .rst(rst),
    .request_valid(request_valid),
    .request_type(request_type),
    .request_length(request_length),
    .request_sequence(request_sequence),
    .request_ready(request_ready),
    .payload_valid(payload_valid),
    .payload_byte(payload_byte),
    .payload_ready(payload_ready),
    .output_valid(output_valid),
    .output_byte(output_byte),
    .output_ready(output_ready),
    .packet_busy(packet_busy),
    .packet_done(packet_done),
    .packet_error(packet_error)
);

always #(CLK_PERIOD / 2) clk = ~clk;

function automatic logic [15:0] crc_next(
    input logic [15:0] current_crc,
    input logic [7:0] next_byte
);
    logic [15:0] working_crc;
begin
    working_crc = current_crc;
    for (int bit_number = 7; bit_number >= 0; bit_number--) begin
        if (working_crc[15] ^ next_byte[bit_number])
            working_crc = {working_crc[14:0], 1'b0} ^ 16'h1021;
        else
            working_crc = {working_crc[14:0], 1'b0};
    end
    return working_crc;
end
endfunction

always_ff @(posedge clk) begin
    if (rst) begin
        captured_byte_count <= 0;
        ready_cycle <= 0;
        output_ready <= 1'b0;
    end else begin
        ready_cycle <= ready_cycle + 1;
        output_ready <= ready_cycle[2:0] != 3'b000;

        if (output_valid && output_ready) begin
            captured_bytes[captured_byte_count] <= output_byte;
            captured_byte_count <= captured_byte_count + 1;
        end
    end
end

task automatic pulse(input string control_name);
begin
    @(negedge clk);
    if (control_name == "arm")
        arm = 1'b1;
    else
        trigger = 1'b1;
    @(negedge clk);
    arm = 1'b0;
    trigger = 1'b0;
end
endtask

task automatic send_sample(
    input logic [11:0] value,
    input logic [63:0] index_value,
    input int gap
);
begin
    repeat (gap) @(posedge clk);
    @(negedge clk);
    sample_u12 = value;
    sample_index = index_value;
    sample_valid = 1'b1;
    @(negedge clk);
    sample_valid = 1'b0;
end
endtask

initial begin
    logic [63:0] expected_start_index;
    logic [15:0] expected_crc;
    int payload_offset;

    source_samples[0] = 12'h001;
    source_samples[1] = 12'habc;
    source_samples[2] = 12'h800;
    source_samples[3] = 12'hfff;
    expected_start_index = 64'h1122334455667788;
    $readmemh("host/tests/fixtures/rtl_capture_packet.hex", fixture_bytes);

    repeat (2) @(posedge clk);
    @(negedge clk);
    rst = 1'b0;
    pulse("arm");
    pulse("trigger");

    for (int index = 0; index < DEPTH; index++)
        send_sample(source_samples[index], expected_start_index + index, index % 2);

    wait (packet_done);
    @(negedge clk);
    assert (captured_byte_count == 29)
    else $fatal(1, "integrated capture packet length mismatch expected=29 actual=%0d", captured_byte_count);
    checks++;

    assert (captured_bytes[0] == 8'ha5 && captured_bytes[1] == 8'h5a)
    else $fatal(1, "capture packet sync mismatch");
    assert (captured_bytes[2] == 8'h01 && captured_bytes[3] == 8'h02)
    else $fatal(1, "capture packet version/type mismatch");
    assert (captured_bytes[4] == 8'h13 && captured_bytes[5] == 8'h00)
    else $fatal(1, "capture packet payload length mismatch");
    assert (captured_bytes[6] == 8'h00 && captured_bytes[7] == 8'h00)
    else $fatal(1, "first capture sequence was not zero");
    checks += 4;

    for (int byte_number = 0; byte_number < 8; byte_number++) begin
        assert (captured_bytes[8 + byte_number] == expected_start_index[byte_number*8 +: 8])
        else $fatal(1, "start-index byte mismatch at %0d", byte_number);
        checks++;
    end

    assert (captured_bytes[16] == DEPTH && captured_bytes[17] == 0 && captured_bytes[18] == 8'h01)
    else $fatal(1, "capture metadata count/format mismatch");
    checks++;

    payload_offset = 19;
    for (int index = 0; index < DEPTH; index++) begin
        assert (captured_bytes[payload_offset] == source_samples[index][7:0])
        else $fatal(1, "sample low byte mismatch at %0d", index);
        assert (captured_bytes[payload_offset + 1] == {4'b0, source_samples[index][11:8]})
        else $fatal(1, "sample high byte mismatch at %0d", index);
        payload_offset += 2;
        checks += 2;
    end

    expected_crc = 16'hffff;
    for (int byte_number = 2; byte_number < 27; byte_number++)
        expected_crc = crc_next(expected_crc, captured_bytes[byte_number]);
    assert (captured_bytes[27] == expected_crc[7:0] && captured_bytes[28] == expected_crc[15:8])
    else $fatal(1, "capture packet CRC mismatch");
    assert (!packet_error && !trigger_rejected)
    else $fatal(1, "integrated capture reported an unexpected error");
    checks += 2;

    for (int byte_number = 0; byte_number < 29; byte_number++) begin
        assert (captured_bytes[byte_number] == fixture_bytes[byte_number])
        else $fatal(1, "RTL/Python fixture mismatch at byte %0d", byte_number);
        checks++;
    end

    $display("PASS: tb_capture_streamer checks=%0d samples=%0d packet_bytes=%0d", checks, DEPTH, captured_byte_count);
    $finish;
end

initial begin
    #100us;
    $fatal(1, "tb_capture_streamer timed out");
end

endmodule
