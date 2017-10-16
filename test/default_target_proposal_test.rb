#! /usr/bin/env rspec

require_relative "./test_helper"

require "services-manager/clients/default_target_proposal"

describe Yast::TargetProposal do
  subject { described_class }
  describe "#call with Description command" do
    it "returns hash" do
      expect(subject.new.call(["Description"])).to be_a(::Hash)
    end
  end
end
