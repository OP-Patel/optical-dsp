module crc16_ccitt(
    input logic clk,
    input logic rst,
    input logic clear,
    input logic data_valid,
    input logic [7:0] data_byte,

    output logic [15:0] crc
);

function automatic logic [15:0] crc16_next(
    input logic [15:0] current_crc,
    input logic [7:0] next_byte
);
    logic [15:0] working_crc;
begin
    working_crc = current_crc;

    for (int bit_number = 7; bit_number >= 0; bit_number--) begin
        if (working_crc[15] ^ next_byte[bit_number]) begin
            working_crc = {working_crc[14:0], 1'b0} ^ 16'h1021;
        end else begin
            working_crc = {working_crc[14:0], 1'b0};
        end
    end

    return working_crc;
end
endfunction

always_ff @(posedge clk or posedge rst) begin
    if (rst) begin
        crc <= 16'hffff;
    end else if (clear) begin
        crc <= 16'hffff;
    end else if (data_valid) begin
        crc <= crc16_next(crc, data_byte);
    end
end

endmodule
