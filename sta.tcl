set_num_threads 4
read_celllib -min /Users/sriramnimmala/sta-analysis/sta-automation/src/osu018_stdcells.lib
read_celllib -max /Users/sriramnimmala/sta-analysis/sta-automation/src/osu018_stdcells.lib
read_sdc constraints.sdc
read_spef openMSP430.spef
read_verilog openMSP430_mapped.final.v
dump_timer timing_results.rpt
