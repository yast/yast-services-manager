#! /usr/bin/env ruby

# Test whether the systemd defined states have been changed.
# It it started regurarly from Travis jobs.
# The expected states are loaded from the expected_states.yml file.

# Rainbow is used by Rubocop, it is already present in the YaST Docker image
require "English"
require "rainbow"
require "shellwords"
require "tempfile"
require "yaml"

# run systemctl and get the help about the defined states
# @return [String]
def systemd_help
  help = `systemctl --state=help`
  raise "Cannot read systemd states help" unless $CHILD_STATUS.success?
  help
end

# parses the systemd status help text
# @param help [String] the input help text
# @return [Hash<String,Array<String>>]
def parse_status_help(help)
  states = {}

  # split the status groups
  help.split("\n\n").each do |group|
    lines = group.split("\n")
    header = lines.shift

    raise "Cannot parse header: #{header}" unless header =~ /Available (.*):/
    states[Regexp.last_match[1]] = lines.sort
  end

  states
end

# read the expected states from the file
# @param file [String] file name (YAML)
# @return [Hash<String,Array<String>>] the loaded content
def read_expected_states(file)
  YAML.load_file(file)
end

# print the difference
# @param name [String] systemd the group name (description)
# @param expected_states [Array<String>] the expected states
# @param current_states [Array<String>] the current states
def print_diff(name, expected_states, current_states)
  puts Rainbow("Found difference in the #{name.inspect} group:").red

  # the tempfiles are removed at exit automatically
  expected = Tempfile.new('expected')
  current = Tempfile.new('actual')

  # add new line at the end to avoid "no newline at the end of the file"
  # diff message
  File.write(expected.path, expected_states.join("\n") + "\n")
  File.write(current.path, current_states.join("\n") + "\n")
  
  system("diff --label 'Expected states' --label 'Current states' " \
    "-u #{Shellwords.escape(expected.path)} #{Shellwords.escape(current.path)}")
  
  puts
end

# compare the current and the expected states
# prints a diff if a difference is found
# @return [Boolean] true if the states are equal
def compare_states(expected, current)
  compared_groups = expected.map do |name, states|

    # sort the states to accept different order
    known_states = states.sort
    current_states = (current[name] || []).sort

    if known_states == current_states
      puts Rainbow("Found expected states in the #{name.inspect} group").green
    else
      print_diff(name, known_states, current_states)
    end

    known_states == current_states
  end

  compared_groups.all?
end

# get the current states
current = parse_status_help(systemd_help)
# read the expected states
expected = read_expected_states(File.expand_path("../expected_states.yml", __FILE__))

# compare them
equal = compare_states(expected, current)

if equal
  puts Rainbow("Check OK, no difference found").green
else
  puts Rainbow("Check failed!").red
  exit 1
end
