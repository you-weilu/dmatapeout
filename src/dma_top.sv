// DMA top-level: SPI-CSR + Ring Manager + Movement Top + IRQ.
// External interface: SPI (4 pins) + single IRQ output + probe pins.

module dma_top #(
    parameter int MAX_INFLIGHT = dma_pkg::MAX_INFLIGHT
) (
    input  logic clk,
    input  logic rst_n,

    // SPI CSR interface (mode 0, MSB first)
    input  logic spi_sclk,
    input  logic spi_mosi,
    output logic spi_miso,
    input  logic spi_csn,

    // Consolidated interrupt output
    output logic irq,

    // Probe outputs (map directly to TinyTapeout uo_out / uio pins)
    output logic       probe_fetch_req_valid,
    output logic       probe_df_in_wr_en,
    output logic       probe_dm_wr_en,
    output logic       probe_dm_instr_rw,
    output logic       probe_ring_empty,
    output logic       probe_busy,
    output logic [7:0] probe_rm_df_addr_lo
);

    // CSR <-> Ring Manager wires (flattened from csr_ring_manager_if)
    logic [dma_pkg::ADDR_WIDTH-1:0] csr_baseaddr;
    logic [7:0] csr_ringlen;
    logic [7:0] csr_tail;
    logic       csr_enable;
    logic       csr_reset;
    logic       csr_irq_en;
    logic       csr_error_clear;
    logic [7:0] csr_head;
    logic       csr_busy;
    logic       csr_ring_empty;
    logic       csr_irq_empty_set;
    logic       csr_error_set;

    logic rst_core_n;
    assign rst_core_n = rst_n & ~csr_reset;

    logic irq_clr_pe0, irq_clr_pe1;

    spi_csr u_csr (
        .clk                  (clk),
        .rst_n                (rst_n),
        .sclk                 (spi_sclk),
        .mosi                 (spi_mosi),
        .miso                 (spi_miso),
        .csn                  (spi_csn),
        .baseaddr             (csr_baseaddr),
        .ringlen              (csr_ringlen),
        .tail                 (csr_tail),
        .enable               (csr_enable),
        .reset                (csr_reset),
        .irq_en               (csr_irq_en),
        .error_clear          (csr_error_clear),
        .head                 (csr_head),
        .busy                 (csr_busy),
        .ring_empty           (csr_ring_empty),
        .irq_empty_set        (csr_irq_empty_set),
        .error_set            (csr_error_set),
        .irq_clear_pulse_empty(irq_clr_pe0),
        .irq_clear_pulse_error(irq_clr_pe1)
    );

    logic [dma_pkg::ADDR_WIDTH-1:0] rm_df_addr;
    logic                           fetch_req_valid;
    logic                           fetch_req_ready;
    logic                           df_error;
    logic                           dm_done;

    ring_manager #(
        .MAX_INFLIGHT(MAX_INFLIGHT)
    ) u_ring_manager (
        .clk           (clk),
        .rst_n         (rst_n),
        .baseaddr      (csr_baseaddr),
        .ringlen       (csr_ringlen),
        .tail          (csr_tail),
        .enable        (csr_enable),
        .reset         (csr_reset),
        .irq_en        (csr_irq_en),
        .error_clear   (csr_error_clear),
        .head          (csr_head),
        .busy          (csr_busy),
        .ring_empty    (csr_ring_empty),
        .irq_empty_set (csr_irq_empty_set),
        .error_set     (csr_error_set),
        .rm_df_addr    (rm_df_addr),
        .fetch_req_valid(fetch_req_valid),
        .fetch_req_ready(fetch_req_ready),
        .df_error      (df_error),
        .as_done       (dm_done),
        .irq_empty     (),
        .irq_error     ()
    );

    IRQ u_irq (
        .clk        (clk),
        .rst_n      (rst_n),
        .empty_event(csr_irq_empty_set),
        .error_event(csr_error_set),
        .irq_en     (csr_irq_en),
        .irq_clear  ({irq_clr_pe1, irq_clr_pe0}),
        .irq_status (),
        .irq        (irq)
    );

    movement_top u_movement (
        .clk              (clk),
        .rst_n            (rst_core_n),
        .rm_df_addr       (rm_df_addr),
        .rm_df_valid      (fetch_req_valid),
        .df_ready         (fetch_req_ready),
        .df_error         (df_error),
        .dm_done          (dm_done),
        .probe_df_in_wr_en(probe_df_in_wr_en),
        .probe_dm_wr_en   (probe_dm_wr_en),
        .probe_dm_instr_rw(probe_dm_instr_rw)
    );

    assign probe_fetch_req_valid = fetch_req_valid;
    assign probe_ring_empty      = csr_ring_empty;
    assign probe_busy            = csr_busy;
    assign probe_rm_df_addr_lo   = rm_df_addr[7:0];

endmodule
