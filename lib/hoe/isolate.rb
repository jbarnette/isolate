require "rubygems"
require "isolate"

module Hoe::Isolate
  attr_accessor :isolate_dir

  def initialize_isolate
    # Tee hee! Move ourselves to the front to beat out :test.
    Hoe.plugins.unshift Hoe.plugins.delete(:isolate)
    self.isolate_dir ||= "tmp/gems"
  end

  def define_isolate_tasks
    i = Isolate.new self.isolate_dir

    (self.extra_deps + self.extra_dev_deps).each do |name, version|
      i.gem name, *Array(version)
    end

    i.activate
  end
end
