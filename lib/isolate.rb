require "fileutils"
require "isolate/entry"
require "isolate/sandbox"
require "rbconfig"
require "rubygems/uninstaller"

# Restricts +GEM_PATH+ and +GEM_HOME+ and provides a DSL for
# expressing your code's runtime Gem dependencies. See README.rdoc for
# rationale, limitations, and examples.

class Isolate
  VERSION = "2.0.0.pre.0" # :nodoc:

  attr_reader :entries # :nodoc:
  attr_reader :environments # :nodoc:

  # Disable Isolate. If a block is provided, isolation will be
  # disabled for the scope of the block.

  def self.disable &block
    instance.disable(&block)
  end

  def self.env # :nodoc:
    ENV["ISOLATE_ENV"] || ENV["RAILS_ENV"] || ENV["RACK_ENV"] || "development"
  end

  # Declare an isolated RubyGems environment, installed in +path+. Any
  # block given will be <tt>instance_eval</tt>ed, see Isolate#gem and
  # Isolate#environment for the sort of stuff you can do.
  #
  # If you'd like to specify gems and environments in a separate file,
  # you can pass an optional <tt>:file</tt> option.
  #
  # Option defaults:
  #
  #    {
  #      :cleanup => true,
  #      :install => true,
  #      :system  => false,
  #      :verbose => true
  #    }

  def self.gems path, options = {}, &block
    @@instance = Isolate::Sandbox.new options.merge(:path => path), &block
    @@instance.activate
  end

  @@instance = nil

  def self.instance # :nodoc:
    @@instance
  end

  def self.now! #:nodoc:
    gems "tmp/gems"
  end

  # Poke RubyGems, we've probably monkeyed with a bunch of paths and
  # suchlike. Clears paths, loaded specs, and source indexes.

  def self.refresh # :nodoc:
    Gem.loaded_specs.clear
    Gem.clear_paths
    Gem.source_index.refresh!
  end
end
