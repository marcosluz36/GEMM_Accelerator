PROJECT_NAME := gemm_accelerator

VIVADO_SETTINGS := /tools/Xilinx/2025.1/Vivado/settings64.sh
VIVADO_BIN      := vivado

TCL_SCRIPT := scripts/create_project.tcl
PROJECT_FILE := build/$(PROJECT_NAME)/$(PROJECT_NAME).xpr

.PHONY: all project gui clean

all: project create_venv

create_venv: requirements.txt
	python3 -m venv .venv
	.venv/bin/pip install -r requirements.txt

project:
	bash -lc 'source $(VIVADO_SETTINGS) && \
	$(VIVADO_BIN) -mode batch -source $(TCL_SCRIPT)'

gui: project
	bash -lc 'source $(VIVADO_SETTINGS) && \
	$(VIVADO_BIN) $(PROJECT_FILE)'

clean:
	rm -rf build
	rm -rf .Xil
	rm -rf *.jou *.log *.str
	rm -rf $(PROJECT_NAME).cache
	rm -rf $(PROJECT_NAME).hw
	rm -rf $(PROJECT_NAME).ip_user_files
	rm -rf $(PROJECT_NAME).sim
	rm -rf $(PROJECT_NAME).runs
	rm -rf $(PROJECT_NAME).srcs
	rm -rf $(PROJECT_NAME).gen
	rm -rf $(VENV)