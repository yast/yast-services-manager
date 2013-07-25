# encoding: utf-8

# Shortcut for calling services-manager
module Yast
  class Services < Client
    def main
      @target = "services-manager"
      WFM.CallFunction(@target, WFM.Args)
    end
  end
end

Yast::Services.new.main
