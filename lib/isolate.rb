require "isolate/sandbox"

# Restricts +GEM_PATH+ and +GEM_HOME+ and provides a DSL for
# expressing your code's runtime Gem dependencies. See README.rdoc for
# rationale, limitations, and examples.

module Isolate

  # Duh.

  VERSION = "2.1.2"

  # Disable Isolate. If a block is provided, isolation will be
  # disabled for the scope of the block.

  def self.disable &block
    sandbox.disable(&block)
  end

  # What environment should be isolated? Consults environment
  # variables <tt>ISOLATE_ENV</tt>, <tt>RAILS_ENV</tt>, and
  # <tt>RACK_ENV</tt>. Defaults to <tt>development"/tt> if none are
  # set.

  def self.env
    ENV["ISOLATE_ENV"] || ENV["RAILS_ENV"] || ENV["RACK_ENV"] || "development"
  end

  # Deprecated. See Isolate.now!

  def self.gems path, options = {}, &block # :nodoc:
    warn "Isolate.gems is deprecated, use Isolate.now! instead.\n" +
         "Isolate.gems will be removed in v3.0."
    compat = {
      :path => path,
      :multiruby => false,
      :system => false,
    }

    now! options.merge(compat), &block
  end

  # Deprecated. See Isolate.sandbox.

  def self.instance
    warn "Isolate.instance is deprecated, use Isolate.sandbox instead.\n" +
         "Isolate.instance will be removed in v3.0."

    sandbox
  end

  @@sandbox = nil

  # A singleton instance of Isolate::Sandbox.

  def self.sandbox
    @@sandbox
  end

  # Declare an isolated RubyGems environment, installed in +path+. Any
  # block given will be <tt>instance_eval</tt>ed, see
  # Isolate::Sandbox#gem and Isolate::Sandbox#environment for the sort
  # of stuff you can do.
  #
  # Valid options:
  #
  # :cleanup:: Should obsolete gems be removed? Default is +true+.
  #
  # :file:: Specify an Isolate file to +instance_eval+. Default is
  #         <tt>Isolate</tt> or <tt>config/isolate.rb</tt>, whichever
  #         is found first. Passing <tt>false</tt> disables file
  #         loading.
  #
  # :install:: Should missing gems be installed? Default is +true+.
  #
  # :multiruby:: Should Isolate assume that multiple Ruby versions
  #              will be used simultaneously? If so, gems will be
  #              segregated by Ruby version. Default is +true+.
  #
  # :path:: Where should isolated gems be kept? Default is
  #         <tt>tmp/isolate"</tt>, and a Ruby version specifier suffix
  #         will be added if <tt>:multiruby</tt> is +true+.
  #
  # :system:: Should system gems be allowed to satisfy dependencies?
  #           Default is +true+.
  #
  # :verbose:: Should Isolate be chatty during installs and nukes?
  #            Default is +true+.

  def self.now! options = {}, &block
    @@sandbox = Isolate::Sandbox.new options, &block
    @@sandbox.activate
  end

  # Poke RubyGems, since we've probably monkeyed with a bunch of paths
  # and suchlike. Clears paths, loaded specs, and source indexes.

  def self.refresh # :nodoc:
    Gem.loaded_specs.clear
    Gem.clear_paths
    Gem.source_index.refresh!
  end
end
