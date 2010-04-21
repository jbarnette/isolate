require "rubygems"
require "isolate"

class Hoe # :nodoc:

  # This module is a Hoe plugin. You can set its attributes in your
  # Rakefile's Hoe spec, like this:
  #
  #    Hoe.plugin :isolate
  #
  #    Hoe.spec "myproj" do
  #      self.isolate_dir = "tmp/isolated"
  #    end
  #
  # NOTE! The Isolate plugin is a little bit special: It messes with
  # the plugin ordering to make sure that it comes before everything
  # else.

  module Isolate

    # Where should Isolate, um, isolate? [default: <tt>"tmp/isolate"</tt>]

    attr_accessor :isolate_dir

    def initialize_isolate # :nodoc:
      # Tee hee! Move ourselves to the front to beat out :test.
      Hoe.plugins.unshift Hoe.plugins.delete(:isolate)
      self.isolate_dir ||= "tmp/isolate"
    end

    def define_isolate_tasks # HACK
      i = ::Isolate::Sandbox.new :path => isolate_dir

      (self.extra_deps + self.extra_dev_deps).each do |name, version|
        i.gem name, *Array(version)
      end

      i.activate
    end
  end
end
