require "rubygems/command"
require "rubygems/dependency_installer"
require "rubygems/requirement"

class Isolate

  # An isolated Gem, with requirement, environment restrictions, and
  # installation options. Internal use only.

  class Entry

    # Which environments does this entry care about? Generally an
    # Array of Strings. An empty array means "all", not "none".

    attr_reader :environments

    # What's the name of this entry? Generally the name of a gem.

    attr_reader :name

    # Extra information or hints for installation. See +initialize+
    # for well-known keys.

    attr_reader :options

    # What version of this entry is required? Expressed as a
    # Gem::Requirement, which see.

    attr_reader :requirement

    # Create a new entry. Takes +sandbox+ (currently an instance of
    # Isolate), +name+ (as above), and any number of optional version
    # requirements (generally Strings). Options can be passed as a
    # trailing hash. FIX: document well-known keys.

    def initialize sandbox, name, *requirements
      @environments = nil
      @name         = name
      @options      = nil
      @requirement  = nil
      @sandbox      = sandbox

      update(*requirements)
    end

    # Install this entry in the sandbox.

    def install
      old = Gem.sources.dup

      begin
        installer = Gem::DependencyInstaller.new :development => false,
          :generate_rdoc => false, :generate_ri => false,
          :install_dir => @sandbox.path

        Gem.sources += Array(options[:source]) if options[:source]
        Gem::Command.build_args = Array(options[:args]) if options[:args]

        installer.install name, requirement
      ensure
        Gem.sources = old
        Gem::Command.build_args = nil
      end
    end

    # Is this entry interested in +environment+?

    def matches? environment
      environments.empty? || environments.include?(environment)
    end

    # Is this entry satisfied by +spec+ (generally a
    # Gem::Specification)?

    def matches_spec? spec
      name == spec.name and requirement.satisfied_by? spec.version
    end

    # Updates this entry's environments, options, and requirement. All
    # are additive. Returns the entry itself. FIX: rewrite, I was in a
    # very strange mood when I wrote this.

    def update *requirements
      @environments &&= @environments | @sandbox.environments
      @environments ||= @sandbox.environments

      options = Hash === requirements.last ? requirements.pop : {}

      @options.merge! options if @options
      @options ||= options

      @requirement &&= Gem::Requirement.new(@requirement.as_list | requirements)
      @requirement ||= Gem::Requirement.new requirements

      self
    end
  end
end
