#! /usr/bin/env ruby

require 'minitest/autorun'
require 'minitest/spec'
require 'pathname'
require 'fileutils'

ENV["Y2DIR"] = File.expand_path("../../src", __FILE__)

require "yast"

Yast.import 'ServicesManager'

module TestHelpers
  SCR_OUTPUT = {
    'exit'   => 0,
    'stderr' => '',
    'stdout' => ''
  }

  module Files
    SOURCE = Pathname.new(File.expand_path('../files', __FILE__))
    TMP    = Pathname.new(File.expand_path('../tmp', __FILE__))
  end

  module Services
    include FileUtils
    include Files

    SAMPLE_CONTENT_FILES = {
      # LANG=C TERM=dumb COLUMNS=1024 systemctl --all --type service \
      # --no-legend --no-pager --no-ask-password
      :services => 'services',
      # LANG=C TERM=dumb COLUMNS=1024 systemctl list-unit-files \
      # --type service --no-legend --no-pager --no-ask-password
      :service_units => 'service_units',
      # systemctl status foo_bar.service --no-legend --no-pager --no-ask-password
      :service_not_found => 'service_not_found'
    }

    def stub_systemd_service
      systemd_service.stub :list_services_units, read_services_units do
        systemd_service.stub :list_services_details, read_services_details do
          systemd_service.stub :status, read_status do
            yield
          end
        end
      end
    end

    def stub_switch
      Yast::Service.stub :Start, true do
        Yast::Service.stub :Stop, true do
          yield
        end
      end
    end

    def stub_toggle
      Yast::Service.stub :Enable, true do
        Yast::Service.stub :Disable, true do
          yield
        end
      end
    end

    def read_services_units
      SCR_OUTPUT.clone.update(
        'stdout'=>File.read(SOURCE.join(SAMPLE_CONTENT_FILES[:service_units]))
      )
    end

    def read_services_details
      SCR_OUTPUT.clone.update(
        'stdout'=>File.read(SOURCE.join(SAMPLE_CONTENT_FILES[:services]))
      )
    end

    def read_status
      SCR_OUTPUT.clone.update(
        'stdout'=>File.read(SOURCE.join(SAMPLE_CONTENT_FILES[:service_not_found]))
      )
    end

    def get_services_units(accept: :all)
      services = { :supported => [], :unsupported => [] }
      read_services_units['stdout'].each_line do |line|
        name, type = line.split /[\s]+/
        name.chomp! '.service'
        if Yast::SystemdServiceClass::Status::SUPPORTED_STATES.member?(type)
          services[:supported] << name
        else
          services[:unsupported] << name
        end
      end
      accept == :all ? services : services[accept]
    end

    def supported_services
      get_services_units :accept => :supported
    end

    def unsupported_services
      get_services_units :accept => :unsupported
    end

    def all_services
      get_services_units
    end
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
      :targets => 'targets',
      # LANG=C TERM=dumb COLUMNS=1024 systemctl list-unit-files --type target --no-legend --no-pager --no-ask-password
      :target_units => 'target_units'
    }

    TARGETS_DIR      = TMP.join 'targets'
    TEST_TARGET_PATH = TARGETS_DIR.join 'etc/'
    TEST_TARGETS_DIR = TARGETS_DIR.join 'lib/'

    def stub_systemd_target
      setup_sample_files
      systemd_target.stub :list_target_units, read_test_target_units do
        systemd_target.stub :list_targets_details, read_test_targets_details do
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
      SCR_OUTPUT.clone.update(
        'stdout' => File.read(SOURCE.join(SAMPLE_CONTENT_FILES[:targets]))
      )
    end

    def read_test_target_units
      SCR_OUTPUT.clone.update(
        'stdout' => File.read(SOURCE.join(SAMPLE_CONTENT_FILES[:target_units]))
      )
    end

    def sweep_sample_files
      rm_rf TARGETS_DIR
    end

  end
end
