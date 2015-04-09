module React
  class JavascriptContext
    attr_accessor :renderer

    def self.current
      unless Thread.current[self.name]
        Thread.current[self.name] = self.new
      end
      Thread.current[self.name]
    end

    def initialize
      @blocks = []
    end

    def self.reset!
      Thread.current[self.name] = nil
    end

    def push(block)
      @blocks << block
    end

    def pop_all
      @blocks.join("\n")
    end

  end
end