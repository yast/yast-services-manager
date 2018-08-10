#! /usr/bin/env rspec

require_relative "./test_helper"

require "services-manager/clients/services-manager_finish.rb"

describe ::ServicesManager::Clients::ServicesManagerFinish do
  subject(:client) { described_class.new }

  describe "#title" do
    it "returns string with title" do
      expect(subject.title).to be_a ::String
    end
  end

  describe "#write" do
    let(:success) { true }
    let(:errors) { [] }

    before do
      allow(Yast::ServicesManager).to receive(:save).and_return(success)
      allow(Yast::ServicesManager).to receive(:errors).and_return(errors)
    end

    it "returns true" do
      expect(client.write).to eq(true)
    end

    context "when some error ocurred" do
      let(:success) { false }
      let(:errors) { ["Error #1", "Error #2"] }

      before do
        allow(Yast::Report).to receive(:LongWarning)
      end

      it "displays a warning" do
        expect(Yast::Report).to receive(:LongWarning)
          .with("<ul><li>Error #1</li><li>Error #2</li></ul>")
        client.write
      end

      it "returns false" do
        expect(client.write).to eq(false)
      end
    end
  end
end
