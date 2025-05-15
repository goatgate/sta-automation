# Makefile for VLSI Design Flow
JSON_FILE = "config.json"
MAPPED = _mapped
SYNTH_MAPPED = $(DESIGN_NAME)$(MAPPED)
SPEF_FILE = $(DESIGN_NAME).spef

# Directory variables
DESIGN_NAME = $(shell jq -r '."Design Name"' $(JSON_FILE))
OUTPUT_DIR = $(shell jq -r '."Output Directory"' $(JSON_FILE))
SOURCE_DIR = $(shell jq -r '."Source Directory"' $(JSON_FILE))
EARLY_LIB_PATH = $(shell jq -r '."Early Library Path"' $(JSON_FILE))
LATE_LIB_PATH = $(shell jq -r '."Late Library Path"' $(JSON_FILE))
CLOCK_CONSTRAINTS_FILE = $(shell jq -r '."Clock Constraints File"' $(JSON_FILE))
INPUT_CONSTRAINTS_FILE = $(shell jq -r '."Input Constraints File"' $(JSON_FILE))
OUTPUT_CONSTRAINTS_FILE = $(shell jq -r '."Output Constraints File"' $(JSON_FILE))
SDC_OUTPUT_FILE = $(OUTPUT_DIR)/$(DESIGN_NAME).sdc

# Generate SPEF
VENDOR_NAME = "TAU 2015 Contest"
PROGRAM_NAME = "Benchmark Parasitic Generator"
DESIGN_FLOW = "NETLIST_TYPE_VERILOG"
DATE = $(shell date)

# Units definitions
T_UNIT = 1 PS
C_UNIT = 1 FF
R_UNIT = 1 KOHM
L_UNIT = 1 UH

# Tool paths
YOSYS = yosys
OPENTIMER = ot-shell
PYTHON = python3
TCLSH = tclsh

# Main target
all: synthesis timing_analysis

# Check directory and file existence
check_setup:
	@echo "Checking setup and directory structure..."
	@test -f $(EARLY_LIB_PATH) || (echo "Error: Early library not found"; exit 1)
	@test -f $(LATE_LIB_PATH) || (echo "Error: Late library not found"; exit 1)
	@test -d $(SOURCE_DIR) || (echo "Error: Source directory not found"; exit 1)
	@test -f $(CLOCK_CONSTRAINTS_FILE) || (echo "Error: Clock constraints file not found"; exit 1)
	@test -f $(INPUT_CONSTRAINTS_FILE) || (echo "Error: Input constraints file not found"; exit 1)
	@test -f $(OUTPUT_CONSTRAINTS_FILE) || (echo "Error: Output constraints file not found"; exit 1)
	@mkdir -p $(OUTPUT_DIR)

# Generate SDC constraints
gen_sdc: check_setup
	@echo "Generating SDC constraints..."
	$(PYTHON) sdc_gen.py --clocks $(CLOCK_CONSTRAINTS_FILE) --inputs $(INPUT_CONSTRAINTS_FILE) --outputs $(OUTPUT_CONSTRAINTS_FILE) --output-sdc $(SDC_OUTPUT_FILE)
	@echo "SDC constraints generated: $(SDC_OUTPUT_FILE)"

# Check hierarchy
hierarchy_build:
	@echo "building $(DESIGN_NAME).hier.ys......."

check_hierarchy: check_setup
	@echo "Checking design hierarchy..."
	$(YOSYS) -s $(OUTPUT_DIR)/$(DESIGN_NAME).hier.ys \
		> $(OUTPUT_DIR)/$(DESIGN_NAME).hierarchy_check.log

