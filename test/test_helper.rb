#! /usr/bin/env ruby

require 'minitest/autorun'
require 'minitest/spec'
require 'pathname'
require 'fileutils'

ENV["Y2DIR"] = File.expand_path("../../src", __FILE__)

require "yast"

Yast.import 'ServicesManager'

module TestHelpers
  module Files
    SOURCE = Pathname.new(File.expand_path( '../files', __FILE__))
    TMP    = Pathname.new(File.expand_path('../tmp', __FILE__))
  end

  module Manager
    attr_accessor :default_target, :services

    def stub_manager_with options
      self.default_target = options[:default_target]
      self.services = options[:services]

      Yast::SystemdTarget.stub :export, default_target do
        Yast::SystemdService.stub :export, services do
          yield
        end
      end
    end
  end

  module Targets
    include FileUtils
    include Files

    SUPPORTED_TEST_TARGETS = [
      'runlevel3',
      'multi-user'
    ]

    UNSUPPORTED_TEST_TARGETS = [
      'shutdown',
      'final'
    ]

    SAMPLE_CONTENT_FILES = {
      # LANG=C TERM=dumb COLUMNS=1024 systemctl --all --type target --no-legend --no-pager --no-ask-password
      :targets      => 'targets',
      # LANG=C TERM=dumb COLUMNS=1024 systemctl list-unit-files --type target --no-legend --no-pager --no-ask-password
      :target_units => 'target_units'
    }

    TARGETS_DIR      = TMP.join 'targets'
    TEST_TARGET_PATH = TARGETS_DIR.join 'etc/'
    TEST_TARGETS_DIR = TARGETS_DIR.join 'lib/'

    def stub_system_target
      setup_sample_files
      system_target.stub :list_target_units, read_test_target_units do
        system_target.stub :list_targets_details, read_test_targets_details do
          yield
        end
      end
    ensure
      sweep_sample_files
    end

    private

    def setup_sample_files
      mkpath TEST_TARGET_PATH
      mkpath TEST_TARGETS_DIR
      SUPPORTED_TEST_TARGETS.each do |target_file|
        cp SOURCE.join("#{target_file}.target"), TEST_TARGETS_DIR
      end
    end

    def read_test_targets_details
      {
        'exit'   => 0,
        'stderr' => '',
        'stdout' => File.read(SOURCE.join(SAMPLE_CONTENT_FILES[:targets]))
      }
    end

    def read_test_target_units
      {
        'exit'   => 0,
        'stderr' => '',
        'stdout' => File.read(SOURCE.join(SAMPLE_CONTENT_FILES[:target_units]))
      }
    end

    def sweep_sample_files
      rm_rf TARGETS_DIR
    end

  end
end
