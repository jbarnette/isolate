require "rubygems/dependency_installer"
require "rubygems/requirement"

# Restricts +GEM_PATH+ and +GEM_HOME+ and provides a DSL for
# expressing your code's runtime Gem dependencies. See README.rdoc for
# rationale, limitations, and examples.

class Isolate

  # An isolated Gem, with requirement, environment restrictions, and
  # installation options. Internal use only.

  class Entry < Struct.new(:name, :requirement, :environments, :options)
    def matches? environment # :nodoc:
      environments.empty? || environments.include?(environment)
    end
  end

  VERSION = "1.2.0" # :nodoc:

  attr_reader :entries # :nodoc:

  attr_reader :path # :nodoc:

  # Activate (and possibly install) gems for a specific
  # +environment+. This allows two-stage isolation, which is necessary
  # for stuff like Rails. See README.rdoc for a detailed example.

  def self.activate environment
    instance.activate environment
  end

  # Declare an isolated RubyGems environment, installed in +path+. The
  # block given will be <tt>instance_eval</tt>ed, see Isolate#gem and
  # Isolate#environment for the sort of stuff you can do.
  #
  # Option defaults:
  #
  #    { :install => true, :verbose => true }

  def self.gems path, options = {}, &block
    @@instance = new path, options, &block
    @@instance.activate
  end

  @@instance = nil

  def self.instance # :nodoc:
    @@instance
  end

  # Poke RubyGems, we've probably monkeyed with a bunch of paths and
  # suchlike. Clears paths, loaded specs, and source indexes.

  def self.refresh # :nodoc:
    Gem.loaded_specs.clear
    Gem.clear_paths
    Gem.source_index.refresh!
  end

  # Create a new Isolate instance. See Isolate.gems for the public
  # API. Don't use this constructor directly.

  def initialize path, options = {}, &block
    @enabled      = false
    @entries      = []
    @environments = []
    @install      = options.key?(:install) ? options[:install] : true
    @path         = path
    @verbose      = options.key?(:verbose) ? options[:verbose] : true

    instance_eval(&block) if block_given?
  end

  def activate environment = nil # :nodoc:
    enable unless enabled?

    env = environment.to_s if environment
    install environment if install?

    entries.each do |e|
      Gem.activate e.name, *e.requirement.as_list if e.matches? env
    end

    self
  end

  def disable # :nodoc:
    return self unless enabled?

    ENV["GEM_PATH"] = @old_gem_path
    ENV["GEM_HOME"] = @old_gem_home
    ENV["RUBYOPT"]  = @old_ruby_opt

    $LOAD_PATH.replace @old_load_path

    @enabled = false

    self.class.refresh
    self
  end

  def enable # :nodoc:
    return self if enabled?

    @old_gem_path  = ENV["GEM_PATH"]
    @old_gem_home  = ENV["GEM_HOME"]
    @old_ruby_opt  = ENV["RUBYOPT"]
    @old_load_path = $LOAD_PATH.dup

    $LOAD_PATH.reject! { |p| Gem.path.any? { |gp| p.include?(gp) } }

    # HACK: Gotta keep isolate explicitly in the LOAD_PATH in
    # subshells, and the only way I can think of to do that is by
    # abusing RUBYOPT.

    ENV["RUBYOPT"]  = "#{ENV['RUBYOPT']} -I#{File.dirname(__FILE__)}"
    ENV["GEM_PATH"] = ENV["GEM_HOME"] = path

    self.class.refresh

    @enabled = true
    self
  end

  def enabled? # :nodoc:
    @enabled
  end

  # Restricts +gem+ calls inside +block+ to a set of +environments+.

  def environment *environments, &block
    old = @environments.dup
    @environments.concat environments.map { |e| e.to_s }

    begin
      instance_eval(&block)
    ensure
      @environments = old
    end
  end

  # Express a gem dependency. Works pretty much like RubyGems' +gem+
  # method, but respects +environment+ and doesn't activate 'til
  # later.

  def gem name, *requirements
    options = Hash === requirements.last ? requirements.pop : {}

    requirement = requirements.empty? ?
      Gem::Requirement.default :
      Gem::Requirement.new(requirements)

    entry = Entry.new name, requirement, @environments.dup,  options

    entries << entry
    entry
  end

  def install environment = nil # :nodoc:
    env = environment.to_s if environment

    installable = entries.select do |e|
      !Gem.available?(e.name, *e.requirement.as_list) && e.matches?(env)
    end

    installable.each_with_index do |e, i|
      if verbose?
        padding  = installable.size.to_s.size
        progress = "[%0#{padding}d/%s]" % [i + 1, installable.size]
        warn "#{progress} Isolating #{e.name} (#{e.requirement})."
      end

      options     = e.options.dup.merge :install_dir => path
      old         = Gem.sources.dup
      source      = options.delete :source
      Gem.sources = Array(source) if source
      installer   = Gem::DependencyInstaller.new options

      installer.install e.name, e.requirement
      Gem.sources = old
    end

    Gem.source_index.refresh!
    self
  end

  def install? # :nodoc:
    @install
  end

  def verbose? # :nodoc:
    @verbose
  end
end
