`timescale 1ns/1ps

module tb_packet_tx;

localparam time CLK_PERIOD = 10ns;
localparam int unsigned MAX_PAYLOAD_BYTES = 16;

logic clk = 1'b0;
logic rst = 1'b1;
logic request_valid = 1'b0;
logic [7:0] request_type = 8'b0;
logic [15:0] request_length = 16'b0;
logic [15:0] request_sequence = 16'b0;
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
logic [7:0] payload_memory [0:MAX_PAYLOAD_BYTES-1];
logic [7:0] captured_bytes [0:63];
logic [7:0] expected_bytes [0:63];
int payload_position = 0;
int active_payload_length = 0;
int captured_count = 0;
int expected_count = 0;
int ready_cycle = 0;
int checks = 0;

packet_tx #(
    .MAX_PAYLOAD_BYTES(MAX_PAYLOAD_BYTES)
) dut(
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

assign payload_valid = payload_position < active_payload_length;
assign payload_byte = payload_memory[payload_position];

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

always @(posedge clk) begin
    if (rst) begin
        payload_position <= 0;
        captured_count <= 0;
        ready_cycle <= 0;
        output_ready <= 1'b0;
    end else begin
        ready_cycle <= ready_cycle + 1;
        output_ready <= ready_cycle[1:0] != 2'b00;

        if (payload_valid && payload_ready)
            payload_position <= payload_position + 1;

        if (output_valid && output_ready) begin
            captured_bytes[captured_count] <= output_byte;
            captured_count <= captured_count + 1;
        end
    end
end

task automatic build_expected(
    input logic [7:0] packet_type,
    input int payload_length,
    input logic [15:0] sequence_value
);
    logic [15:0] expected_crc;
begin
    expected_count = 0;
    expected_bytes[expected_count++] = 8'ha5;
    expected_bytes[expected_count++] = 8'h5a;
    expected_bytes[expected_count++] = 8'h01;
    expected_bytes[expected_count++] = packet_type;
    expected_bytes[expected_count++] = payload_length[7:0];
    expected_bytes[expected_count++] = payload_length[15:8];
    expected_bytes[expected_count++] = sequence_value[7:0];
    expected_bytes[expected_count++] = sequence_value[15:8];

    for (int index = 0; index < payload_length; index++)
        expected_bytes[expected_count++] = payload_memory[index];

    expected_crc = 16'hffff;
    for (int index = 2; index < expected_count; index++)
        expected_crc = crc_next(expected_crc, expected_bytes[index]);

    expected_bytes[expected_count++] = expected_crc[7:0];
    expected_bytes[expected_count++] = expected_crc[15:8];
end
endtask

task automatic run_packet(
    input logic [7:0] packet_type,
    input int payload_length,
    input logic [15:0] sequence_value
);
begin
    @(negedge clk);
    payload_position = 0;
    active_payload_length = payload_length;
    captured_count = 0;
    build_expected(packet_type, payload_length, sequence_value);
    request_type = packet_type;
    request_length = payload_length;
    request_sequence = sequence_value;
    request_valid = 1'b1;
    wait (request_ready);
    @(posedge clk);
    @(negedge clk);
    request_valid = 1'b0;

    wait (packet_done);
    @(negedge clk);
    assert (captured_count == expected_count)
    else $fatal(1, "packet byte count mismatch expected=%0d actual=%0d", expected_count, captured_count);
    checks++;

    for (int index = 0; index < expected_count; index++) begin
        assert (captured_bytes[index] == expected_bytes[index])
        else $fatal(1, "packet byte mismatch index=%0d expected=%02h actual=%02h", index, expected_bytes[index], captured_bytes[index]);
        checks++;
    end

    assert (!packet_error && !packet_busy)
    else $fatal(1, "valid packet ended with an error or busy state");
    checks++;
end
endtask

initial begin
    for (int index = 0; index < MAX_PAYLOAD_BYTES; index++)
        payload_memory[index] = (index * 8'h31) ^ 8'ha6;

    repeat (2) @(posedge clk);
    @(negedge clk);
    rst = 1'b0;

    run_packet(8'h01, 0, 16'h0000);
    run_packet(8'h02, 5, 16'h1234);
    run_packet(8'h7e, MAX_PAYLOAD_BYTES, 16'hffff);

    // Oversize requests are consumed but rejected without emitting bytes.
    @(negedge clk);
    captured_count = 0;
    request_type = 8'h02;
    request_length = MAX_PAYLOAD_BYTES + 1;
    request_sequence = 16'h0003;
    request_valid = 1'b1;
    @(posedge clk);
    @(negedge clk);
    request_valid = 1'b0;
    #1ns;
    assert (packet_error && packet_done && captured_count == 0)
    else $fatal(1, "oversize packet was not rejected cleanly");
    checks++;

    $display("PASS: tb_packet_tx checks=%0d zero ordinary max and oversize packets", checks);
    $finish;
end

initial begin
    #100us;
    $fatal(1, "tb_packet_tx timed out");
end

endmodule
