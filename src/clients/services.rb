# encoding: utf-8

# Shortcut for calling services-manager
module Yast
  class Services < Client
    def main
      WFM.CallFunction("services-manager", WFM.Args)
    end
  end
end

Yast::Services.new.main
