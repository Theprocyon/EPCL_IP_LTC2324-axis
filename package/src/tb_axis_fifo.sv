`timescale 1ns / 1ps

module tb_axis_fifo;
    localparam int DEPTH = 4;
    logic clk = 0;
    always #5 clk = ~clk;
    logic rst_n = 0;
    logic wr_en = 0, rd_en = 0;
    logic [15:0] wr_data = 0;
    wire [15:0] rd_data;
    wire valid, full, empty;
    axis_fifo #(.DATA_WIDTH(16), .DEPTH(DEPTH)) dut (.*);

    logic [15:0] expected[$];
    int accepted = 0, consumed = 0, blocked = 0;

    task automatic check_head;
        if (empty !== (expected.size() == 0) ||
            valid !== (expected.size() != 0) ||
            full !== (expected.size() == DEPTH))
            $fatal(1, "FIFO status mismatch, expected depth=%0d", expected.size());
        if (expected.size() != 0) begin
            if (rd_data !== expected[0])
                $fatal(1, "FIFO_HEAD_MISMATCH expected=%04h actual=%04h",
                       expected[0], rd_data);
        end
    endtask

    // Check the word seen by a ready/valid consumer before each sampling edge.
    task automatic step(input bit push, input bit ready, input logic [15:0] data);
        bit accept_write, accept_read;
        logic [15:0] removed;
        @(negedge clk);
        wr_en = push; rd_en = ready; wr_data = data;
        #1;
        check_head();
        accept_write = push && expected.size() < DEPTH;
        accept_read = ready && expected.size() != 0;
        @(posedge clk);
        if (accept_read) begin
            removed = expected.pop_front();
            consumed++;
        end
        if (accept_write) begin
            expected.push_back(data);
            accepted++;
        end else if (push) blocked++;
        #1;
        check_head();
    endtask

    task automatic reset_fifo;
        @(negedge clk);
        rst_n = 0; wr_en = 0; rd_en = 0;
        expected.delete();
        #1;
        check_head();
        if (rd_data !== 16'd0) $fatal(1, "Reset output is not zero");
        repeat (2) @(negedge clk);
        rst_n = 1;
    endtask

    initial begin
        reset_fifo();
        step(0, 1, 0);
        step(1, 1, 16'hff95);
        step(0, 1, 0);
        step(1, 1, 16'h0001);
        step(0, 1, 0);
        $display("PASS: empty-to-write with ready already high; fresh signed bit patterns");

        step(1, 0, 16'h8000);
        step(1, 0, 16'h7fff);
        step(1, 0, 16'hffff);
        step(1, 0, 16'h0000);
        repeat (4) step(0, 0, 0);
        step(1, 0, 16'hdead);
        // Preserve the existing full policy: writes are rejected while full,
        // including a clock that also reads. A rejected write must not corrupt data.
        step(1, 1, 16'hbeef);
        step(1, 1, 16'h1234);
        repeat (4) step(0, 1, 0);
        $display("PASS: backpressure, full/empty guards and simultaneous push/pop");

        // Repeated empty-to-write is the CM's usual once-per-period receive pattern.
        for (int i = 0; i < 32; i++) begin
            step(1, 1, 16'hf100 + i);
            step(0, 1, 0);
            repeat (3) step(0, 1, 0);
        end
        for (int i = 0; i < 200; i++)
            step((i % 4) != 0, (i % 5) != 0, 16'h4000 + i);
        repeat (DEPTH + 1) step(0, 1, 0);
        if (accepted != consumed)
            $fatal(1, "Lost or duplicated data: accepted=%0d consumed=%0d", accepted, consumed);
        $display("PASS: isolated ADC-style samples, pointer wrap and mixed traffic");

        step(1, 0, 16'haaaa);
        step(1, 0, 16'h5555);
        reset_fifo();
        step(1, 1, 16'h0102);
        step(0, 1, 0);
        $display("PASS: reset discards queued data; first post-reset word is fresh");
        $display("AXIS_FIFO_TEST_PASS accepted=%0d consumed=%0d blocked=%0d",
                 accepted, consumed, blocked);
        $finish;
    end

    initial begin
        #100000;
        $fatal(1, "Test timeout");
    end
endmodule
