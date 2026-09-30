`timescale 1ns / 1ps

//////////////////////////////////////////////////////////////////////////////////
// Company: EPCL
// Engineer: theprocyon
// 
// Create Date: 2025/12/08 21:21:13
// Design Name: 
// Module Name: ltc2324_core
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

module ltc2324_core(

    input clk,
    input rst_n,
    input start,

    output valid,
    output logic [15:0] ch1,
    output logic [15:0] ch2,
    output logic [15:0] ch3,
    output logic [15:0] ch4,
    
    // LTC2324 Interface
    input CLKOUT,
    input SDO1,
    input SDO2,
    input SDO3,
    input SDO4,
    output nCNV,
    output SCK

    );

// ====== State Machine  ======

typedef enum logic [2:0] {
    IDLE,
    START,
    CONVERT,
    ACQUIRE, // Fire sck
    DSCKHCNVH
} state_t;

state_t state, next_state;

//state counters for timing control
logic [1:0] tcnvh_clk_cnt;
localparam logic [1:0] TCNVH_CLK_MAX = 3;

logic [4:0] tconv_clk_cnt;
localparam logic [4:0] TCONV_CLK_MAX = 24;

logic [3:0] tsck_clk_cnt;
localparam logic [3:0] TSCK_CLK_MAX = 16 - 1;

logic [3:0] tdsckhcnvh_clk_cnt;
localparam logic [3:0] TDSCKHCNVH_CLK_MAX = 10;


always_ff @(posedge clk or negedge rst_n) begin : State_Register // State Flipflop
    if (!rst_n) begin
        state <= IDLE;
    end else begin
        state <= next_state;
    end
end

always_comb begin : Next_State_Logic // Next State Logic
    next_state = state;
    unique case (state)
        IDLE: if (start) next_state = START;
        START: if (tcnvh_clk_cnt == TCNVH_CLK_MAX) next_state = CONVERT;
        CONVERT: if (tconv_clk_cnt == TCONV_CLK_MAX) next_state = ACQUIRE;
        ACQUIRE: if (tsck_clk_cnt == TSCK_CLK_MAX) next_state = DSCKHCNVH;
        DSCKHCNVH: if (tdsckhcnvh_clk_cnt == TDSCKHCNVH_CLK_MAX) next_state = IDLE;
    endcase
end

always_ff @(posedge clk or negedge rst_n) begin : State_Counters // state ounters
    if (!rst_n) begin
        tcnvh_clk_cnt <= 0;
        tconv_clk_cnt <= 0;
        tsck_clk_cnt <= 0;
        tdsckhcnvh_clk_cnt <= 0;
    end else begin
        if (state == START)     tcnvh_clk_cnt <= tcnvh_clk_cnt + 1;
        else                    tcnvh_clk_cnt <= 0;

        if (state == CONVERT)   tconv_clk_cnt <= tconv_clk_cnt + 1;
        else                    tconv_clk_cnt <= 0;
            
        if (state == ACQUIRE)   tsck_clk_cnt <= tsck_clk_cnt + 1;
        else                    tsck_clk_cnt <= 0;

        if (state == DSCKHCNVH) tdsckhcnvh_clk_cnt <= tdsckhcnvh_clk_cnt + 1;
        else                    tdsckhcnvh_clk_cnt <= 0;    
    end
end

// ====== Output assignment ======
assign nCNV = state == START;
// Although LTC2324 datasheet specifies tDSCKHCNVH as 0ns, the DSCKHCNVH state is added to address CLK-CLKOUT round trip delay to ensure acquisition.
assign valid = (state == DSCKHCNVH) && (tdsckhcnvh_clk_cnt == TDSCKHCNVH_CLK_MAX);


//assign SCK = (state == ACQUIRE) ? clk : 1'b0;
logic sck_en_reg;
    always_ff @(posedge clk or negedge rst_n) begin
        if(!rst_n) sck_en_reg <= 0;
        else       sck_en_reg <= (state == ACQUIRE); 
    end

    ODDR #(
        .DDR_CLK_EDGE("OPPOSITE_EDGE"),
        .INIT(1'b0),
        .SRTYPE("SYNC")
    ) u_sck_gen (
        .Q(SCK),
        .C(clk),
        .CE(1'b1),
        .D1(sck_en_reg),
        .D2(1'b0),
        .R(~rst_n),
        .S(1'b0)
    );
// ====== receive data from SDO pins ======

logic [15:0] shift_ch1, shift_ch2, shift_ch3, shift_ch4;

always_ff @(posedge CLKOUT) begin
    shift_ch1 <= {shift_ch1[14:0], SDO1};
    shift_ch2 <= {shift_ch2[14:0], SDO2};
    shift_ch3 <= {shift_ch3[14:0], SDO3};
    shift_ch4 <= {shift_ch4[14:0], SDO4};
end

// ====== update synchronous ==============

always_ff @(posedge clk or negedge rst_n) begin : SDO_Shift_Register
    if (!rst_n) begin
        ch1 <= 16'd0;
        ch2 <= 16'd0;
        ch3 <= 16'd0;
        ch4 <= 16'd0;
    end else begin
        if (state == DSCKHCNVH && tdsckhcnvh_clk_cnt == 2) begin
            ch1 <= shift_ch1;
            ch2 <= shift_ch2;
            ch3 <= shift_ch3;
            ch4 <= shift_ch4;
        end
    end
end

endmodule
