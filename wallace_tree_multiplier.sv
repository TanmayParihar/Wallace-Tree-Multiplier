// ===== BASIC GATES =====
module and_gate (input a, b, output out);
    assign out = a & b;
endmodule

module xor_gate (input a, b, output out);
    assign out = a ^ b;
endmodule

module or_gate (input a, b, output out);
    assign out = a | b;
endmodule

// ===== HALF ADDER =====
module half_adder (input a, b, output sum, carry);
    xor_gate xor1 (.a(a), .b(b), .out(sum));
    and_gate and1 (.a(a), .b(b), .out(carry));
endmodule

// ===== FULL ADDER =====
module full_adder (input a, b, cin, output sum, carry);
    wire s1, c1, c2;
    
    half_adder ha1 (.a(a), .b(b), .sum(s1), .carry(c1));
    half_adder ha2 (.a(s1), .b(cin), .sum(sum), .carry(c2));
    or_gate or1 (.a(c1), .b(c2), .out(carry));
endmodule

// ===== 4:2 COMPRESSOR =====
module compressor_4_2 (
    input in1, in2, in3, in4, cin,
    output sum, carry, cout
);
    wire s1, c1, s2, c2;
    
    full_adder fa1 (.a(in1), .b(in2), .cin(in3), .sum(s1), .carry(c1));
    full_adder fa2 (.a(s1), .b(in4), .cin(cin), .sum(sum), .carry(c2));
    half_adder ha (.a(c1), .b(c2), .sum(carry), .carry(cout));
endmodule

// ===== PARTIAL PRODUCT GENERATION =====
module partial_products #(parameter N = 8) (
    input [N-1:0] a, b,
    output [N-1:0] pp [0:N-1]
);
    generate
        genvar i, j;
        for (i = 0; i < N; i = i + 1) begin : PP_ROW
            for (j = 0; j < N; j = j + 1) begin : PP_COL
                and_gate and_inst (.a(a[j]), .b(b[i]), .out(pp[i][j]));
            end
        end
    endgenerate
endmodule

