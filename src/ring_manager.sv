// Ring Manager: schedules DMA work by sending descriptor addresses to the
// Descriptor Fetcher. Tracks progress via head pointer. Generates IRQ events.
// MAX_INFLIGHT=1: at most one descriptor in-flight at any time.

module ring_manager #(
    parameter int MAX_INFLIGHT = dma_pkg::MAX_INFLIGHT  // must be 1
)(
    input  logic clk,
    input  logic rst_n,

    input  logic [dma_pkg::ADDR_WIDTH-1:0] baseaddr,
    input  logic [7:0] ringlen,
    input  logic [7:0] tail,
    input  logic       enable,
    input  logic       reset,
    input  logic       irq_en,
    input  logic       error_clear,

    output logic [7:0] head,
    output logic       busy,
    output logic       ring_empty,
    output logic       irq_empty_set,
    output logic       error_set,

    output logic [dma_pkg::ADDR_WIDTH-1:0] rm_df_addr,
    output logic  fetch_req_valid,
    input  logic  fetch_req_ready,
    input  logic  df_error,
    input  logic  as_done,

    output logic  irq_empty,
    output logic  irq_error
);
    localparam int DESC_SIZE = dma_pkg::DESCRIPTOR_SIZE_BYTES;  // 8

    logic inflight;
    logic was_empty;
    logic int_status_error;

    logic [7:0] head_next;
    logic       inflight_next;
    logic       int_status_error_next;

    assign ring_empty      = (head == tail);
    assign fetch_req_valid = !ring_empty && enable
                             && (ringlen > 8'd0)
                             && !inflight && !int_status_error;
    assign rm_df_addr      = baseaddr
                             + dma_pkg::ADDR_WIDTH'({8'd0, head} << 3);
    assign busy            = inflight;

    assign irq_empty_set   = !was_empty && ring_empty;
    assign error_set       = df_error;
    assign irq_empty       = irq_en && irq_empty_set;
    assign irq_error       = irq_en && error_set;

    always_comb begin
        head_next = head;
        if (fetch_req_valid && fetch_req_ready)
            head_next = (head == (ringlen - 8'd1)) ? 8'd0 : head + 8'd1;

        inflight_next = inflight;
        if (fetch_req_valid && fetch_req_ready && !as_done)
            inflight_next = 1'b1;
        else if ((as_done || df_error) && !(fetch_req_valid && fetch_req_ready))
            inflight_next = 1'b0;

        int_status_error_next = int_status_error;
        if (df_error)    int_status_error_next = 1'b1;
        if (error_clear) int_status_error_next = 1'b0;
    end

    always_ff @(posedge clk) begin
        if (!rst_n || reset) begin
            head             <= '0;
            inflight         <= 1'b0;
            was_empty        <= 1'b1;
            int_status_error <= 1'b0;
        end else begin
            head             <= head_next;
            inflight         <= inflight_next;
            was_empty        <= ring_empty;
            int_status_error <= int_status_error_next;
        end
    end

endmodule
