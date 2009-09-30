require "rubygems/dependency_installer"
require "rubygems/uninstaller"
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

    def matches_spec? spec
      self.name == spec.name and self.requirement.satisfied_by? spec.version
    end
  end

  VERSION = "1.3.0" # :nodoc:

  attr_reader :entries # :nodoc:

  attr_reader :path # :nodoc:

  # Activate (and possibly install) gems for a specific
  # +environment+. This allows two-stage isolation, which is necessary
  # for stuff like Rails. See README.rdoc for a detailed example.

  def self.activate environment
    instance.activate environment
    instance.cleanup
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

  def cleanup
    activated = Gem.loaded_specs.values.map { |s| s.full_name }
    extra     = Gem.source_index.gems.values.sort.reject { |spec|
      activated.include? spec.full_name or
        entries.any? { |e| e.matches_spec? spec }
    }

    log "Cleaning..." unless extra.empty?

    padding = extra.size.to_s.size # omg... heaven forbid you use math
    format  = "[%0#{padding}d/%s] Nuking %s."
    extra.each_with_index do |e, i|
      log format % [i + 1, extra.size, e.full_name]

      Gem::DefaultUserInteraction.use_ui Gem::SilentUI.new do
        Gem::Uninstaller.new(e.name,
                             :version     => e.version,
                             :ignore      => true,
                             :executables => true,
                             :install_dir => self.path).uninstall
      end
    end
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
    old = @environments
    @environments = @environments.dup.concat environments.map { |e| e.to_s }

    instance_eval(&block)
  ensure
    @environments = old
  end

  # Express a gem dependency. Works pretty much like RubyGems' +gem+
  # method, but respects +environment+ and doesn't activate 'til
  # later.

  def gem name, *requirements
    options = Hash === requirements.last ? requirements.pop : {}

    requirement = if requirements.empty? then
                    Gem::Requirement.default
                  else
                    Gem::Requirement.new(requirements)
                  end

    entry = Entry.new name, requirement, @environments,  options

    entries << entry
    entry
  end

  def log s
    $stderr.puts s if verbose?
  end

  def install environment = nil # :nodoc:
    env = environment.to_s if environment

    installable = entries.select do |e|
      !Gem.available?(e.name, *e.requirement.as_list) && e.matches?(env)
    end

    log "Isolating #{environment}..." unless installable.empty?

    padding = installable.size.to_s.size # omg... heaven forbid you use math
    format  = "[%0#{padding}d/%s] Isolating %s (%s)."
    installable.each_with_index do |e, i|
      log format % [i + 1, installable.size, e.name, e.requirement]

      old         = Gem.sources.dup
      options     = e.options.merge(:install_dir   => path,
                                    :generate_rdoc => false,
                                    :generate_ri   => false)
      source      = options.delete :source
      args        = options.delete :args
      Gem.sources = Array(source) if source
      installer   = Gem::DependencyInstaller.new options

      Gem::Command.build_args = args if args
      installer.install e.name, e.requirement

      Gem.sources = old
      Gem::Command.build_args = nil if args
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
