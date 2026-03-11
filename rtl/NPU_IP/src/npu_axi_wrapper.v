`timescale 1ns / 1ps

module npu_axi_wrapper (
    // System Clock & Reset
    input  wire aclk,
    input  wire aresetn,

    // ==========================================
    // 1. AXI4-Lite Slave Interface (CPU 제어 버스)
    // ==========================================
    input  wire [4:0]  s_axi_awaddr,
    input  wire        s_axi_awvalid,
    output wire        s_axi_awready,
    input  wire [31:0] s_axi_wdata,
    input  wire [3:0]  s_axi_wstrb,
    input  wire        s_axi_wvalid,
    output wire        s_axi_wready,
    output wire [1:0]  s_axi_bresp,
    output wire        s_axi_bvalid,
    input  wire        s_axi_bready,
    input  wire [4:0]  s_axi_araddr,
    input  wire        s_axi_arvalid,
    output wire        s_axi_arready,
    output wire [31:0] s_axi_rdata,
    output wire [1:0]  s_axi_rresp,
    output wire        s_axi_rvalid,
    input  wire        s_axi_rready,

    // ==========================================
    // 2. [변경] BRAM Full Interface (Read 전용)
    //    - 기존 AXI4-Stream Slave 포트를 제거하고
    //      BRAM 직접 읽기 포트로 교체
    // ==========================================
    output wire [31:0]  bram_addr,    // NPU wrapper가 생성하는 픽셀 주소
    output wire         bram_en,      // BRAM 읽기 enable
    input  wire [31:0]  bram_rdata,   // BRAM에서 읽어온 픽셀 데이터 (8bit)

    // ==========================================
    // 3. AXI4-Stream Master (NPU에서 나가는 최종 결과) - 유지
    // ==========================================
    output wire [31:0] m_axis_tdata,
    output wire        m_axis_tvalid,
    input  wire        m_axis_tready,
    output wire        m_axis_tlast
);

    // --------------------------------------------------
    // [Part 1] AXI-Lite 레지스터 맵 (기존과 동일)
    // --------------------------------------------------
    reg [31:0] slv_reg0; // 제어 레지스터 (Bit 0: start, Bit 1: pad_en)
    reg [31:0] slv_reg1; // 해상도 (상위 16비트: Height, 하위 16비트: Width)
    reg [31:0] slv_reg2; // Weight 0~3
    reg [31:0] slv_reg3; // Weight 4~7
    reg [31:0] slv_reg4; // Bias(16bit) & Weight 8(8bit)

    reg awready_reg, wready_reg, bvalid_reg;
    assign s_axi_awready = awready_reg;
    assign s_axi_wready  = wready_reg;
    assign s_axi_bvalid  = bvalid_reg;
    assign s_axi_bresp   = 2'b00;

    always @(posedge aclk) begin
        if (!aresetn) begin
            awready_reg <= 0; wready_reg <= 0; bvalid_reg <= 0;
        end else begin
            if (s_axi_awvalid && !awready_reg) awready_reg <= 1;
            else awready_reg <= 0;

            if (s_axi_wvalid && !wready_reg) wready_reg <= 1;
            else wready_reg <= 0;

            if (awready_reg && wready_reg) bvalid_reg <= 1;
            else if (s_axi_bready && bvalid_reg) bvalid_reg <= 0;
        end
    end

    wire [2:0] reg_addr = s_axi_awaddr[4:2];
    always @(posedge aclk) begin
        if (!aresetn) begin
            slv_reg0 <= 0; slv_reg1 <= 0; slv_reg2 <= 0; slv_reg3 <= 0; slv_reg4 <= 0;
        end else if (awready_reg && wready_reg) begin
            case (reg_addr)
                3'h0: slv_reg0 <= s_axi_wdata;
                3'h1: slv_reg1 <= s_axi_wdata;
                3'h2: slv_reg2 <= s_axi_wdata;
                3'h3: slv_reg3 <= s_axi_wdata;
                3'h4: slv_reg4 <= s_axi_wdata;
            endcase
        end else begin
            if (slv_reg0[0]) slv_reg0[0] <= 1'b0;
        end
    end

    assign s_axi_arready = 1'b1;
    assign s_axi_rvalid  = s_axi_arvalid;
    assign s_axi_rdata   = 32'd0;
    assign s_axi_rresp   = 2'b00;

    // --------------------------------------------------
    // [Part 2] BRAM Read FSM
    //    - start 신호가 오면 BRAM 주소를 0부터 순차 증가
    //    - BRAM 레이턴시 1클럭을 고려하여 pixel_valid를
    //      bram_en을 1클럭 지연시켜 생성
    // --------------------------------------------------
    wire [31:0] total_pixels = slv_reg1[15:0] * slv_reg1[31:16]; // Width * Height

    reg [31:0] addr_cnt;
    reg        reading;      // BRAM 읽기 진행 중 플래그
    reg        bram_en_reg;
    reg        pixel_valid_reg;

    // 읽기 시작/종료 제어
    always @(posedge aclk) begin
        if (!aresetn) begin
            addr_cnt       <= 0;
            reading        <= 0;
            bram_en_reg    <= 0;
            pixel_valid_reg <= 0;
        end else begin
            // start 펄스 감지 → 읽기 시작
            if (slv_reg0[0] && !reading) begin
                addr_cnt    <= 0;
                reading     <= 1;
                bram_en_reg <= 1;
            end

            if (reading) begin
                // BRAM 레이턴시 1클럭: bram_en을 1클럭 지연 → pixel_valid
                pixel_valid_reg <= bram_en_reg;

                if (addr_cnt < total_pixels - 1) begin
                    addr_cnt    <= addr_cnt + 1;
                    bram_en_reg <= 1;
                end else begin
                    // 마지막 주소 읽기 완료
                    bram_en_reg <= 0;
                    reading     <= 0;
                    addr_cnt    <= 0;
                end
            end else begin
                pixel_valid_reg <= 0;
                bram_en_reg     <= 0;
            end
        end
    end

    assign bram_addr = addr_cnt;
    assign bram_en   = bram_en_reg;

    // --------------------------------------------------
    // [Part 3] npu_top 조립 및 신호 맵핑
    // --------------------------------------------------
    wire [3:0] final_digit;
    wire       final_valid;
    wire       done_tick;

    npu_top u_npu (
        .clk         (aclk),
        .reset_p     (~aresetn),

        .start       (slv_reg0[0]),
        .reg_pad_en  (slv_reg0[1]),
        .reg_img_w   (slv_reg1[15:0]),
        .reg_img_h   (slv_reg1[31:16]),

        .weight_in_0 (slv_reg2[7:0]),
        .weight_in_1 (slv_reg2[15:8]),
        .weight_in_2 (slv_reg2[23:16]),
        .weight_in_3 (slv_reg2[31:24]),

        .weight_in_4 (slv_reg3[7:0]),
        .weight_in_5 (slv_reg3[15:8]),
        .weight_in_6 (slv_reg3[23:16]),
        .weight_in_7 (slv_reg3[31:24]),

        .weight_in_8 (slv_reg4[7:0]),
        .bias_in     (slv_reg4[23:8]),

        // [변경] Stream → BRAM에서 읽어온 데이터로 교체
        .pixel_in    (bram_rdata[7:0]),       // BRAM 읽기 데이터 직결
        .pixel_valid (pixel_valid_reg),  // BRAM 레이턴시 보정된 valid

        .final_digit (final_digit),
        .final_valid (final_valid),
        .done_tick   (done_tick)
    );

    // --------------------------------------------------
    // [Part 4] AXI-Stream 출력 (기존과 동일)
    // --------------------------------------------------
    assign m_axis_tdata  = {28'd0, final_digit};
    assign m_axis_tvalid = final_valid;
    assign m_axis_tlast  = final_valid;

endmodule