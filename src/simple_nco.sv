/*
 * Copyright (c) 2024 s1pu11i
 * SPDX-License-Identifier: Apache-2.0
 */

`define default_netname none

module simple_nco (
  input  logic clk,
  input  logic rst_n,
  input  logic enable,
  input  logic [7:0] dataIn,
  input  logic [7:0] ctrlIn,
  output logic [7:0] dataOut
);

  logic [1:0] modeSelection;
  logic storeUpperPartOfFreqControlWord;
  logic storeLowerPartOfFreqControlWord;
  logic freqControlWordUpdated;
  logic [15:0] freqControlWord;
  logic [15:0] phaseAccumulator;
  logic [9:0] phaseAccuTruncated;
  logic phaseAccuTruncatedMsb;
  logic phaseAccuTruncQuarter;
  logic [7:0] sineRomAddr;
  logic [7:0] sineOut;
  logic [7:0] squareOut;
  logic [7:0] sawtoothOut;
  logic [7:0] outputMux;

  // output
  assign dataOut = outputMux;

  // mode selection: 0 off, 1 sine, 2 square, 3 saw-tooth
  assign modeSelection = ctrlIn[1:0];

  // frequency control word load enable upper and lower part
  assign freqControlWordUpdated = ctrlIn[2] | ctrlIn[3];
  assign storeLowerPartOfFreqControlWord = ctrlIn[2];
  assign storeUpperPartOfFreqControlWord = ctrlIn[3];

  // Loading new frequency control word
  always_ff @(posedge clk, negedge rst_n) begin : FreqWordLoadLbl
    if (~rst_n)
      freqControlWord <= 16'h8; // reset to some value
    else if (enable) begin
      if (storeUpperPartOfFreqControlWord) begin
        freqControlWord[15:8] <= dataIn;
      end
      if (storeLowerPartOfFreqControlWord) begin
        freqControlWord[7:0] <= dataIn;
      end
    end
  end : FreqWordLoadLbl

  // Phase accumulator
  always_ff @(posedge clk, negedge rst_n) begin : PhaseAccuLbl
    if (~rst_n) begin
      phaseAccumulator <= 16'h0;
    end
    else if (enable) begin
      if (freqControlWordUpdated)
        phaseAccumulator <= 16'h0;
      else
        phaseAccumulator <= phaseAccumulator + freqControlWord;
    end
  end : PhaseAccuLbl

  // truncate to 10 bits
  assign phaseAccuTruncated = phaseAccumulator[15:6];

  assign phaseAccuTruncQuarter = ~|phaseAccuTruncated[7:0];
 
  // Sine ROM Table
  reg [7:0] sineRomTable [0:255];
  initial begin
    $readmemh("../src/sine.rom", sineRomTable);
  end

  // Sine ROM address generation
  always_ff @(posedge clk, negedge rst_n) begin : AddrGenLbl
    if (~rst_n) begin
      sineRomAddr <= 8'h0;
      phaseAccuTruncatedMsb <= 1'b0;
    end
    else if (enable) begin
      if (phaseAccuTruncQuarter && ((phaseAccuTruncated[9:8] == 2'd1) || (phaseAccuTruncated[9:8] == 2'd3))) begin
        sineRomAddr <= 8'hFF;
      end
      else if (phaseAccuTruncated[8]) begin
        sineRomAddr <= ~(phaseAccuTruncated[7:0] - 1);
      end
      else begin
        sineRomAddr <= phaseAccuTruncated[7:0];
      end
      // just the 2 MSBs registered (means also same delay as sineRomAddr)
      phaseAccuTruncatedMsb <= phaseAccuTruncated[9];
    end
  end : AddrGenLbl

  // Generated Sine
  always_ff @(posedge clk, negedge rst_n) begin : SinePacLbl
    if (~rst_n)
      sineOut <= 8'h0;
    else if (enable)
      if (phaseAccuTruncatedMsb) begin
        sineOut <= ~sineRomTable[sineRomAddr] + 1;
      end
      else begin
        sineOut <= sineRomTable[sineRomAddr];
      end
  end : SinePacLbl

  // Square output
  always_ff @(posedge clk, negedge rst_n) begin : SquareLbl
    if (~rst_n)
      squareOut <= 8'h0;
    else if (enable)
      if (phaseAccuTruncatedMsb)
        squareOut <= 8'hFF;
      else
        squareOut <= 8'h0;
  end : SquareLbl

  // Sawtooth output (simply the further truncated phase accumulator)
  assign sawtoothOut = phaseAccuTruncated[9:2];
  
  // Output mux
  always_ff @(posedge clk, negedge rst_n) begin : OutputMuxLbl
    if (~rst_n)
      outputMux <= 8'h0;
    else if (enable) begin
      case(modeSelection)
        2'd1: begin
          outputMux <= sineOut;
        end
        2'd2: begin
          outputMux <= squareOut;
        end
        2'd3: begin
          outputMux <= sawtoothOut;
        end
        default: begin
          outputMux <= 8'h0;
        end
      endcase
    end
  end : OutputMuxLbl

endmodule : simple_nco
