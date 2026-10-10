# CDC FIFO tests
#   make              build and run with Verilator
#   make DEPTH=4      try another FIFO depth
#   make questa       run with Questa (on asicfab)
#   make clean

DEPTH ?= 16

RTL = rtl/socetlib_bin2gray.sv rtl/socetlib_cdc_fifo_mem.sv rtl/socetlib_cdc_fifo.sv
TB  = tb/tb_cdc_fifo.sv

.PHONY: sim questa clean

sim:
	verilator --binary --timing -Wno-fatal -Wno-WIDTHTRUNC -Wno-WIDTHEXPAND \
	  --top-module tb_cdc_fifo -GDEPTH=$(DEPTH) --Mdir build -o sim $(RTL) $(TB)
	./build/sim

questa:
	vlib work
	vlog -sv $(RTL) $(TB)
	vsim -c tb_cdc_fifo -GDEPTH=$(DEPTH) -do "run -all; quit -f"

clean:
	rm -rf build work transcript
