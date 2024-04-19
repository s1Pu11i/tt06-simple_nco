# SPDX-FileCopyrightText: © 2024 Tiny Tapeout
# SPDX-License-Identifier: MIT

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles
import numpy as np
from scipy import signal

# create int from logic array
def logic_array_to_int(logic_array):
  idx = 0
  value_int = 0
  for x in reversed(logic_array):
    tmp = int(x)
    value_int += tmp << idx
    idx += 1
  return value_int

# reference sine output
def create_ref_values_sine():
  resolution_full = 2**10
  length_full = 2 * np.pi
  values_float_full = np.sin(np.arange(0, length_full, length_full / resolution_full))
  values_int_full = np.round(values_float_full * (2**7-1) + 128)
  return values_int_full

@cocotb.test()
async def test_project(dut):
  dut._log.info("Start")
  
  # Our example module doesn't use clock and reset, but we show how to use them here anyway.
  clock = Clock(dut.clk, 20, units="ns")
  cocotb.start_soon(clock.start())

  # Reset
  dut._log.info("Reset")
  dut.ena.value = 1
  dut.ui_in.value = 0
  dut.uio_in.value = 0
  dut.rst_n.value = 0
  await ClockCycles(dut.clk, 10)
  dut.rst_n.value = 1

  # Set the input values, wait one clock cycle, and check the output
  dut._log.info("Set Lowest Frequency word to address Sine ROM")
  dut.uio_in.value = 4
  dut.ui_in.value = 64
  await ClockCycles(dut.clk, 1)
  dut.uio_in.value = 8
  dut.ui_in.value = 0
  # enable sine output
  await ClockCycles(dut.clk, 1)
  dut.uio_in.value = 1
  #await ClockCycles(dut.clk, 2000)
  await ClockCycles(dut.clk, 3)
  ref_sine = create_ref_values_sine()
  for x in ref_sine:
    await ClockCycles(dut.clk, 1)
    dut._log.info("DUT value: %d" % logic_array_to_int(dut.uo_out.value))
    dut._log.info("REF (sine) value: %d" % x)
    assert logic_array_to_int(dut.uo_out.value) == x

  dut._log.info("Set some higher frequency word and switch to square output")
  dut.uio_in.value = 0
  await ClockCycles(dut.clk, 1)
  dut.uio_in.value = 4
  dut.ui_in.value = 0
  await ClockCycles(dut.clk, 1)
  dut.uio_in.value = 8
  dut.ui_in.value = 32
  # enable square for 2k cycles
  await ClockCycles(dut.clk, 1)
  dut.uio_in.value = 2
  await ClockCycles(dut.clk, 3)
  dut._log.info("DUT value: %d" % logic_array_to_int(dut.uo_out.value))
  dut._log.info("REF value: 0")
  assert logic_array_to_int(dut.uo_out.value) == 0
  await ClockCycles(dut.clk, 2000)

  dut._log.info("Set some higher frequency word and switch to sawtooth output")
  dut.uio_in.value = 0
  await ClockCycles(dut.clk, 1)
  dut.uio_in.value = 4
  dut.ui_in.value = 0
  await ClockCycles(dut.clk, 1)
  dut.uio_in.value = 8
  dut.ui_in.value = 48
  # enable sawtooth for 2k cycles
  await ClockCycles(dut.clk, 1)
  dut.uio_in.value = 3
  await ClockCycles(dut.clk, 2000)

  dut._log.info("Set output to 0")
  dut.uio_in.value = 0
  await ClockCycles(dut.clk, 3)
  dut._log.info("DUT value: %d" % logic_array_to_int(dut.uo_out.value))
  dut._log.info("REF value: 0")
  assert dut.uo_out.value == 0

  dut._log.info("## TEST DONE ##")
