#! /usr/bin/env ruby

require 'minitest/autorun'
require 'minitest/spec'
require 'pathname'
require 'fileutils'

ENV["Y2DIR"] = File.expand_path("../../src", __FILE__)

require "yast"

Yast.import 'ServicesManager'

module TestHelpers
  module Manager
    attr_accessor :default_target, :services

    def stub_with options
      self.default_target = options[:default_target]
      self.services = options[:services]

      Yast::SystemdTarget.stub :export, default_target do
        Yast::SystemdService.stub :export, services do
          yield
        end
      end
    end
  end
end
