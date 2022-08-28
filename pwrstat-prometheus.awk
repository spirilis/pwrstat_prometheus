#!/usr/bin/gawk -f

BEGIN {
  prometheus_prefix = "cyberpower_ups"

  # Help text for the different metrics
  prometheus_help["model_name"] = "Model name of CyberPower UPS"
  prometheus_type["model_name"] = "gauge"
  prometheus_help["firmware"] = "Firmware release running on the UPS"
  prometheus_type["firmware"] = "gauge"
  prometheus_help["rated_watts"] = "Rated power handling (in Watts)"
  prometheus_type["rated_watts"] = "gauge"
  prometheus_help["rated_voltamps"] = "Rated power handling (in Volt-Amps)"
  prometheus_type["rated_voltamps"] = "gauge"
  prometheus_help["state"] = "UPS current state of operation"
  prometheus_type["state"] = "gauge"
  prometheus_help["supply_source"] = "Description of current power supply source"
  prometheus_type["supply_source"] = "gauge"
  prometheus_help["utility_voltage"] = "Current AC voltage found at the utility plug (in Volts)"
  prometheus_type["utility_voltage"] = "gauge"
  prometheus_help["output_voltage"] "Current AC voltage output to the battery-backed loads (in Volts)"
  prometheus_type["output_voltage"] = "gauge"
  prometheus_help["battery_state_of_charge"] = "Present battery SoC (in %)"
  prometheus_type["battery_state_of_charge"] = "gauge"
  prometheus_help["battery_remaining_runtime"] = "Remaining battery runtime, estimated, units listed as runtime_units label"
  prometheus_type["battery_remaining_runtime"] = "gauge"
  prometheus_help["load"] = "Present load on the UPS (in Watts)"
  prometheus_type["load"] = "gauge"
  prometheus_help["line_interaction"] = "Line interaction information (unknown)"
  prometheus_type["line_interaction"] = "gauge"
  prometheus_help["last_power_event"] = "Last power event (label=last_event)"
  prometheus_type["last_power_event"] = "gauge"
  prometheus_help["pwrstat_version"] = "Version of the pwrstat utility for Linux used to retrieve this information"
  prometheus_type["pwrstat_version"] = "gauge"
}

function print_prometheus_help(metric) {
  printf "# HELP %s_%s %s\n", prometheus_prefix, metric, prometheus_help[metric]
  printf "# TYPE %s_%s %s\n", prometheus_prefix, metric, prometheus_type[metric]
}

/pwrstat version / {vers=1; pwrstat_version=$3}

/Properties:/ {prop=1; stat=0}
/Current UPS status:/ {prop=0; stat=1}

prop == 1 && /Model Name/ {model=$3}
prop == 1 && /Firmware Number/ {firmware=$3}
prop == 1 && /Rating Power/ {rated_power=$3; rated_va=substr($4,6)}

stat == 1 && /State/ {state=$2}
stat == 1 && /Power Supply by/ {supply=$4; for(i=5; i<=NF; i++) {supply = supply " " $i}}
stat == 1 && /Utility Voltage/ {voltage=$3}
stat == 1 && /Output Voltage/ {voltage_out=$3}
stat == 1 && /Battery Capacity/ {capacity_remaining=$3}
stat == 1 && /Remaining Runtime/ {runtime_remaining=$3; runtime_remaining_units=$4}
stat == 1 && /Load../ {load_watts = $2}
stat == 1 && /Line Interaction/ {line_interaction=$3; for (i=4; i<=NF; i++) {line_interaction = line_interaction " " $i}}
stat == 1 && /Last Power Event/ {last_pwr_event=$4; for (i=5; i<=NF; i++) {last_pwr_event = last_pwr_event " " $i}}

END {
  print_prometheus_help("model_name")
  printf "%s_model_name{model_name=\"%s\"} 1\n", prometheus_prefix, model

  print_prometheus_help("firmware")
  printf "%s_firmware{firmware=\"%s\"} 1\n", prometheus_prefix, firmware

  print_prometheus_help("rated_watts")
  printf "%s_rated_watts %f\n", prometheus_prefix, rated_power

  print_prometheus_help("rated_voltamps")
  printf "%s_rated_voltamps %f\n", prometheus_prefix, rated_va

  print_prometheus_help("state")
  if (state == "Normal") { state_val = 1 } else { state_val = 2 }
  printf "%s_state{state=\"%s\"} %f\n", prometheus_prefix, state, state_val

  print_prometheus_help("supply_source")
  if (supply == "Utility Power") { supply_val = 1 } else { supply_val = 2 }
  printf "%s_supply_source{source=\"%s\"} %f\n", prometheus_prefix, supply, supply_val

  print_prometheus_help("utility_voltage")
  printf "%s_utility_voltage %f\n", prometheus_prefix, voltage

  print_prometheus_help("output_voltage")
  printf "%s_output_voltage %f\n", prometheus_prefix, voltage_out

  print_prometheus_help("battery_state_of_charge")
  printf "%s_battery_state_of_charge %f\n", prometheus_prefix, capacity_remaining

  print_prometheus_help("battery_remaining_runtime")
  printf "%s_battery_remaining_runtime{runtime_units=\"%s\"} %f\n", prometheus_prefix, runtime_remaining_units, runtime_remaining

  print_prometheus_help("load")
  printf "%s_load %f\n", prometheus_prefix, load_watts

  print_prometheus_help("line_interaction")
  if (line_interaction == "None") { line_interaction_val = 1 } else { line_interaction_val = 2 }
  printf "%s_line_interaction{line_interaction=\"%s\"} %f\n", prometheus_prefix, line_interaction, line_interaction_val

  print_prometheus_help("last_power_event")
  printf "%s_last_power_event{last_event=\"%s\"} 1\n", prometheus_prefix, last_pwr_event

  if (vers == 1) {
    print_prometheus_help("pwrstat_version")
    printf "%s_pwrstat_version{pwrstat_version=\"%s\"} 1\n", prometheus_prefix, pwrstat_version
  }
}
