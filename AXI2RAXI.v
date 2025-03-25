
--> 設計一個 精簡版 Reduced IO AXI-Lite Slave 包含 256個 32-bit register 

1. IO 定義 
module raxi_device (
    input  wire         RESETn,      // System Reset 
    input  wire         iclk,        // System Clock 
	// RAXI Interface 
    input  wire         raxi_rvalid,  // CPU Read 
	input  wire         raxi_wvalid,  // CPU Write   
	output reg          raxi_ready,   // Slave Ready   
    input  wire [31:0]  raxi_address, // Address 0xFFFFFF00~  
    input  wire [31:0]  raxi_wdata,   // Write Data 
    output reg  [31:0]  raxi_rdata,   // Read Data  
	
);
2.  internal register 
    (1) 16 個 32-bit register  Slave_reg [0:15]  // 16個 32-bit 內部暫存器 
    (2) reg raxi_ready  //  指示 Slave 完成交易    
	(3) reg clk_count;  // 8-bit counter to generate signal output    
	
3.  這slave包含 FSM: State_IDLE, State_READ, State_WRITE 三個 states  
	
4.  16 個 register 位址定義  0xFFFFFFF0 ~ 0xFFFFFFFF  
	
5.  以下是整個 Slave FSM operation Description 
       	   	   
    State_IDLE:  
        if(raxi_rvalid)   
		       state = State_READ 	    			
        else if(raxi_wvalid) state = State_WRITE 
                
    State_READ:     
	  raxi_rdata <= Slave_reg[raxi_address[5:2]]    // 1 Byte = 1個 address , 32-bit 占用 4個  
	  raxi_ready = 1                // 表示完成讀取  
	  if(raxi_rvalid=0)             // 表示 CPU 確認  
         raxi_ready=0               // 完成交易 
         state = State_IDLE;        // 回到 IDLE 
      end   		 	  	  
	  
	State_WRITE: 
      Slave_reg[raxi_address[5:2]] = raxi_wdata 
	  raxi_ready = 1                // 表示完成寫入   
	  if(raxi_wvalid=0)             // 表示 CPU 確認  
         raxi_ready=0               // 完成交易 
         state = State_IDLE;        // 回到 IDLE 
      end
 	


	
 --> 替這個 Reduced IO AXI-Lite Slave verilog 設計一個 testbench 

1.  產生 RAXI 寫入 與 讀取 訊號 , 比對資料 
    (0) 輸出控制訊號 raxi_rvalid , raxi_wvalid
    (1) wait(raxi_ready)  等待 Slave ready 	
    (2) 連續寫入 16個 data , 位址 0xFFFFFF00 ~ 0xFFFFFF40 
	(3) 連續讀出 16個 data 
    (4) 列印 讀寫過程  	
    (5) 比對 讀寫資料是否一致 
    (6) 使用 task 簡化testbench    	

2.  產生 VCD waveform   

3. 參考以下 task design  
task write_register;
    input [ADDR_WIDTH-1:0] addr;
    input [DATA_WIDTH-1:0] data;
    begin
        raxi_wvalid  = 1'b1;
        raxi_rvalid  = 1'b0;
        raxi_address = addr;
        raxi_wdata   = data;
        @(posedge iclk);
        #(1);
        while (~raxi_ready) @(posedge iclk);
        @(posedge iclk);
        raxi_wvalid  = 1'b0;
        @(posedge iclk);
        #(1);
    end
endtask

// ---------------------------------------
// Read Task
// ---------------------------------------
task read_register;
    input [ADDR_WIDTH-1:0] addr;
    output [DATA_WIDTH-1:0] read_data;
    begin
        raxi_wvalid  = 1'b0;
        raxi_rvalid  = 1'b1;
        raxi_address = addr;
        @(posedge iclk);
        #(1);
        while (~raxi_ready) @(posedge iclk);
        @(posedge iclk);
        read_data    = raxi_rdata;
        raxi_rvalid  = 1'b0;
        @(posedge iclk);
        #(1);
    end
endtask



-->  替這個 Reduced IO AXI-Lite Slave verilog 與 testbench 撰寫 Makefile 
     使用 iverilog 與 gtkwave 
	 
	 