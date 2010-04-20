require "isolate/entry"
require "minitest/autorun"
require "rubygems/version"

class TestIsolateEntry < MiniTest::Unit::TestCase
  def setup
    @sandbox = Object.new
    def @sandbox.environments; @e ||= [] end
  end

  def test_initialize
    @sandbox.environments.concat %w(foo bar)

    entry = e "baz", "> 1.0", "< 2.0", :quux => :corge

    assert_equal %w(foo bar), entry.environments
    assert_equal "baz", entry.name
    assert_equal Gem::Requirement.new("> 1.0", "< 2.0"), entry.requirement
    assert_equal :corge, entry.options[:quux]

    entry = e "plugh"

    assert_equal Gem::Requirement.default, entry.requirement
    assert_equal({}, entry.options)
  end

  def test_matches?
    @sandbox.environments << "test"
    entry = e "hi"

    assert entry.matches?("test")
    assert !entry.matches?("double secret production")

    @sandbox.environments.clear
    assert entry.matches?("double secret production")
  end

  def test_matches_spec?
    entry = e "hi", "1.1"

    assert entry.matches_spec?(spec "hi", "1.1")
    assert !entry.matches_spec?(spec "bye", "1.1")
    assert !entry.matches_spec?(spec "hi", "1.2")
  end

  def e *args
    Isolate::Entry.new @sandbox, *args
  end

  Spec = Struct.new :name, :version

  def spec name, version
    Spec.new name, Gem::Version.new(version)
  end
end
