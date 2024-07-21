SRCS      := src/test.sv src/cpu.sv

IVERILOG  := iverilog -g2012 -Wall
VERILATOR := verilator --quiet --timing -Wall -Wno-DECLFILENAME
YOSYS     := yosys
ELF2HEX   := objcopy -O verilog --verilog-data-width=4 --adjust-vma=-0x80000000

.PHONY: lint test clean stat timing

lint:
	$(VERILATOR) --lint-only $(SRCS)
	$(IVERILOG) $(SRCS)
	$(YOSYS) -q -p "read_verilog -sv src/cpu.sv; proc"

test: a.out obj_dir/Vtest
	for file in test/*; do \
		echo; echo "[$$file]"; \
		$(ELF2HEX) "$$file" src/mem.hex; \
		./a.out; \
		./obj_dir/Vtest +verilator+quiet; \
	done

clean:
	rm -rf a.out obj_dir/

stat:
	$(YOSYS) -p "read_verilog -sv src/cpu.sv; synth -lut 2; ltp -noff"

timing:
	$(YOSYS) -p "read_verilog -sv src/cpu.sv; synth_ice40 -nobram -nocarry; sta"

a.out: $(SRCS)
	$(IVERILOG) $(SRCS)

obj_dir/Vtest: $(SRCS)
	$(VERILATOR) --binary $(SRCS)
