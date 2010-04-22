require "rubygems/command"
require "rubygems/dependency_installer"
require "rubygems/requirement"

module Isolate

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
      @environments = []
      @name         = name
      @options      = {}
      @requirement  = Gem::Requirement.default
      @sandbox      = sandbox

      update(*requirements)
    end

    # Install this entry in the sandbox.

    def install
      dir = Dir.pwd
      old = Gem.sources.dup

      begin
        Dir.chdir File.join(@sandbox.path, "cache")

        installer = Gem::DependencyInstaller.new :development => false,
          :generate_rdoc => false, :generate_ri => false,
          :install_dir => @sandbox.path

        Gem.sources += Array(options[:source]) if options[:source]
        Gem::Command.build_args = Array(options[:args]) if options[:args]

        installer.install name, requirement
      ensure
        Dir.chdir dir
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

    # Updates this entry's environments, options, and
    # requirement. Environments and options are merged, requirement is
    # replaced.

    def update *reqs
      @environments |= @sandbox.environments
      @options.merge! reqs.pop if Hash === reqs.last
      @requirement = Gem::Requirement.new reqs unless reqs.empty?

      self
    end
  end
end
