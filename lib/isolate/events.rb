module Isolate
  module Events
    def self.watch klass, name, &block
      watchers[[klass, name]] << block
    end

    def self.fire klass, name, *args
      watchers[[klass, name]].each do |block|
        block[*args]
      end
    end

    def self.watchers
      @watchers ||= Hash.new { |h, k| h[k] = [] }
    end

    def fire name, after = nil, *args, &block
      Isolate::Events.fire self.class, name, *args

      if after && block_given?
        yield self
        Isolate::Events.fire self.class, after, *args
      end
    end
  end
end
