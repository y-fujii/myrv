.PHONY: lint
lint:
	verilator --quiet --lint-only --timing -Wall -Wno-DECLFILENAME src/*.sv
	iverilog -g2012 -Wall src/*.sv
	yosys -q -p "read_verilog -sv src/cpu.sv"
