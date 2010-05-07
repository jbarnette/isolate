require "isolate/sandbox"

# Restricts +GEM_PATH+ and +GEM_HOME+ and provides a DSL for
# expressing your code's runtime Gem dependencies. See README.rdoc for
# rationale, limitations, and examples.

module Isolate

  # Duh.

  VERSION = "2.0.0.pre.1"

  # Disable Isolate. If a block is provided, isolation will be
  # disabled for the scope of the block.

  def self.disable &block
    sandbox.disable(&block)
  end

  def self.env
    ENV["ISOLATE_ENV"] || ENV["RAILS_ENV"] || ENV["RACK_ENV"] || "development"
  end

  def self.gems path, options = {}, &block # :nodoc:
    warn "Isolate.gems is deprecated, use Isolate.now! instead.\n" +
         "Isolate.gems will be removed in v3.0."

    now! options.merge(:path => path), &block
  end

  def self.instance
    warn "Isolate.instance is deprecated, use Isolate.sandbox instead.\n" +
         "Isolate.instance will be removed in v3.0."

    sandbox
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
