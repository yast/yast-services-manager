#! /usr/bin/env rspec

require_relative "./test_helper"

require "services-manager/clients/services-manager_finish.rb"

describe ::ServicesManager::Clients::ServicesManagerFinish do
  describe "#title" do
    it "returns string with title" do
      expect(subject.title).to be_a ::String
    end
  end

  describe "#write" do
    it "writes installation services and default target" do
      expect(::Yast::ServicesManagerTarget).to receive(:save)
      expect(::Yast::ServicesManagerService).to receive(:save)

      subject.write
    end
  end
end
