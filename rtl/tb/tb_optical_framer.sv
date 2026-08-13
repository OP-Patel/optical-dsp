`timescale 1ns/1ps

module tb_optical_framer;

localparam time CLK_PERIOD = 10ns;
localparam logic [1:0] MODE_OFF = 2'b00;
localparam logic [1:0] MODE_ON = 2'b01;
localparam logic [1:0] MODE_TRAINING = 2'b10;
localparam logic [1:0] MODE_FRAMED = 2'b11;
localparam logic [31:0] PREAMBLE = 32'hAAAAAAAA;
localparam logic [15:0] SYNC_WORD = 16'hD5B3;
localparam logic [0:63] GOLDEN_PRBS =
    64'b0000000000000010000000000000110000000000001010000000000011110000;

logic clk = 1'b0;
logic rst = 1'b1;
logic symbol_ce = 1'b0;
logic [1:0] mode = MODE_OFF;
logic tx_bit;
logic frame_start;
logic payload_start;
logic [15:0] frame_sequence;
logic payload_zero [0:1023];
logic last_emitted_bit;
int checks = 0;
int seed_loads = 0;
int prbs_advances = 0;

optical_framer dut (
    .clk(clk),
    .rst(rst),
    .symbol_ce(symbol_ce),
    .mode(mode),
    .tx_bit(tx_bit),
    .frame_start(frame_start),
    .payload_start(payload_start),
    .frame_sequence(frame_sequence)
);

always #(CLK_PERIOD / 2) clk = ~clk;

always @(posedge clk) begin
    if (!rst && dut.prbs_load_seed)
        seed_loads++;
    if (!rst && dut.prbs_advance)
        prbs_advances++;
end

function automatic logic expected_prbs_bit(input int payload_index);
    logic [14:0] model_state;
    logic feedback;
    int i;
begin
    model_state = 15'h0001;
    for (i = 0; i < payload_index; i++) begin
        feedback = model_state[14] ^ model_state[13];
        model_state = {model_state[13:0], feedback};
    end
    expected_prbs_bit = model_state[14];
end
endfunction

function automatic logic expected_frame_bit(
    input int symbol_index,
    input logic [15:0] sequence_value
);
begin
    if (symbol_index < 32)
        expected_frame_bit = PREAMBLE[31 - symbol_index];
    else if (symbol_index < 48)
        expected_frame_bit = SYNC_WORD[15 - (symbol_index - 32)];
    else if (symbol_index < 64)
        expected_frame_bit = sequence_value[15 - (symbol_index - 48)];
    else
        expected_frame_bit = expected_prbs_bit(symbol_index - 64);
end
endfunction

task automatic apply_reset;
begin
    @(negedge clk);
    rst = 1'b1;
    symbol_ce = 1'b0;
    #1ns;
    assert (tx_bit === 1'b0)
    else $fatal(1, "tx_bit was not safe while reset was asserted");
    checks++;

    @(posedge clk);
    #1ns;
    assert (frame_sequence === 16'd0)
    else $fatal(1, "frame sequence did not reset");
    assert (dut.frame_state === 2'd0 && dut.field_index === 0)
    else $fatal(1, "framer did not reset to the first preamble bit");
    checks += 2;

    @(negedge clk);
    rst = 1'b0;
end
endtask

task automatic emit_and_expect(
    input logic expected_bit,
    input logic expected_frame_start,
    input logic expected_payload_start,
    input string message
);
begin
    @(negedge clk);
    symbol_ce = 1'b1;
    #1ns;
    assert (tx_bit === expected_bit)
    else $fatal(1, "%s: expected tx_bit=%0b, got %0b", message, expected_bit, tx_bit);
    assert (frame_start === expected_frame_start)
    else $fatal(1, "%s: incorrect frame_start", message);
    assert (payload_start === expected_payload_start)
    else $fatal(1, "%s: incorrect payload_start", message);
    checks += 3;
    last_emitted_bit = tx_bit;

    @(posedge clk);
    #1ns;
    symbol_ce = 1'b0;
end
endtask

task automatic check_hold(input string message);
    logic [1:0] held_frame_state;
    logic [9:0] held_field_index;
    logic [14:0] held_prbs_state;
    logic held_tx_bit;
    logic [15:0] held_sequence;
    int i;
begin
    @(negedge clk);
    symbol_ce = 1'b0;
    held_frame_state = dut.frame_state;
    held_field_index = dut.field_index;
    held_prbs_state = dut.prbs_state;
    held_tx_bit = tx_bit;
    held_sequence = frame_sequence;

    for (i = 0; i < 3; i++) begin
        @(posedge clk);
        #1ns;
        assert (dut.frame_state === held_frame_state)
        else $fatal(1, "%s: state changed during symbol_ce stall", message);
        assert (dut.field_index === held_field_index)
        else $fatal(1, "%s: field index changed during symbol_ce stall", message);
        assert (dut.prbs_state === held_prbs_state)
        else $fatal(1, "%s: PRBS state changed during symbol_ce stall", message);
        assert (tx_bit === held_tx_bit)
        else $fatal(1, "%s: tx_bit changed during symbol_ce stall", message);
        assert (frame_sequence === held_sequence)
        else $fatal(1, "%s: sequence changed during symbol_ce stall", message);
        assert (!frame_start && !payload_start)
        else $fatal(1, "%s: event asserted without symbol_ce", message);
        checks += 6;
    end
end
endtask

task automatic consume_frame(
    input logic [15:0] expected_sequence,
    input bit save_payload,
    input bit add_stalls
);
    logic expected;
    int i;
begin
    for (i = 0; i < 1088; i++) begin
        if (add_stalls && i == 5)
            check_hold("preamble hold");
        if (add_stalls && i == 35)
            check_hold("sync hold");
        if (add_stalls && i == 52)
            check_hold("sequence hold");
        if (add_stalls && i == 100)
            check_hold("payload hold");

        expected = expected_frame_bit(i, expected_sequence);
        emit_and_expect(expected, i == 0, i == 64, "framed symbol mismatch");

        if (i >= 64 && save_payload)
            payload_zero[i - 64] = last_emitted_bit;
        if (i >= 64 && expected_sequence == 16'd1) begin
            assert (last_emitted_bit === payload_zero[i - 64])
            else $fatal(1, "payload differed between frames at index %0d", i - 64);
            checks++;
        end
    end
end
endtask

task automatic enter_framed_mode;
begin
    @(negedge clk);
    mode = MODE_OFF;
    symbol_ce = 1'b0;
    @(posedge clk);
    #1ns;
    @(negedge clk);
    mode = MODE_FRAMED;
end
endtask

task automatic reset_from_frame_position(input int symbols_to_consume);
    int i;
begin
    enter_framed_mode();
    for (i = 0; i < symbols_to_consume; i++)
        emit_and_expect(expected_frame_bit(i, 16'd0), i == 0, i == 64,
                        "setup before reset");
    apply_reset();
end
endtask

initial begin : stimulus
    int i;

    apply_reset();

    mode = MODE_OFF;
    for (i = 0; i < 100; i++)
        emit_and_expect(1'b0, 1'b0, 1'b0, "OFF mode");

    mode = MODE_ON;
    for (i = 0; i < 100; i++)
        emit_and_expect(1'b1, 1'b0, 1'b0, "ON mode");

    mode = MODE_TRAINING;
    for (i = 0; i < 100; i++)
        emit_and_expect((i % 2) == 0, 1'b0, 1'b0, "TRAINING mode");
    check_hold("training hold");

    enter_framed_mode();
    seed_loads = 0;
    prbs_advances = 0;
    consume_frame(16'd0, 1'b1, 1'b1);
    assert (frame_sequence === 16'd1)
    else $fatal(1, "sequence did not increment after first frame");
    checks++;

    consume_frame(16'd1, 1'b0, 1'b0);
    assert (frame_sequence === 16'd2)
    else $fatal(1, "sequence did not increment after second frame");
    assert (seed_loads == 2)
    else $fatal(1, "expected two PRBS seed loads, got %0d", seed_loads);
    assert (prbs_advances == 2048)
    else $fatal(1, "expected 2048 PRBS advances, got %0d", prbs_advances);
    checks += 3;

    for (i = 0; i < 64; i++) begin
        assert (expected_prbs_bit(i) === GOLDEN_PRBS[i])
        else $fatal(1, "independent PRBS model disagreed with golden bit %0d", i);
        checks++;
    end

    // A non-framed request immediately aborts the frame. Re-entering framed
    // mode starts at preamble bit zero instead of resuming the old payload.
    enter_framed_mode();
    for (i = 0; i < 80; i++)
        emit_and_expect(expected_frame_bit(i, 16'd2), i == 0, i == 64,
                        "mode-change setup");

    @(negedge clk);
    mode = MODE_TRAINING;
    symbol_ce = 1'b1;
    #1ns;
    assert (tx_bit === 1'b1)
    else $fatal(1, "TRAINING did not take effect immediately");
    checks++;
    @(posedge clk);
    #1ns;
    symbol_ce = 1'b0;

    enter_framed_mode();
    emit_and_expect(PREAMBLE[31], 1'b1, 1'b0,
                    "FRAMED did not restart at preamble bit zero");

    for (i = 1; i < 70; i++)
        emit_and_expect(expected_frame_bit(i, 16'd2), 1'b0, i == 64,
                        "OFF mode-change setup");
    @(negedge clk);
    mode = MODE_OFF;
    #1ns;
    assert (tx_bit === 1'b0)
    else $fatal(1, "OFF did not force tx_bit low immediately");
    checks++;

    // Exercise synchronous reset from every framing state.
    reset_from_frame_position(1);
    reset_from_frame_position(33);
    reset_from_frame_position(49);
    reset_from_frame_position(65);

    $display("PASS: tb_optical_framer checks=%0d frames=2 seed_loads=2 prbs_advances=2048", checks);
    $finish;
end

initial begin
    #2ms;
    $fatal(1, "tb_optical_framer timed out");
end

endmodule
