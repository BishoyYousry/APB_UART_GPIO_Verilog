`timescale 1ns/1ns

/*
 * Simple 8-bit UART realization.
 * Combine receiver, transmitter and baud rate generator.
 * Able to operate 8 bits of serial data, one start bit, one stop bit.
 */
 
module Uart#(
    parameter CLOCK_RATE = 100000000, // board internal clock
    parameter BAUD_RATE = 9600
)(
    input wire clk,
    input wire[31:0] pAdd,      //Is not used
    input wire[31:0] pwData,
    input wire rst_n,
    input wire pwr,
    input wire[1:0] psel,       //If psel == 2'b10 then UART is choose
    input wire pen,
    input wire rxd,
    output wire[31:0] prdata,
    output wire pready,
    output reg txd
);
wire txStart, rxStart, rxDone, txDone, tx_data_out, busy;
wire [7:0] txData, rxData;


// remaining busy, err, parity_err, parity_en
Receiver rxInst (.clk(clk), .rxStart(pen), .done(rxDone), .out(rxData), .in(rxd)); 

//remaining busy
/*transmitter txInst (.tx_clk(clk), .rst_n(rst_n), .tx_start(txStart), .tx_enable(pen), .tx_data_in(txData),
                   .done(txDone), .busy(busy), .tx_data_out(tx_data_out));*/

APB_interface apb_interface(.pAdd(pAdd), .pwData(pwData), .psel(psel), .pen(pen), .pwr(pwr), .rst_n(rst_n),
                            .clk(clk), .prdata(prdata), .pready(pready), .txStart(txStart), .txData(txData),
                            .rxData(rxData), .txDone(txDone), .rxDone(rxDone), .rxStart(rxStart));
endmodule






module tb_Uart();

reg clk, rst_n, pwr, pen, pready, rxd;
reg [1:0] psel;
reg [31:0] pwData, pAdd;
wire prdata, txd;

//Test transmitter
Uart uart(.clk(clk), .pwData(pwData), .pAdd(pAdd), .rst_n(rst_n), .pwr(pwr), .psel(psel), .pen(pen),
          .prdata(prdata), .pready(pready), .rxd(rxd), .txd(txd));

always #1 clk = ~clk;

initial begin
  clk <= 0; pwData <= 0; pAdd <= 0; rst_n <= 0; pwr <= 0; psel <= 2'b00; pen <= 0; 
  #3 pAdd <= 32'd15; pwr <= 1; psel <= 2'b10; rst_n = 1; pen <= 1;
  #2 rxd <= 0; 
  #150 rxd = 1;
end
endmodule







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
  output reg rxStart,    
  output reg txStart,     
  output reg[7:0] txData,   
  output reg[31:0] prdata,
  output reg pready
);

reg [31:0]fifo;    
reg [1:0]count4;       //Indicates that the TX module has read the four bytes from fifo
reg[2:0] state;
reg[2:0] next_state;

localparam [2:0] IDLE            =       3'b000,
                 READY           =       3'b001,
                 FIFO_WRITE      =       3'b010,
                 CHECK_FIFO      =       3'b011,
                 TRANSFER        =       3'b100,
                 RECEIVE         =       3'b101,
                 STORE           =       3'b110,
                 BUS_READ        =       3'b111;





always @(posedge clk or ~rst_n) begin
  if(~rst_n)
    state = IDLE;
  else
    state = next_state;
end


always@(state)begin
  case(state)
    IDLE: begin
      if(psel == 2'b10)      // The Processor wants UART 
        next_state = READY;
    end

    READY: begin    
      if(pwr)       //Write operation -> enable transmitter module
        next_state = CHECK_FIFO;
      else if(~pwr) //Read operation -> enable Receiver module
        next_state = RECEIVE;
    end

    FIFO_WRITE: 
      next_state = CHECK_FIFO;

    CHECK_FIFO: begin
      if(&count4) begin   //if count4 == 2'b11
        next_state <= IDLE;
        count4 <= 0;
      end
      else 
      next_state = TRANSFER;
    end
      

    TRANSFER: begin
      if(txDone)    //Transmitter sent the data 8 bits 
        next_state = CHECK_FIFO;
    end


    RECEIVE: begin
      if(rxDone)     //Receiver received the data 8 bits
        next_state = STORE;
    end


    STORE: begin
      if(&count4)
        next_state = BUS_READ;
      else
        next_state = RECEIVE;
    end

    BUS_READ: begin
      if(pready)
        next_state = IDLE;
    end

  endcase
end


always@(state) begin
  case(state)
    IDLE: begin
      txStart <= 0;
      rxStart <= 0;
      txData <= 0;
      prdata <= 0;
      fifo <= 0;
      pready <= 0;
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
    end


    STORE: begin
      rxStart <= 0;
      fifo[7:0] <= rxData;
      fifo <= fifo << 8;
      count4 <= count4 + 2'b01;
    end

    BUS_READ: begin
      prdata <= fifo;
      pready <= 1;        // Receiver tells the APB bus that the data you want is available now on the bus
    end
  endcase
end
endmodule






/*
 * 8-bit UART Receiver.
 * Able to receive 8 bits of serial data, one start bit, one stop bit.
 * When receive is complete {done} is driven high for one clock cycle.
 * Output data should be taken away by a few clocks or can be lost.
 * When receive is in progress {busy} is driven high.
 * Clock should be decreased to baud rate.
 */
module Receiver (
    input  wire       clk,  // baud rate
    input  wire       rxStart,
    input  wire       in,   // rx
    input  wire       parity_err,
    output reg        parity_en,
    output reg  [7:0] out,  // received data
    output reg        done, // end on transaction
    output reg        busy, // transaction is in process
    output reg        err   // error while receiving data
);

    // states of state machine
    localparam [2:0] RESET         =      3'b000,
                     IDLE          =      3'b001,
                     DATA_BITS     =      3'b010,
                     PARITY        =      3'b011,
                     STOP_BIT      =      3'b100;
    

    reg [2:0] state;
    reg [2:0] bitIdx = 3'b0; // for 8-bit data
    reg [1:0] inputSw = 2'b0; // shift reg for input signal state
    reg [3:0] clockCount = 4'b0; // count clocks for 16x oversample
    reg [7:0] receivedData = 8'b0; // temporary storage for input data



    always @(posedge clk) begin
        inputSw = { inputSw[0], in };

        if (!rxStart) begin
            state = RESET;
        end

        case (state)
            RESET: begin
                out <= 8'b0;
                err <= 1'b0;
                done <= 1'b0;
                busy <= 1'b0;
                bitIdx <= 3'b0;
                clockCount <= 4'b0;
                receivedData <= 8'b0;
                if (rxStart) begin
                    state <= IDLE;
                end
            end

            IDLE: begin
                done <= 1'b0;
                if (clockCount >= 4'b0111) begin
                    state <= DATA_BITS;
                    out <= 8'b0;
                    bitIdx <= 3'b0;
                    clockCount <= 4'b0;
                    receivedData <= 8'b0;
                    busy <= 1'b1;
                    err <= 1'b0;
                end else if (!(&inputSw) || |clockCount) begin
                    // Check bit to make sure it's still low
                    if (&inputSw) begin
                        err <= 1'b1;
                        state <= RESET;
                    end
                    clockCount <= clockCount + 4'b1;
                end
            end

            // Wait 8 full cycles to receive serial data
            DATA_BITS: begin
                if (&clockCount) begin // save one bit of received data
                    clockCount <= 4'b0;
                    // TODO: check the most popular value
                    receivedData[bitIdx] <= inputSw[0];
                    if (&bitIdx) begin
                        bitIdx <= 3'b0;
                        state <= PARITY;
                    end else begin
                        bitIdx <= bitIdx + 3'b1;
                    end
                end else begin
                    clockCount <= clockCount + 4'b1;
                end
            end
  
            PARITY: begin
              if(&clockCount) begin
                clockCount <= 0;
                parity_en <= 1;
                out <= receivedData;  //To send the data to parity checker module
                if(~parity_err)
                  state <= STOP_BIT;
                else
                  state <= RESET;
              end
            else
              clockCount <= clockCount + 4'b1;
            end
            

            /*
            * Baud clock may not be running at exactly the same rate as the
            * transmitter. Next start bit is allowed on at least half of stop bit.
            */
            STOP_BIT: begin
                if (&clockCount || (clockCount >= 4'h8 && !(|inputSw))) begin
                    state <= IDLE;
                    done <= 1'b1;
                    busy <= 1'b0;
                    out <= receivedData;
                    clockCount <= 4'b0;
                end else begin
                    clockCount <= clockCount + 1;
                    // Check bit to make sure it's still high
                    if (!(|inputSw)) begin
                        err <= 1'b1;
                        state <= RESET;
                    end
                end
            end
            default: state <= IDLE;
        endcase
    end
endmodule





module tb_receiver();
  reg clk, rxStart, in;
  wire parity_en;
  wire parity_err;
  wire done, busy, err;
  wire [7:0]out;
  Receiver receiver(.parity_en(parity_en), .clk(clk), .rxStart(rxStart), .in(in), .parity_err(parity_err), .out(out), .busy(busy), .err(err), .done(done));
  PARITY_CHECK parity_check(.parity_en(parity_en), .rx(in), .rx_data_in(out), .parity_err(parity_err));
  always #1 clk = ~clk;
  
  initial begin
    clk <= 0; rxStart <= 1; in <= 0;
    #3 in = 0; 
    #2 rxStart = 1;
    #32 in = 1;
    #32 in = 0;
    #32 in = 1;
    #32 in = 0; 
    #32 in = 1;
    #32 in = 0;
    #32 in = 1;
    #32 in = 1;
    #32 in = 0;   // Parity bit (Parity error)
    #32 in = 1;   //stop bit                   
  end
endmodule






module PARITY_CHECK(parity_err, parity_en, rx, rx_data_in);
  input[7:0] rx_data_in;
  input wire rx, parity_en;
  output reg parity_err;
  
  always@(*) begin    //if any of the upper signals changed
    if(parity_en) begin
      if(rx == (^rx_data_in)) begin   //Even Parity check
        parity_err <= 0;
      end
    else begin
      parity_err <= 1;
    end
  end
    else
      parity_err <= 0;
  end
endmodule


module tb_parity();
  reg rx, parity_en;
  reg[7:0] rx_data_in;
  PARITY_CHECK parity_check(.parity_en(parity_en), .rx(rx), .rx_data_in(rx_data_in));
  initial begin
    parity_en = 0; rx = 0; rx_data_in = 8'b00000000;
    #2  parity_en <= 1; rx <= 1; rx_data_in <= 8'b11110000;   //There is parity error    
    #2  parity_en = 0;
    #2  parity_en <= 1; rx_data_in <= 8'b11000000;             //There is no parity error
  end
endmodule
