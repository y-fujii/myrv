SRCS      := src/test.sv src/cpu.sv
IVERILOG  := iverilog -g2012 -Wall
VERILATOR := verilator --quiet --timing -Wall -Wno-DECLFILENAME

.PHONY: lint
lint:
	$(VERILATOR) --lint-only $(SRCS)
	$(IVERILOG) $(SRCS)
	#yosys -q -p "read_verilog -sv src/cpu.sv"

.PHONY: test
test: a.out obj_dir/Vtest
	for file in test/*.hex32; do \
		cp "$$file" src/mem.hex; \
		echo "v======= $$file =======v"; \
		echo; \
		./a.out; \
		echo; \
		./obj_dir/Vtest; \
		echo; \
	done

a.out: $(SRCS)
	$(IVERILOG) $(SRCS)

obj_dir/Vtest:
	$(VERILATOR) --binary $(SRCS)
