require "simplecov"
require "simplecov-rcov"
require "fileutils"
require "test/unit"
require "mocha/setup"
require "yast"

$LOAD_PATH.unshift File.expand_path(File.join(File.dirname(__FILE__), '../src/modules'))

SimpleCov.formatter = SimpleCov::Formatter::RcovFormatter
SimpleCov.start

