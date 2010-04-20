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
      @sandbox      = sandbox
      @environments = sandbox.environments
      @name         = name
      @options      = Hash === requirements.last ? requirements.pop : {}
      @requirement  = Gem::Requirement.new requirements
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
  end
end
