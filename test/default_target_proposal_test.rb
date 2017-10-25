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

  describe "#call with MakeProposal command" do
    before do
      allow(Yast::ServicesManagerTarget).to receive(:read) # avoid real read
      allow(Yast::Stage).to receive(:initial).and_return(true) # skip state validation
    end

    context "auto mode" do
      before do
        allow(Yast::Mode).to receive(:autoinst).and_return(true)
      end

      it "keep default target as it was before" do
        Yast::ServicesManagerTarget.default_target = "multi-user"

        expect(Yast::ServicesManagerTarget).to_not receive(:default_target=)
        subject.new.call(["MakeProposal"])
      end
    end

    context "non-auto mode" do
      before do
        allow(Yast::Mode).to receive(:autoinst).and_return(false)
        allow(Yast::Mode).to receive(:autoupgrade).and_return(false)
      end

      it "sets target level according to control file" do
        allow(Yast::ProductFeatures).to receive(:GetStringFeature).with("globals", "default_target")
          .and_return("multi-user")

        subject.new.call(["MakeProposal"])

        expect(Yast::ServicesManagerTarget.default_target).to eq "multi-user"
      end

      it "proposes target when it is not specified in control file" do
        allow(Yast::ProductFeatures).to receive(:GetStringFeature).with("globals", "default_target")
          .and_return("")

        subject.new.call(["MakeProposal"])

        expect(Yast::ServicesManagerTarget.default_target).to_not be_empty
      end

      it "raises exception if control file contain invalid value" do
        allow(Yast::ProductFeatures).to receive(:GetStringFeature).with("globals", "default_target")
          .and_return("COBE invalid value")

        expect{subject.new.call(["MakeProposal"])}.to raise_error(RuntimeError)
      end
    end
  end
end
