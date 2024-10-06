RTLS      := rtl/cpu.sv rtl/ram.sv rtl/test.sv
TEST_DIR  := ../riscv-tests

IVERILOG  := iverilog -g2012 -Wall
VERILATOR := verilator --quiet --timing -Wall -Wno-DECLFILENAME
YOSYS     := yosys
ELF2HEX   := objcopy -O verilog --verilog-data-width=4 --adjust-vma=-0x80000000

.PHONY: lint test clean ltp sta

lint:
	$(VERILATOR) --lint-only $(RTLS)
	$(IVERILOG) -o /dev/null $(RTLS)
	$(YOSYS) -q -p "read_verilog -sv rtl/cpu.sv; prep"

test: build/test_iverilog build/test_verilator/Vtest
	for file in $$(find $(TEST_DIR)/isa/ -name "rv32ui-p-*" -executable); do \
		printf "\n[%s]\n" "$$(basename $$file)"; \
		$(ELF2HEX) "$$file" build/mem.hex; \
		build/test_iverilog; \
		build/test_verilator/Vtest +verilator+quiet; \
	done

clean:
	rm -rf build/

ltp:
	$(YOSYS) -p "read_verilog -sv rtl/cpu.sv; synth -lut 2; ltp -noff"

sta:
	$(YOSYS) -p "read_verilog -sv rtl/cpu.sv; synth_ice40 -nobram -nocarry; sta"

build/test_iverilog: $(RTLS)
	mkdir -p build/
	$(IVERILOG) -o build/test_iverilog $(RTLS)

build/test_verilator/Vtest: $(RTLS)
	mkdir -p build/
	$(VERILATOR) --binary --Mdir build/test_verilator $(RTLS)
