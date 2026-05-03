# SPDX-FileCopyrightText: © 2024 Tiny Tapeout
# SPDX-License-Identifier: Apache-2.0

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles


@cocotb.test()
async def test_project(dut):
    dut._log.info("Start")

    clock = Clock(dut.clk, 10, unit="us")
    cocotb.start_soon(clock.start())

    # Reset
    dut._log.info("Reset")
    dut.ena.value = 1
    dut.ui_in.value = 0
    dut.uio_in.value = 0
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 10)
    dut.rst_n.value = 1

    # SPI_CSN = ui_in[2] = 1 (inactive), all others 0
    dut.ui_in.value = 0b00000100
    dut.uio_in.value = 0
    await ClockCycles(dut.clk, 2)

    dut._log.info("Check idle state after reset")

    # In idle: DMA disabled, head=tail=0 so probe_ring_empty (uo_out[6]) = 1,
    # all other outputs (IRQ, SPI MISO, probes) = 0  =>  uo_out = 0b01000000 = 64
    assert dut.uo_out.value == 0b01000000, \
        f"Expected uo_out=0b01000000 in idle state, got {dut.uo_out.value:#010b}"
