module optical_framer#(
    localparam logic [31:0] PREAMBLE = 32'hAAAAAAAA, // 10101010101010101010101010101010
    localparam logic [15:0] SYNC_WORD = 16'hD5B3, // 1101010110110011
    localparam logic [14:0] PRBS_SEED = 15'h0001 // 000000000000001
)
(
    input logic clk, 
    input logic rst, 
    input logic symbol_ce,
    input logic [1:0] mode,

    output logic tx_bit, frame_start, payload_start,
    output logic [15:0] frame_sequence
);

logic [9:0] field_index;
logic training_bit;
logic prbs_out;
logic prbs_load_seed;
logic prbs_advance;
logic [14:0] prbs_state;

prbs15_gen #(
    .SEED(PRBS_SEED)
) prbs_gen (
    .clk(clk),
    .rst(rst),
    .load_seed(prbs_load_seed),
    .advance(prbs_advance),
    .bit_out(prbs_out),
    .state(prbs_state)
);

typedef enum logic [1:0]{
    MODE_OFF = 2'b00,
    MODE_ON = 2'b01,
    MODE_TRAINING = 2'b10,
    MODE_FRAMED = 2'b11
} transmit_mode_t;

typedef enum logic [1:0] {
    FRAME_PREAMBLE,
    FRAME_SYNC,
    FRAME_SEQUENCE,
    FRAME_PAYLOAD
} frame_state_t;

frame_state_t frame_state;

logic framed_bit;

always_comb begin
    framed_bit = 1'b0;

    case (frame_state)
        FRAME_PREAMBLE:
            framed_bit = PREAMBLE[31 - field_index];

        FRAME_SYNC:
            framed_bit = SYNC_WORD[15 - field_index];

        FRAME_SEQUENCE:
            framed_bit = frame_sequence[15 - field_index];

        FRAME_PAYLOAD:
            framed_bit = prbs_out;

        default:
            framed_bit = 1'b0;
    endcase
end

always_comb begin
    if (rst) begin
        tx_bit = 1'b0;
    end else begin
        case (mode)
            MODE_OFF:
                tx_bit = 1'b0;

            MODE_ON:
                tx_bit = 1'b1;

            MODE_TRAINING:
                tx_bit = training_bit;

            MODE_FRAMED:
                tx_bit = framed_bit;

            default:
                tx_bit = 1'b0;
        endcase
    end
end

always_comb begin
    frame_start =
        symbol_ce &&
        (mode == MODE_FRAMED) &&
        (frame_state == FRAME_PREAMBLE) &&
        (field_index == 0);

    payload_start =
        symbol_ce &&
        (mode == MODE_FRAMED) &&
        (frame_state == FRAME_PAYLOAD) &&
        (field_index == 0);

    prbs_load_seed =
        symbol_ce &&
        (mode == MODE_FRAMED) &&
        (frame_state == FRAME_SEQUENCE) &&
        (field_index == 15);

    prbs_advance =
        symbol_ce &&
        (mode == MODE_FRAMED) &&
        (frame_state == FRAME_PAYLOAD);
end

always_ff @(posedge clk) begin
    if (rst) begin
        frame_state <= FRAME_PREAMBLE;
        field_index <= 10'd0;
        frame_sequence <= 16'd0;
        training_bit <= 1'b1;
    end else begin
        if (mode == MODE_TRAINING) begin
            if (symbol_ce) begin
                training_bit <= ~training_bit;
            end
        end else begin
            // Restart training at 1 next time it is selected.
            training_bit <= 1'b1;
        end

        if (mode != MODE_FRAMED) begin
            // Park the framer so framed mode always starts cleanly.
            frame_state <= FRAME_PREAMBLE;
            field_index <= 10'd0;
        end else if (symbol_ce) begin
            case (frame_state)
                FRAME_PREAMBLE: begin
                    if (field_index == 31) begin
                        frame_state <= FRAME_SYNC;
                        field_index <= 10'd0;
                    end else begin
                        field_index <= field_index + 10'd1;
                    end
                end

                FRAME_SYNC: begin
                    if (field_index == 15) begin
                        frame_state <= FRAME_SEQUENCE;
                        field_index <= 10'd0;
                    end else begin
                        field_index <= field_index + 10'd1;
                    end
                end

                FRAME_SEQUENCE: begin
                    if (field_index == 15) begin
                        frame_state <= FRAME_PAYLOAD;
                        field_index <= 10'd0;
                    end else begin
                        field_index <= field_index + 10'd1;
                    end
                end

                FRAME_PAYLOAD: begin
                    if (field_index == 1023) begin
                        frame_state <= FRAME_PREAMBLE;
                        field_index <= 10'd0;
                        frame_sequence <= frame_sequence + 16'd1;
                    end else begin
                        field_index <= field_index + 10'd1;
                    end
                end

                default: begin
                    frame_state <= FRAME_PREAMBLE;
                    field_index <= 10'd0;
                end
            endcase
        end
    end
end

endmodule
 


