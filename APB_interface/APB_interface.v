
module APB_interface
(
  input wire [31:0] pAdd,    //Is not used
  input wire [31:0] pwData,      
  input wire [1:0] psel,       //if psel == 10 -> choose UART
  input wire pen,
  input wire pwr,             //if pwr == 1 -> enable TX, else enable RX
  input wire rst_n,         
  input wire clk,  
  input wire [7:0] rxData,
  input wire rxDone,           //Indication that receiver received 8 bits
  input wire txDone,           //Indication that transmitter sent 8 bits
  input wire err_in,
  input wire busy,
  output reg rxStart,    
  output reg txStart,     
  output reg[7:0] txData,   
  output reg[31:0] prdata,
  output reg pready,
  output reg rx_en,
  output reg tx_en
);

reg [31:0]fifo;    
reg [1:0]count4;       //Indicates that the TX module has read the four bytes from fifo
reg[3:0] state;
reg[3:0] next_state;

localparam [3:0] IDLE            =       4'b0000,
                 READY           =       4'b0001,
                 FIFO_WRITE      =       4'b0010,
                 CHECK_FIFO      =       4'b0011,
                 TRANSFER        =       4'b0100,
                 RECEIVE         =       4'b0101,
                 STORE           =       4'b0110,
                 BUS_READ        =       4'b0111,
                 SHIFT           =       4'b1000;



always @(posedge clk or ~rst_n) begin
  if(~rst_n)
    state <= IDLE;
  else
    state <= next_state;
end


always@(state or posedge rxDone or posedge txDone) begin
  case(state)
    IDLE: begin
      if(psel == 2'b10)      // The Processor wants UART 
        next_state <= READY;
    end

    READY: begin    
      if(pwr)       //Write operation -> enable transmitter module
        next_state <= CHECK_FIFO;
      else if(~pwr) //Read operation -> enable Receiver module
        next_state <= RECEIVE;
    end

    FIFO_WRITE: 
      next_state <= CHECK_FIFO;

    CHECK_FIFO: begin
      if(&count4) begin   //if count4 == 2'b11
        next_state <= IDLE;
        count4 <= 0;
      end
      else 
      next_state <= TRANSFER;
    end   

    TRANSFER: begin
      if(txDone)    //Transmitter sent the data 8 bits 
        next_state <= CHECK_FIFO;
    end

    RECEIVE: begin
      if(rxDone) begin    //Receiver received the data 8 bits
        next_state <= STORE;
      end
    end

    STORE: begin  
      if(&count4)  // the 4 bytes are stored in fifo
        next_state <= BUS_READ;
      else
        next_state <= SHIFT;
    end

    SHIFT: begin      
      next_state <= RECEIVE;
    end

    BUS_READ: begin
      if(pready)
        next_state <= IDLE;
    end
  endcase
end


always@(state) begin
  case(state)
    IDLE: begin
      next_state <= READY;
      txStart <= 0;
      rxStart <= 0;
      txData <= 0;
      prdata <= 0;
      fifo <= 0;
      pready <= 0;
      rx_en <= 0;
      tx_en <= 0;
      count4 <= 0;
    end


    READY: begin
      txStart <= 0;
      rxStart <= 0;
      txData <= 0;
      prdata <= 0;
      fifo <= 0;
      pready <= 1;
    end

    FIFO_WRITE: begin
      pready <= 0;
      if(pen) fifo <= pwData;

    end


    CHECK_FIFO: begin
      txStart <= 0;
      tx_en <= 1;
      txData <= fifo[7:0];
      fifo <= fifo >> 8;
      count4 <= count4 + 2'b01;
    end


    TRANSFER: begin
      txStart <= 1;
    end


    RECEIVE: begin
      pready <= 0;
      rxStart <= 1;
      rx_en <= 1;
    end


    STORE: begin
      rxStart <= 0;
      count4 <= (count4 + 2'b01);
      fifo[7:0] <= rxData;
    end

    SHIFT: begin      
      fifo <= (fifo << 8);
    end


    BUS_READ: begin
      prdata <= fifo;
      pready <= 1;        // Receiver tells the APB bus that the data you want is available now on the bus
    end
  endcase
end
endmodule