


module axis_fifo #(
    parameter DATA_WIDTH = 16,
    parameter DEPTH = 4,
    parameter ADDR_WIDTH = $clog2(DEPTH)
)(
    input clk,
    input rst_n,
    
    // Write interface
    input wr_en,
    input [DATA_WIDTH-1:0] wr_data,
    
    // Read interface
    input rd_en,
    output logic [DATA_WIDTH-1:0] rd_data,
    output logic valid,
    
    // Status
    output logic full,
    output logic empty
);

    // FIFO storage
    logic [DATA_WIDTH-1:0] mem [0:DEPTH-1];
    
    // Pointers
    logic [ADDR_WIDTH:0] wr_ptr;  // Extra bit for full/empty detection
    logic [ADDR_WIDTH:0] rd_ptr;
    
    // Status signals
    assign full = (wr_ptr[ADDR_WIDTH] != rd_ptr[ADDR_WIDTH]) && 
                  (wr_ptr[ADDR_WIDTH-1:0] == rd_ptr[ADDR_WIDTH-1:0]);
    assign empty = (wr_ptr == rd_ptr);
    assign valid = !empty;
    // FWFT: valid and rd_data refer to the same head word before the read edge.
    assign rd_data = empty ? '0 : mem[rd_ptr[ADDR_WIDTH-1:0]];
    
    // Write logic
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wr_ptr <= 0;
        end else begin
            if (wr_en && !full) begin
                mem[wr_ptr[ADDR_WIDTH-1:0]] <= wr_data;
                wr_ptr <= wr_ptr + 1;
            end
        end
    end
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rd_ptr <= 0;
        end else begin
            if (rd_en && !empty) begin
                rd_ptr <= rd_ptr + 1;
            end
        end
    end

endmodule