// ===== OPTIMIZED 2-STAGE WALLACE REDUCTION =====
module wallace_reduction #(parameter N = 8) (
    input [N-1:0] pp [0:N-1],
    output [2*N-1:0] sum_out,
    output [2*N-1:0] carry_out
);
    
    // Shifted partial product matrix
    wire [2*N-1:0] pp_matrix [0:N-1];
    
    generate
        genvar row, col;
        for (row = 0; row < N; row = row + 1) begin : CREATE_MATRIX
            for (col = 0; col < 2*N; col = col + 1) begin : INIT_MATRIX
                if (col >= row && col < (row + N)) begin
                    assign pp_matrix[row][col] = pp[row][col - row];
                end else begin
                    assign pp_matrix[row][col] = 1'b0;
                end
            end
        end
    endgenerate
    
    // ===== STAGE 1: Reduce 8 rows to 6 rows =====
    // Use two 4:2 compressors per column
    // Each compressor outputs: sum (stays), carry (shift +1), cout (shift +2)
    wire [2*N-1:0] s1_sum1, s1_sum2;           // Sums stay in same column
    wire [2*N-1:0] s1_carry1, s1_carry2;       // Carries shift left by 1
    wire [2*N-1:0] s1_cout1, s1_cout2;         // Couts shift left by 2
    
    generate
        for (col = 0; col < 2*N; col = col + 1) begin : STAGE1
            compressor_4_2 cmp1 (
                .in1(pp_matrix[0][col]),
                .in2(pp_matrix[1][col]),
                .in3(pp_matrix[2][col]),
                .in4(pp_matrix[3][col]),
                .cin(1'b0),
                .sum(s1_sum1[col]),
                .carry(s1_carry1[col]),
                .cout(s1_cout1[col])
            );
            
            compressor_4_2 cmp2 (
                .in1(pp_matrix[4][col]),
                .in2(pp_matrix[5][col]),
                .in3(pp_matrix[6][col]),
                .in4(pp_matrix[7][col]),
                .cin(1'b0),
                .sum(s1_sum2[col]),
                .carry(s1_carry2[col]),
                .cout(s1_cout2[col])
            );
        end
    endgenerate
    
    // Create 6 rows for Stage 2 by shifting carries appropriately
    // All carries are treated as independent bits - NO carry propagation chains!
    wire [2*N-1:0] stage2_row0, stage2_row1, stage2_row2, stage2_row3, stage2_row4, stage2_row5;
    
    assign stage2_row0 = s1_sum1;                           // Column i
    assign stage2_row1 = s1_sum2;                           // Column i
    assign stage2_row2 = {s1_carry1[2*N-2:0], 1'b0};       // Shifted left by 1
    assign stage2_row3 = {s1_carry2[2*N-2:0], 1'b0};       // Shifted left by 1
    assign stage2_row4 = {s1_cout1[2*N-3:0], 2'b0};        // Shifted left by 2
    assign stage2_row5 = {s1_cout2[2*N-3:0], 2'b0};        // Shifted left by 2
    
    // ===== STAGE 2: Reduce 6 rows to 2 rows =====
    // Use one 4:2 compressor + one half adder per column
    wire [2*N-1:0] s2_sum1;                    // Sum from 4:2 compressor
    wire [2*N-1:0] s2_carry1;                  // Carry from 4:2 (shift +1)
    wire [2*N-1:0] s2_cout1;                   // Cout from 4:2 (shift +2)
    
    wire [2*N-1:0] s2_sum2;                    // Sum from half adder
    wire [2*N-1:0] s2_carry2;                  // Carry from half adder (shift +1)
    
    generate
        for (col = 0; col < 2*N; col = col + 1) begin : STAGE2
            // 4:2 compressor on first 4 rows
            compressor_4_2 cmp (
                .in1(stage2_row0[col]),
                .in2(stage2_row1[col]),
                .in3(stage2_row2[col]),
                .in4(stage2_row3[col]),
                .cin(1'b0),
                .sum(s2_sum1[col]),
                .carry(s2_carry1[col]),
                .cout(s2_cout1[col])
            );
            
            // Half adder on last 2 rows
            half_adder ha (
                .a(stage2_row4[col]),
                .b(stage2_row5[col]),
                .sum(s2_sum2[col]),
                .carry(s2_carry2[col])
            );
        end
    endgenerate
    
    // ===== FINAL OUTPUT: Combine all outputs into 2 rows =====
    // We now have 5 independent bit arrays:
    // - s2_sum1 (column i)
    // - s2_sum2 (column i)
    // - s2_carry1 (shift +1)
    // - s2_carry2 (shift +1)
    // - s2_cout1 (shift +2)
    //
    // We need to reduce these 5 rows to 2 rows for the final adder
    // Use 3:2 compressors (full adders) to do this efficiently
    
    wire [2*N-1:0] final_sum_temp;
    wire [2*N-1:0] final_carry_temp1;
    wire [2*N-1:0] final_carry_temp2;
    
    generate
        for (col = 0; col < 2*N; col = col + 1) begin : FINAL_COMBINE
            wire carry1_shifted = (col > 0) ? s2_carry1[col-1] : 1'b0;
            wire carry2_shifted = (col > 0) ? s2_carry2[col-1] : 1'b0;
            wire cout1_shifted = (col > 1) ? s2_cout1[col-2] : 1'b0;
            
            // First 3:2 compressor: combine s2_sum1, s2_sum2, carry1_shifted
            wire sum_temp1, carry_temp1;
            full_adder fa1 (
                .a(s2_sum1[col]),
                .b(s2_sum2[col]),
                .cin(carry1_shifted),
                .sum(sum_temp1),
                .carry(carry_temp1)
            );
            
            // Second 3:2 compressor: combine sum_temp1, carry2_shifted, cout1_shifted
            full_adder fa2 (
                .a(sum_temp1),
                .b(carry2_shifted),
                .cin(cout1_shifted),
                .sum(final_sum_temp[col]),
                .carry(final_carry_temp1[col])
            );
            
            // Store the first carry for shifting
            assign final_carry_temp2[col] = carry_temp1;
        end
    endgenerate
    
    // Final output: sum stays in place, both carries shift left by 1
    assign sum_out = final_sum_temp;
    
    // Combine the two carry arrays by shifting and OR'ing
    // (OR is safe here because these are independent carry bits going to different positions)
    assign carry_out = {final_carry_temp1[2*N-2:0], 1'b0} | {final_carry_temp2[2*N-2:0], 1'b0};
    
endmodule

// ===== TOP LEVEL =====
module wallace_tree_multiplier #(parameter N = 8) (
    input [N-1:0] a, b,
    output [2*N-1:0] product
);
    wire [N-1:0] pp [0:N-1];
    wire [2*N-1:0] stage_sum, stage_carry;
    
    partial_products #(.N(N)) pp_gen (.a(a), .b(b), .pp(pp));
    wallace_reduction #(.N(N)) reduction (.pp(pp), .sum_out(stage_sum), .carry_out(stage_carry));
    
    mcla #(.N(2*N)) final_adder (
        .a(stage_sum),
        .b(stage_carry),
        .cin(1'b0),
        .sum(product),
        .cout()
    );
endmodule

module mcla #(parameter N = 16) (
    input [N-1:0] a, b,
    input cin,
    output [N-1:0] sum,
    output cout
);
    localparam K = 4; // Block size as per paper
    localparam NUM_BLOCKS = N / K;
    
    // Generate and Propagate signals
    wire [N-1:0] g, p;
    wire [N:0] carry;
    
    // Block-level signals
    wire [NUM_BLOCKS-1:0] block_g, block_p;
    wire [NUM_BLOCKS:0] block_carry;
    
    assign carry[0] = cin;
    assign block_carry[0] = cin;
    
    // ============================================================
    // Generate and Propagate for each bit
    // ============================================================
    genvar i;
    generate
        for (i = 0; i < N; i = i + 1) begin : GEN_PROP
            // Standard generate and propagate
            assign g[i] = a[i] & b[i];
            assign p[i] = a[i] ^ b[i];
        end
    endgenerate
    
    // ============================================================
    // First Level: 4-bit CLA blocks
    // ============================================================
    generate
        for (i = 0; i < NUM_BLOCKS; i = i + 1) begin : BLOCK_LEVEL
            wire [K-1:0] local_g, local_p;
            wire [K:0] local_carry;
            
            // Map signals
            assign local_g = g[i*K +: K];
            assign local_p = p[i*K +: K];
            assign local_carry[0] = block_carry[i];
            
            // Carry lookahead equations within 4-bit block
            // C₁ = G₀ + P₀·C₀
            assign local_carry[1] = local_g[0] | (local_p[0] & local_carry[0]);
            
            // C₂ = G₁ + P₁·G₀ + P₁·P₀·C₀
            assign local_carry[2] = local_g[1] | 
                                   (local_p[1] & local_g[0]) |
                                   (local_p[1] & local_p[0] & local_carry[0]);
            
            // C₃ = G₂ + P₂·G₁ + P₂·P₁·G₀ + P₂·P₁·P₀·C₀
            assign local_carry[3] = local_g[2] |
                                   (local_p[2] & local_g[1]) |
                                   (local_p[2] & local_p[1] & local_g[0]) |
                                   (local_p[2] & local_p[1] & local_p[0] & local_carry[0]);
            
            // C₄ = G₃ + P₃·G₂ + P₃·P₂·G₁ + P₃·P₂·P₁·G₀ + P₃·P₂·P₁·P₀·C₀
            assign local_carry[4] = local_g[3] |
                                   (local_p[3] & local_g[2]) |
                                   (local_p[3] & local_p[2] & local_g[1]) |
                                   (local_p[3] & local_p[2] & local_p[1] & local_g[0]) |
                                   (local_p[3] & local_p[2] & local_p[1] & local_p[0] & local_carry[0]);
            
            // Map local carries to global carry array
            assign carry[i*K+1] = local_carry[1];
            assign carry[i*K+2] = local_carry[2];
            assign carry[i*K+3] = local_carry[3];
            assign carry[i*K+4] = local_carry[4];
            
            // Block-level generate: G = G₃ + P₃·G₂ + P₃·P₂·G₁ + P₃·P₂·P₁·G₀
            assign block_g[i] = local_g[3] |
                               (local_p[3] & local_g[2]) |
                               (local_p[3] & local_p[2] & local_g[1]) |
                               (local_p[3] & local_p[2] & local_p[1] & local_g[0]);
            
            // Block-level propagate: P = P₃·P₂·P₁·P₀
            assign block_p[i] = local_p[3] & local_p[2] & local_p[1] & local_p[0];
        end
    endgenerate
    
    // ============================================================
    // Second Level: Inter-block carry generation
    // Uses block generate and propagate to compute carries in parallel
    // This is the key advantage over ripple carry between blocks
    // ============================================================
    generate
        if (NUM_BLOCKS > 1) begin : SECOND_LEVEL
            // C₄ = BG₀ + BP₀·C₀ (carry out of block 0)
            assign block_carry[1] = block_g[0] | (block_p[0] & cin);
            
            // C₈ = BG₁ + BP₁·BG₀ + BP₁·BP₀·C₀ (carry out of block 1)
            assign block_carry[2] = block_g[1] |
                                   (block_p[1] & block_g[0]) |
                                   (block_p[1] & block_p[0] & cin);
            
            // C₁₂ = BG₂ + BP₂·BG₁ + BP₂·BP₁·BG₀ + BP₂·BP₁·BP₀·C₀ (carry out of block 2)
            if (NUM_BLOCKS > 2) begin
                assign block_carry[3] = block_g[2] |
                                       (block_p[2] & block_g[1]) |
                                       (block_p[2] & block_p[1] & block_g[0]) |
                                       (block_p[2] & block_p[1] & block_p[0] & cin);
            end
            
            // C₁₆ = BG₃ + BP₃·BG₂ + BP₃·BP₂·BG₁ + BP₃·BP₂·BP₁·BG₀ + BP₃·BP₂·BP₁·BP₀·C₀ (carry out of block 3)
            if (NUM_BLOCKS > 3) begin
                assign block_carry[4] = block_g[3] |
                                       (block_p[3] & block_g[2]) |
                                       (block_p[3] & block_p[2] & block_g[1]) |
                                       (block_p[3] & block_p[2] & block_p[1] & block_g[0]) |
                                       (block_p[3] & block_p[2] & block_p[1] & block_p[0] & cin);
            end
        end
    endgenerate
    
    // ============================================================
    // Sum Generation: S = A ⊕ B ⊕ C
    // ============================================================
    generate
        for (i = 0; i < N; i = i + 1) begin : SUM_GEN
            assign sum[i] = a[i] ^ b[i] ^ carry[i];
        end
    endgenerate
    
    assign cout = carry[N];
    
endmodule
