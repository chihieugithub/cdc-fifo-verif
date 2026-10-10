// Simple testbench for socetlib_cdc_fifo.
//
// Runs 4 tests in order:
//   1. reset         flags are correct after reset
//   2. write_read    one word goes through
//   3. fill_drain    wfull rises when full, rempty rises when empty, data stays in order
//   4. simultaneous  writer and reader run at the same time
//
// The write clock is 10 ns and the read clock is 7 ns, so the two sides are
// truly asynchronous. The last line printed is PASS or FAIL.

`timescale 1ns/1ps

module tb_cdc_fifo;

  parameter int DATA_WIDTH = 8;
  parameter int DEPTH      = 16;

  // ---------------------------------------------------------------- clocks
  logic wclk = 0;
  logic rclk = 0;
  always #5   wclk = ~wclk;   // 10 ns
  always #3.5 rclk = ~rclk;   // 7 ns

  // ---------------------------------------------------------------- DUT
  logic [DATA_WIDTH-1:0] wdata, rdata;
  logic winc, wfull, wnrst;
  logic rinc, rempty, rnrst;

  socetlib_cdc_fifo #(.DATA_WIDTH(DATA_WIDTH), .FIFO_DEPTH(DEPTH)) dut (
    .wdata(wdata), .winc(winc), .wclk(wclk), .wnrst(wnrst), .wfull(wfull),
    .rdata(rdata), .rinc(rinc), .rclk(rclk), .rnrst(rnrst), .rempty(rempty)
  );

  // ---------------------------------------------------------------- checking
  // Every word written is pushed here. Every read pops one and compares.
  logic [DATA_WIDTH-1:0] expected[$];
  int errors = 0;

  function automatic void check(bit ok, string msg);
    if (!ok) begin
      errors++;
      $display("  ERROR @%0t: %s", $time, msg);
    end
  endfunction

  // ---------------------------------------------------------------- tasks
  // Inputs change on the falling edge, so they are stable at the rising edge.

  task automatic reset_dut();
    winc = 0; rinc = 0; wdata = '0;
    wnrst = 0; rnrst = 0;
    repeat (4) @(posedge wclk);
    @(negedge wclk) wnrst = 1;
    @(negedge rclk) rnrst = 1;
  endtask

  // Wait until the FIFO is not full, then write one word.
  task automatic write_word(logic [DATA_WIDTH-1:0] d);
    @(negedge wclk);
    while (wfull) @(negedge wclk);
    wdata = d;
    winc  = 1;
    expected.push_back(d);
    @(negedge wclk) winc = 0;
  endtask

  // Wait until the FIFO is not empty, check the word, then read it.
  // rdata already shows the oldest word before rinc is raised.
  task automatic read_word();
    logic [DATA_WIDTH-1:0] exp;
    @(negedge rclk);
    while (rempty) @(negedge rclk);
    exp = expected.pop_front();
    check(rdata === exp, $sformatf("read %h, expected %h", rdata, exp));
    rinc = 1;
    @(negedge rclk) rinc = 0;
  endtask

  task automatic report(string name, int errors_before);
    $display("Test %-13s %s", name, (errors == errors_before) ? "PASS" : "FAIL");
  endtask

  // ---------------------------------------------------------------- tests
  initial begin
    int e;
    $display("CDC FIFO test: DEPTH=%0d DATA_WIDTH=%0d", DEPTH, DATA_WIDTH);

    // 1. Reset: the FIFO starts empty and not full.
    e = errors;
    reset_dut();
    repeat (5) @(negedge rclk);
    check(rempty == 1, "rempty should be 1 after reset");
    check(wfull  == 0, "wfull should be 0 after reset");
    report("reset", e);

    // 2. Write one word and read it back.
    e = errors;
    write_word(8'hA5);
    read_word();
    check(rempty == 1, "rempty should be 1 after reading the only word");
    report("write_read", e);

    // 3. Fill to full, then drain to empty.
    e = errors;
    for (int i = 0; i < DEPTH; i++) write_word(DATA_WIDTH'(i + 1));
    check(wfull == 1, $sformatf("wfull should be 1 after %0d writes", DEPTH));
    for (int i = 0; i < DEPTH; i++) read_word();
    check(rempty == 1, $sformatf("rempty should be 1 after %0d reads", DEPTH));
    report("fill_drain", e);

    // 4. Write and read at the same time.
    e = errors;
    fork
      for (int i = 0; i < 50; i++) write_word(DATA_WIDTH'($urandom));
      for (int i = 0; i < 50; i++) read_word();
    join
    check(expected.size() == 0, "words left over after test");
    report("simultaneous", e);

    if (errors == 0) begin
      $display("PASS");
      $finish;
    end else begin
      $display("FAIL (%0d errors)", errors);
      $fatal(1);
    end
  end

  // Stop instead of hanging if a flag never changes.
  initial begin
    #100us;
    $display("  ERROR: timeout");
    $display("FAIL");
    $fatal(1);
  end

endmodule
