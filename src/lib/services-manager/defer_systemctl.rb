module Yast
  module DeferSystemctl
    def initialize
      @modified = false
      @actions  = []
    end

    def modified?
      @modified
    end

    def defer action
      @actions << action
      @modified = true
    end

    def run_deferred
      actions_done = []
      @actions.each do |action|
        send(action)
        actions_done << action
      end
    ensure
      @actions -= actions_done
    end
  end
end
