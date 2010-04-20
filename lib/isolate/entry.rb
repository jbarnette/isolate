class Isolate

  # An isolated Gem, with requirement, environment restrictions, and
  # installation options. Internal use only.

  class Entry < Struct.new :name, :requirement, :environments, :options
    def matches? environment # :nodoc:
      environments.empty? || environments.include?(environment)
    end

    def matches_spec? spec
      name == spec.name and requirement.satisfied_by? spec.version
    end
  end
end
