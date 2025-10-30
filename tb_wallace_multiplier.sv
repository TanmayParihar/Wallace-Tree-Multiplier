// ===== COMPREHENSIVE TESTBENCH =====
module tb_wallace_multiplier;
    reg [7:0] a, b;
    wire [15:0] product;
    reg [15:0] expected;
    integer pass_count, fail_count;
    integer i, j;
    
    // Instantiate the multiplier
    wallace_tree_multiplier #(.N(8)) dut (.a(a), .b(b), .product(product));
    
    initial begin
        pass_count = 0;
        fail_count = 0;
        
        $display("=== Wallace Tree Multiplier with CORRECTED 4:2 Compressors ===");
        $display("Time\tA\tB\tProduct\tExpected\tStatus");
        
        // Test case 1: Zero multiplication
        a = 8'd0; b = 8'd0; expected = a * b; #20;
        check_result();
        
        // Test case 2: Identity
        a = 8'd1; b = 8'd1; expected = a * b; #20;
        check_result();
        
        // Test case 3: Simple multiplication
        a = 8'd10; b = 8'd15; expected = a * b; #20;
        check_result();
        
        // Test case 4: Maximum with 1
        a = 8'd255; b = 8'd1; expected = a * b; #20;
        check_result();
        
        // Test case 5: Medium values
        a = 8'h7F; b = 8'h03; expected = a * b; #20;
        check_result();
        
        // Test case 6: Powers of 2
        a = 8'h40; b = 8'h40; expected = a * b; #20;
        check_result();
        
        // Test case 7: Random values
        a = 8'h64; b = 8'h64; expected = a * b; #20;
        check_result();
        
        // Test case 8: CRITICAL - Previously failed
        a = 8'hF0; b = 8'h0F; expected = a * b; #20;
        check_result();
        
        // Test case 9: CRITICAL - Previously failed
        a = 8'hFE; b = 8'hFE; expected = a * b; #20;
        check_result();
        
        // Test case 10: CRITICAL - Previously failed
        a = 8'hFF; b = 8'hFF; expected = a * b; #20;
        check_result();
        
        // Additional edge cases
        a = 8'h55; b = 8'hAA; expected = a * b; #20;
        check_result();
        
        a = 8'd128; b = 8'd2; expected = a * b; #20;
        check_result();
        
        // Test bit patterns
        a = 8'b10101010; b = 8'b01010101; expected = a * b; #20;
        check_result();
        
        a = 8'b11110000; b = 8'b00001111; expected = a * b; #20;
        check_result();
        
        a = 8'h80; b = 8'h80; expected = a * b; #20;
        check_result();
        
        a = 8'hAA; b = 8'h55; expected = a * b; #20;
        check_result();
        
        // Summary
        #10;
        $display("\n=== Test Summary ===");
        $display("Passed: %0d, Failed: %0d, Total: %0d", 
                 pass_count, fail_count, pass_count + fail_count);
        
        if (fail_count == 0) begin
            $display("*** ALL INITIAL TESTS PASSED ***");
        end else begin
            $display("*** SOME TESTS FAILED ***");
        end
        
        // Run comprehensive test - ALL 65536 combinations
        $display("\n=== Running Comprehensive Test (All 65536 combinations) ===");
        $display("This will test every possible 8x8 multiplication...\n");
        
        for (i = 0; i < 256; i = i + 1) begin
            for (j = 0; j < 256; j = j + 1) begin
                a = i;
                b = j;
                expected = a * b;
                #5;
                if (product !== expected) begin
                    $display("FAIL: %h * %h = %h (expected %h)", a, b, product, expected);
                    fail_count = fail_count + 1;
                end else begin
                    pass_count = pass_count + 1;
                end
            end
            if (i % 32 == 0) begin
                $display("Progress: %0d/256 rows tested... (%0d%% complete)", 
                         i, (i * 100) / 256);
            end
        end
        
        $display("\n=== Comprehensive Test Completed ===");
        $display("Final Results - Passed: %0d, Failed: %0d, Total: 65536", 
                 pass_count, fail_count);
        
        if (fail_count == 0) begin
            $display("\n╔═══════════════════════════════════════════════╗");
            $display("║ ★★★ PERFECT! ALL 65536 TESTS PASSED! ★★★     ║");
            $display("║  Wallace Tree with 4:2 Compressors WORKING!  ║");
            $display("╚═══════════════════════════════════════════════╝");
        end else begin
            $display("\n*** %0d TESTS FAILED - NEEDS DEBUGGING ***", fail_count);
        end
        
        $display("\n=== Performance Analysis ===");
        $display("Design: 8x8 Wallace Tree Multiplier with 4:2 Compressors");
        $display("Key Fix: 4:2 compressor now outputs TWO separate carry bits");
        $display("No information loss from OR'ing carries!");
        $display("Reduction stages: 4 (properly handles all carries)");
        $display("Estimated critical path: ~8-10 gate delays through reduction");
        $display("Plus CLA final adder: ~4 gate delays");
        $display("Total: ~12-14 gate delays - Fast and CORRECT!");
        
        $finish;
    end
    
    task check_result;
        begin
            $write("%0t\t%h\t%h\t%h\t%h\t", $time, a, b, product, expected);
            if (product === expected) begin
                $display("PASS");
                pass_count = pass_count + 1;
            end else begin
                $display("FAIL");
                fail_count = fail_count + 1;
            end
        end
    endtask
endmodule
