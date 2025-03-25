// AXI Slave IF for Xilinx PS 
// Without Support : S_WLAST & Burst 
// FPGA PS --> AXI Slave --> RAXI 

`timescale 1ns / 1ps

module axi_slave #(
    parameter C_AXI_ID_WIDTH   = 4,
    parameter C_AXI_DATA_WIDTH = 32,
    parameter C_AXI_ADDR_WIDTH = 32,
    parameter SLAVE_ADDR       = 8'h00  // Slave Address
)
(
    input  wire                      S_ACLK,
    input  wire                      S_ARESETN,

    // AXI Write Address Channel
    input  wire [C_AXI_ID_WIDTH-1:0]   S_AWID,
    input  wire [C_AXI_ADDR_WIDTH-1:0] S_AWADDR,
    input  wire [2:0]                  S_AWPROT,
    input  wire [7:0]                  S_AWLEN,
    input  wire                        S_AWVALID,
    output reg                         S_AWREADY,

    // AXI Write Data Channel
    input  wire [C_AXI_DATA_WIDTH-1:0]     S_WDATA,
    input  wire [(C_AXI_DATA_WIDTH/8)-1:0] S_WSTRB,
    input  wire                            S_WVALID,
    output reg                             S_WREADY,

    // AXI Write Response Channel
    output reg [C_AXI_ID_WIDTH-1:0] S_BID,
    output reg [1:0]                S_BRESP,
    output reg                      S_BVALID,
    input  wire                     S_BREADY,

    // AXI Read Address Channel
    input  wire [C_AXI_ID_WIDTH-1:0]   S_ARID,
    input  wire [C_AXI_ADDR_WIDTH-1:0] S_ARADDR,
    input  wire [2:0]                  S_ARPROT,
    input  wire [7:0]                  S_ARLEN,
    input  wire                        S_ARVALID,
    output reg                         S_ARREADY,

    // AXI Read Data Channel
    output reg [C_AXI_ID_WIDTH-1:0]    S_RID,
    output wire [C_AXI_DATA_WIDTH-1:0] S_RDATA,
    output reg [1:0]                   S_RRESP,
    output reg                         S_RLAST,
    output reg                         S_RVALID,
    input  wire                        S_RREADY,

    // External Control Interface
    output wire                      raxi_rvalid,
    output wire                      raxi_wvalid,
    input  wire                      raxi_ready,
    output wire [31:0]               raxi_address,
    output wire [31:0]               raxi_wdata,
    input  wire [31:0]               raxi_rdata
);

// Internal state
reg [7:0] data_count;
reg [2:0] state;
localparam IDLE = 3'd0, WRITE_ADDR = 3'd1, WRITE_DATA = 3'd2, WRITE_RESP = 3'd3, READ_ADDR = 3'd4, READ_DATA = 3'd5;

assign raxi_rvalid = S_RVALID & S_RREADY;
assign raxi_wvalid = S_WVALID & S_WREADY;
assign raxi_address = (state==WRITE_DATA) ? S_AWADDR : S_ARADDR;
assign raxi_wdata = S_WDATA;
assign S_RDATA = raxi_rdata;

always @(posedge S_ACLK) begin
    if (!S_ARESETN) begin
        state      <= IDLE;
        S_AWREADY  <= 1'b0;
        S_WREADY   <= 1'b0;
        S_BVALID   <= 1'b0;
        S_BRESP    <= 2'b00;
        S_BID      <= {C_AXI_ID_WIDTH{1'b0}};
        S_ARREADY  <= 1'b0;
        S_RVALID   <= 1'b0;
        S_RRESP    <= 2'b00;
        S_RLAST    <= 1'b0;
        S_RID      <= {C_AXI_ID_WIDTH{1'b0}};
        data_count <= 0;
    end else begin
        case(state)
            IDLE: begin
                S_AWREADY <= S_AWVALID && (S_AWADDR[31:24]==SLAVE_ADDR);
                S_ARREADY <= ~S_AWREADY && S_ARVALID && (S_ARADDR[31:24]==SLAVE_ADDR);
                if (S_AWREADY) state <= WRITE_ADDR;
                else if (S_ARREADY) state <= READ_ADDR;
            end

            WRITE_ADDR: begin
                S_AWREADY <= 1'b0;
                S_WREADY  <= 1'b1;
                state     <= WRITE_DATA;
                data_count<= 0;
            end

            WRITE_DATA: begin
                if (S_WVALID && S_WREADY) begin
                    if (data_count == S_AWLEN) begin
                        S_WREADY <= 1'b0;
                        state    <= WRITE_RESP;
                        S_BID    <= S_AWID;
                        S_BRESP  <= 2'b00;
                        S_BVALID <= 1'b1;
                    end else data_count <= data_count + 1;
                end
            end

            WRITE_RESP: begin
                if (S_BVALID && S_BREADY) begin
                    S_BVALID <= 1'b0;
                    state    <= IDLE;
                end
            end

            READ_ADDR: begin
                S_ARREADY <= 1'b0;
                S_RVALID  <= 1'b1;
                S_RRESP   <= 2'b00;
                S_RID     <= S_ARID;
                state     <= READ_DATA;
                data_count<= 0;
            end

            READ_DATA: begin
                if (S_RVALID && S_RREADY) begin
                    S_RLAST <= (data_count == S_ARLEN);
                    if (data_count == S_ARLEN) begin
                        S_RVALID <= 1'b0;
                        S_RLAST  <= 1'b0;
                        state    <= IDLE;
                    end else data_count <= data_count + 1;
                end
            end
        endcase
    end
end
endmodule
