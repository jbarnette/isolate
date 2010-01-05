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
      name == spec.name and requirement.satisfied_by? spec.version
    end
  end

  VERSION = "1.8.0" # :nodoc:

  attr_reader :entries # :nodoc:
  attr_reader :path # :nodoc:

  # Declare an isolated RubyGems environment, installed in +path+. The
  # block given will be <tt>instance_eval</tt>ed, see Isolate#gem and
  # Isolate#environment for the sort of stuff you can do.
  #
  # Option defaults:
  #
  #    { :cleanup => true, :install => true, :verbose => true }

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
  # API. You probably don't want to use this constructor directly.

  def initialize path, options = {}, &block
    @enabled      = false
    @entries      = []
    @environments = []
    @path         = File.expand_path path

    @install      = options.fetch :install, true
    @verbose      = options.fetch :verbose, true
    @cleanup      = @install && options.fetch(:cleanup, true)

    instance_eval(&block) if block_given?
  end

  # Activate this set of isolated entries, respecting an optional
  # +environment+. Points RubyGems to a separate repository, messes
  # with paths, auto-installs gems (if necessary), activates
  # everything, and removes any superfluous gem (again, if
  # necessary). If +environment+ isn't specified, +ISOLATE_ENV+,
  # +RAILS_ENV+, and +RACK_ENV+ are checked before falling back to
  # <tt>"development"</tt>.

  def activate environment = nil
    enable unless enabled?

    env = (environment        ||
           ENV["ISOLATE_ENV"] ||
           ENV["RAILS_ENV"]   ||
           ENV["RACK_ENV"]    ||
           "development").to_s

    install env if install?

    entries.each do |e|
      Gem.activate e.name, *e.requirement.as_list if e.matches? env
    end

    cleanup if cleanup?

    self
  end

  def cleanup # :nodoc:
    activated = Gem.loaded_specs.values.map { |s| s.full_name }
    extra     = Gem.source_index.gems.values.sort.reject { |spec|
      activated.include? spec.full_name or
        entries.any? { |e| e.matches_spec? spec }
    }

    return if extra.empty?

    padding = Math.log10(extra.size).to_i + 1
    format  = "[%0#{padding}d/%s] Nuking %s."

    extra.each_with_index do |e, i|
      log format % [i + 1, extra.size, e.full_name]

      Gem::DefaultUserInteraction.use_ui Gem::SilentUI.new do
        Gem::Uninstaller.new(e.name,
                             :version     => e.version,
                             :ignore      => true,
                             :executables => true,
                             :install_dir => path).uninstall
      end
    end
  end

  def cleanup? # :nodoc:
    @cleanup
  end

  def disable # :nodoc:
    return self if not enabled?

    ENV["GEM_PATH"] = @old_gem_path
    ENV["GEM_HOME"] = @old_gem_home
    ENV["PATH"]     = @old_path
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
    @old_path      = ENV["PATH"]
    @old_ruby_opt  = ENV["RUBYOPT"]
    @old_load_path = $LOAD_PATH.dup

    $LOAD_PATH.reject! do |p|
      p != File.dirname(__FILE__) &&
        Gem.path.any? { |gp| p.include?(gp) }
    end

    # HACK: Gotta keep isolate explicitly in the LOAD_PATH in
    # subshells, and the only way I can think of to do that is by
    # abusing RUBYOPT.

    ENV["RUBYOPT"]  = "#{ENV['RUBYOPT']} -I#{File.dirname(__FILE__)}"
    ENV["GEM_PATH"] = ENV["GEM_HOME"] = path

    bin = File.join path, "bin"
    ENV["PATH"] = [bin, ENV["PATH"]].join File::PATH_SEPARATOR

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
                    Gem::Requirement.new requirements
                  end

    entry = Entry.new name, requirement, @environments,  options

    entries << entry

    entry
  end

  def install environment # :nodoc:
    installable = entries.select do |e|
      !Gem.available?(e.name, *e.requirement.as_list) && e.matches?(environment)
    end

    return self if installable.empty?

    padding = Math.log10(installable.size).to_i + 1
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

      Gem::Command.build_args = Array(args) if args
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

  def log s # :nodoc:
    $stderr.puts s if verbose?
  end

  def verbose? # :nodoc:
    @verbose
  end
end