# Synthesis
gen_synth: 
	touch synth.ys
	for file in $(wildcard $(SOURCE_DIR)/*.v); do \
		echo "read_verilog $$file" >> synth.ys; \
	done
	echo "hierarchy -top $(DESIGN_NAME)" >> synth.ys
	echo "synth -top $(DESIGN_NAME)" >> synth.ys
	echo "splitnets -ports -format ___" >> synth.ys
	echo "tribuf" >> synth.ys
	echo "techmap" >> synth.ys
	echo "proc; opt;" >> synth.ys
	echo "dfflibmap -prepare -liberty $(EARLY_LIB_PATH)" >> synth.ys
	echo "abc -liberty $(EARLY_LIB_PATH)" >> synth.ys
	echo "dfflibmap -liberty $(EARLY_LIB_PATH)" >> synth.ys
	echo "stat -liberty $(EARLY_LIB_PATH)" >> synth.ys
	echo "flatten" >> synth.ys
	echo "clean" >> synth.ys
	echo "tee -o report.txt stat -liberty $(EARLY_LIB_PATH)" >> synth.ys
	echo "write_verilog -noattr $(SYNTH_MAPPED).v" >> synth.ys

synth: gen_synth
	yosys synth.ys
# modifying synth
synth_mod:
	touch openMSP430_mapped.final.v
	echo "Info: Removing '*' from netlist. For user debug."
	echo "Info: Removing '\\' from netlist. For user debug."
	sed 's/\\//g' "openMSP430_mapped.v" > "openMSP430_mapped.final.v"
# Rule to generate the SPEF file
gen_spef:
	@echo "Generating SPEF file..."
	touch $(SPEF_FILE)
	echo "*SPEF \"IEEE 1481-1998\"" > $(SPEF_FILE)
	echo "*DESIGN \"$(DESIGN_NAME)\"" >> $(SPEF_FILE)
	echo "*DATE \"$(DATE)\"" >> $(SPEF_FILE)
	echo "*VENDOR \"$(VENDOR_NAME)\"" >> $(SPEF_FILE)
	echo "*PROGRAM \"$(PROGRAM_NAME)\"" >> $(SPEF_FILE)
	echo "*VERSION \"0.0\"" >> $(SPEF_FILE)
	echo "*DESIGN_FLOW \"$(DESIGN_FLOW)\"" >> $(SPEF_FILE)
	echo "*DIVIDER /" >> $(SPEF_FILE)
	echo "*DELIMITER :" >> $(SPEF_FILE)
	echo "*BUS_DELIMITER [ ]" >> $(SPEF_FILE)
	echo "*T_UNIT $(T_UNIT)" >> $(SPEF_FILE)
	echo "*C_UNIT $(C_UNIT)" >> $(SPEF_FILE)
	echo "*R_UNIT $(R_UNIT)" >> $(SPEF_FILE)
	echo "*L_UNIT $(L_UNIT)" >> $(SPEF_FILE)
	echo "SPEF file generated: $(SPEF_FILE)"

# Generate STA TCL script

gen_timing:
	touch sta.tcl
	echo "set_num_threads 4" > sta.tcl
	echo "read_celllib -min $(EARLY_LIB_PATH)" >> sta.tcl
	echo "read_celllib -max $(LATE_LIB_PATH)" >> sta.tcl
	echo "read_sdc constraints.sdc" >> sta.tcl
	echo "read_spef $(SPEF_FILE)" >> sta.tcl
	echo "read_verilog openMSP430_mapped.final.v" >> sta.tcl
	echo "report_timing $(DESIGN_NAME).timing" >> sta.tcl
	echo "report_timing" >> sta.tcl
	echo "dump_timer timing_results.rpt" >> sta.tcl
timing_analysis:gen_timing
	@echo "Running static timing analysis..."
	@echo "$($(OPENTIMER) < sta.tcl)"
	@echo "Timing analysis completed."
time:
	$(OPENTIMER)
# Clean generated files
clean:
	rm -rf $(OUTPUT_DIR)/*

# Help target
help:
	@echo "Available targets:"
	@echo "  all              - Run complete flow (synthesis and timing)"
	@echo "  check_setup      - Verify required files and directories"
	@echo "  gen_sdc          - Generate SDC constraints"
	@echo "  check_hierarchy  - Check design hierarchy"
	@echo "  synthesis        - Run synthesis flow"
	@echo "  gen_spef         - Generate SPEF file"
	@echo "  gen_sta          - Generate STA TCL script"
	@echo "  timing_analysis  - Run static timing analysis"
	@echo "  clean            - Remove generated files"
	@echo ""
	@echo "Required variables:"
	@echo "  DESIGN_NAME      - Name of the design"
	@echo "  OUTPUT_DIR       - Output directory path"
	@echo "  SOURCE_DIR       - Directory containing RTL netlists"
	@echo "  EARLY_LIB_PATH   - Path to early library"
	@echo "  LATE_LIB_PATH    - Path to late library"
	@echo "  CLOCK_CONSTRAINTS_FILE - Path to clock constraints JSON file"
	@echo "  INPUT_CONSTRAINTS_FILE - Path to input constraints JSON file"
	@echo "  OUTPUT_CONSTRAINTS_FILE - Path to output constraints JSON file"

.PHONY: all check_setup gen_sdc check_hierarchy synthesis gen_spef gen_sta timing_analysis clean help