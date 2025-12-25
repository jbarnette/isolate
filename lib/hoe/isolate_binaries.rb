Hoe.plugin :isolate

class Hoe
  module IsolateBinaries
    def define_isolate_binaries_tasks
      # do nothing
    end

    def initialize_isolate_binaries
      self.isolate_multiruby = true
    end
  end
end
