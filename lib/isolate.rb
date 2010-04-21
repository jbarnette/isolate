require "fileutils"
require "isolate/entry"
require "isolate/sandbox"
require "rbconfig"
require "rubygems/uninstaller"

# Restricts +GEM_PATH+ and +GEM_HOME+ and provides a DSL for
# expressing your code's runtime Gem dependencies. See README.rdoc for
# rationale, limitations, and examples.

module Isolate

  # Duh.

  VERSION = "2.0.0.pre.0"

  # Disable Isolate. If a block is provided, isolation will be
  # disabled for the scope of the block.

  def self.disable &block
    sandbox.disable(&block)
  end

  def self.env
    ENV["ISOLATE_ENV"] || ENV["RAILS_ENV"] || ENV["RACK_ENV"] || "development"
  end

  @@sandbox = nil

  def self.sandbox
    @@sandbox
  end

  # Declare an isolated RubyGems environment, installed in +path+. Any
  # block given will be <tt>instance_eval</tt>ed, see Isolate#gem and
  # Isolate#environment for the sort of stuff you can do.

  def self.now! options = {}, &block
    @@sandbox = Isolate::Sandbox.new options, &block
    @@sandbox.activate
  end

  # Poke RubyGems, we've probably monkeyed with a bunch of paths and
  # suchlike. Clears paths, loaded specs, and source indexes.

  def self.refresh # :nodoc:
    Gem.loaded_specs.clear
    Gem.clear_paths
    Gem.source_index.refresh!
  end
end
