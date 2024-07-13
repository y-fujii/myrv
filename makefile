SRCS      := src/test.sv src/cpu.sv
IVERILOG  := iverilog -g2012 -Wall
VERILATOR := verilator --quiet --timing -Wall -Wno-DECLFILENAME
YOSYS     := yosys -q

.PHONY: lint
lint:
	$(VERILATOR) --lint-only $(SRCS)
	$(IVERILOG) $(SRCS)
	$(YOSYS) -p "read_verilog -sv src/cpu.sv"

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

.PHONY: clean
clean:
	rm -f a.out
	rm -rf obj_dir

a.out: $(SRCS)
	$(IVERILOG) $(SRCS)

obj_dir/Vtest: $(SRCS)
	$(VERILATOR) --binary $(SRCS)
