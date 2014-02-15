module Yast
  module DeferredExecution
    attr_reader :actions
    attr_accessor :modified

    alias_method :modified?, :modified

    def initialize
      @modified = false
      @actions  = []
    end

    def defer &block
      raise "Mandatory block missing" unless block_given?

      actions << block
      self.modified = true
    end

    def reset
      actions.clear
      self.modified = false
      true
    end

    def execute_deferred
      return unless modified?
      blocks_called = actions.map do |block|
        block.call
        block
      end
    ensure
      actions -= blocks_called
      self.modified = false if actions.empty?
    end
  end
end
