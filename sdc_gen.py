import json
import argparse
class SDCGenerator:
    def __init__(self, clock_file, input_file, output_file):
        self.clock_data = self._load_json(clock_file)
        self.input_data = self._load_json(input_file)
        self.output_data = self._load_json(output_file)
    def _load_json(self, file_path):
        try:
            with open(file_path, 'r') as f:
                data = json.load(f)
                return data
        except json.JSONDecodeError as e:
            raise ValueError(f"Error parsing JSON from {file_path}: {str(e)}")
        except Exception as e:
            raise ValueError(f"Error loading file {file_path}: {str(e)}")
    def generate_clock_constraints(self):
        sdc_lines = []
        sdc_lines.append("# Clock Definitions")
        clocks = self.clock_data.get('clocks', [])
        for clock in clocks:
            try:
                clock_name = clock.get('CLOCK')
                frequency = float(clock.get('frequency'))
                duty_cycle = float(clock.get('duty_cycle', 50))
                if not all([clock_name, frequency]):
                    continue
                period = 1000 / frequency
                clock_cmd = f"create_clock -name {clock_name} -period {period:.3f} -waveform {{0 {period * duty_cycle/100:.3f}}} [get_ports {clock_name}]"
                sdc_lines.append(clock_cmd)
                sdc_lines.append(f"set_clock_transition -rise -min {float(clock.get('early_rise_slew', 0.0)):.3f} [get_clocks {clock_name}]")
                sdc_lines.append(f"set_clock_transition -fall -min {float(clock.get('early_fall_slew', 0.0)):.3f} [get_clocks {clock_name}]")
                sdc_lines.append(f"set_clock_transition -rise -max {float(clock.get('late_rise_slew', 0.0)):.3f} [get_clocks {clock_name}]")
                sdc_lines.append(f"set_clock_transition -fall -max {float(clock.get('late_fall_slew', 0.0)):.3f} [get_clocks {clock_name}]")
            except Exception:
                continue
        return "\n".join(sdc_lines)
    def generate_input_constraints(self):
        sdc_lines = []
        sdc_lines.append("# Input Constraints")
        inputs = self.input_data.get('inputs', [])
        for input_port in inputs:
            try:
                port_name = input_port.get('pin')
                clock = input_port.get('clocks')
                if not all([port_name, clock]):
                    continue
                sdc_lines.append(f"set_input_delay -clock {clock} -min -rise {float(input_port.get('early_rise_delay', 0.0)):.3f} [get_ports {port_name}]")
                sdc_lines.append(f"set_input_delay -clock {clock} -min -fall {float(input_port.get('early_fall_delay', 0.0)):.3f} [get_ports {port_name}]")
                sdc_lines.append(f"set_input_delay -clock {clock} -max -rise {float(input_port.get('late_rise_delay', 0.0)):.3f} [get_ports {port_name}]")
                sdc_lines.append(f"set_input_delay -clock {clock} -max -fall {float(input_port.get('late_fall_delay', 0.0)):.3f} [get_ports {port_name}]")
                sdc_lines.append(f"set_input_transition -rise -min {float(input_port.get('early_rise_slew', 0.0)):.3f} [get_ports {port_name}]")
                sdc_lines.append(f"set_input_transition -fall -min {float(input_port.get('early_fall_slew', 0.0)):.3f} [get_ports {port_name}]")
                sdc_lines.append(f"set_input_transition -rise -max {float(input_port.get('late_rise_slew', 0.0)):.3f} [get_ports {port_name}]")
                sdc_lines.append(f"set_input_transition -fall -max {float(input_port.get('late_fall_slew', 0.0)):.3f} [get_ports {port_name}]")
            except Exception:
                continue
        return "\n".join(sdc_lines)
    def generate_output_constraints(self):
        sdc_lines = []
        sdc_lines.append("# Output Constraints")
        outputs = self.output_data.get('outputs', [])
        for output_port in outputs:
            try:
                port_name = output_port.get('pin')
                clock = output_port.get('clocks')
                if not all([port_name, clock]):
                    continue
                sdc_lines.append(f"set_output_delay -clock {clock} -min -rise {float(output_port.get('early_rise_delay', 0.0)):.3f} [get_ports {port_name}]")
                sdc_lines.append(f"set_output_delay -clock {clock} -min -fall {float(output_port.get('early_fall_delay', 0.0)):.3f} [get_ports {port_name}]")
                sdc_lines.append(f"set_output_delay -clock {clock} -max -rise {float(output_port.get('late_rise_delay', 0.0)):.3f} [get_ports {port_name}]")
                sdc_lines.append(f"set_output_delay -clock {clock} -max -fall {float(output_port.get('late_fall_delay', 0.0)):.3f} [get_ports {port_name}]")
                sdc_lines.append(f"set_load {float(output_port.get('load', 0.0)):.3f} [get_ports {port_name}]")
            except Exception:
                continue
        return "\n".join(sdc_lines)
    def generate_sdc(self, output_file):
        sdc_content = []
        sdc_content.append(self.generate_clock_constraints())
        sdc_content.append(self.generate_input_constraints())
        sdc_content.append(self.generate_output_constraints())
        with open(output_file, 'w') as f:
            f.write("\n".join(sdc_content))
def main():
    parser = argparse.ArgumentParser(description='Generate SDC constraints from JSON configuration files')
    parser.add_argument('--clocks', required=True, help='Path to clock configuration JSON file')
    parser.add_argument('--inputs', required=True, help='Path to input ports configuration JSON file')
    parser.add_argument('--outputs', required=True, help='Path to output ports configuration JSON file')
    parser.add_argument('--output-sdc', required=True, help='Path to output SDC file')
    args = parser.parse_args()
    generator = SDCGenerator(args.clocks, args.inputs, args.outputs)
    generator.generate_sdc(args.output_sdc)
if __name__ == '__main__':
    main()