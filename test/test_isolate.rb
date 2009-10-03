require "minitest/autorun"
require "rubygems/dependency_installer"
require "rubygems/requirement"
require "isolate"

class TestIsolate < MiniTest::Unit::TestCase
  WITH_HOE = "test/fixtures/with-hoe"

  def setup
    @isolate = Isolate.new "tmp/gems", :install => false, :verbose => false
  end

  def teardown
    @isolate.disable
    Isolate.instance.disable if Isolate.instance
    Gem::DependencyInstaller.reset_value
    Gem::Uninstaller.reset_value
    FileUtils.rm_rf "tmp/gems"
  end

  def test_self_gems
    assert_nil Isolate.instance

    Isolate.gems WITH_HOE do
      gem "hoe"
    end

    refute_nil Isolate.instance
    assert_equal File.expand_path(WITH_HOE), Isolate.instance.path
    assert_equal "hoe", Isolate.instance.entries.first.name
  end

  def test_activate
    @isolate = Isolate.new WITH_HOE

    assert_nil Gem.loaded_specs["hoe"]

    @isolate.gem "hoe"
    @isolate.activate

    refute_nil Gem.loaded_specs["hoe"]
  end

  def test_activate_environment
    @isolate = Isolate.new WITH_HOE
    @isolate.gem "rubyforge"

    @isolate.environment "borg" do
      gem "hoe"
    end

    @isolate.activate
    assert_nil Gem.loaded_specs["hoe"]
    refute_nil Gem.loaded_specs["rubyforge"]
  end

  def test_activate_environment_explicit
    @isolate = Isolate.new WITH_HOE

    @isolate.gem "rubyforge"

    @isolate.environment "borg" do
      gem "hoe"
    end

    @isolate.activate "borg"
    refute_nil Gem.loaded_specs["hoe"]
    refute_nil Gem.loaded_specs["rubyforge"]
  end

  def test_activate_install
    @isolate = Isolate.new "tmp/gems", :install => true, :verbose => false

    @isolate.gem "foo"

    # rescuing because activate, well, actually tries to activate
    begin; @isolate.activate; rescue Gem::LoadError; end

    assert_equal ["foo", Gem::Requirement.default],
      Gem::DependencyInstaller.value.shift
  end

  def test_activate_install_environment
    @isolate = Isolate.new "tmp/gems", :install => true
    @isolate.environment(:nope) { gem "foo" }

    @isolate.activate
    assert_empty Gem::DependencyInstaller.value
  end

  def test_activate_ret
    assert_equal @isolate, @isolate.activate
  end

  # TODO: cleanup with 2 versions of same gem, 1 activated
  # TODO: install with 1 older version, 1 new gem to be installed

  def test_cleanup
    @isolate = Isolate.new WITH_HOE, :verbose => false
    # no gems specified on purpose
    @isolate.activate
    @isolate.cleanup

    expected = [["hoe",       "2.3.3", WITH_HOE],
                ["rake",      "0.8.7", WITH_HOE],
                ["rubyforge", "1.0.4", WITH_HOE]]

    assert_equal expected, Gem::Uninstaller.value
  end

  def test_disable
    home, path = ENV.values_at "GEM_HOME", "GEM_PATH"
    load_path  = $LOAD_PATH.dup

    @isolate.enable

    refute_equal home, ENV["GEM_HOME"]
    refute_equal path, ENV["GEM_PATH"]
    refute_equal load_path, $LOAD_PATH

    @isolate.disable

    assert_equal home, ENV["GEM_HOME"]
    assert_equal path, ENV["GEM_PATH"]
    assert_equal load_path, $LOAD_PATH
  end

  def test_disable_ret
    assert_equal @isolate, @isolate.disable
  end

  def test_enable
    refute_empty Gem.find_files("minitest/unit.rb"),
      "There's a minitest/unit in the current env, since we're running it."

    @isolate.enable

    assert_equal @isolate.path, ENV["GEM_PATH"]
    assert_equal @isolate.path, ENV["GEM_HOME"]

    assert_equal [], Gem.find_files("minitest/unit.rb"),
      "Can't find minitest/unit now, 'cause we're activated!"

    assert_empty Gem.loaded_specs
    assert_equal [@isolate.path], Gem.path
  end

  def test_enable_ret
    assert_equal @isolate, @isolate.enable
  end

  def test_environment
    @isolate.gem "none"

    @isolate.environment "test", "ci" do
      gem "test-ci"

      environment "production" do
        gem "test-ci-production"
      end
    end

    none, test_ci, test_ci_production = @isolate.entries

    assert_equal [], none.environments
    assert_equal %w(test ci), test_ci.environments
    assert_equal %w(test ci production), test_ci_production.environments
  end

  def test_gem
    g = @isolate.gem "foo"
    assert_includes @isolate.entries, g

    assert_equal "foo", g.name
    assert_equal Gem::Requirement.create(">= 0"), g.requirement
  end

  def test_gem_multi_requirements
    g = @isolate.gem "foo", "= 1.0", "< 2.0"
    assert_equal Gem::Requirement.create(["= 1.0", "< 2.0"]), g.requirement
  end

  def test_gem_options
    g = @isolate.gem "foo", :source => "somewhere"
    assert_equal "somewhere", g.options[:source]
  end

  def test_initialize
    i = Isolate.new "foo/gems"
    assert_equal File.expand_path("foo/gems"), i.path
  end

  def test_initialize_options
    i = Isolate.new "foo/gems"
    assert i.install?
    assert i.verbose?
    assert i.cleanup?

    i = Isolate.new "foo/gems",
      :cleanup => false, :install => false, :verbose => false

    refute i.cleanup?
    refute i.install?
    refute i.verbose?

    i = Isolate.new "foo/gems", :install => false
    refute i.cleanup?, "no install, no cleanup"
  end

  def test_passthrough
    refute @isolate.passthrough?

    @isolate.passthrough { true }
    assert @isolate.passthrough?

    idx = Gem.source_index.dup
    @isolate.activate
    assert_equal idx, Gem.source_index


    @isolate.passthrough { false }
    refute @isolate.passthrough?
  end
end

module BrutalStub
  @@value = []
  def value; @@value end
  def reset_value; value.clear end
end

class Gem::DependencyInstaller
  extend BrutalStub

  alias old_install install
  def install name, requirement
    self.class.value << [name, requirement]
  end
end

class Gem::Uninstaller
  extend BrutalStub

  attr_reader :gem, :version, :gem_home
  alias old_uninstall uninstall
  def uninstall
    self.class.value << [self.gem,
                         self.version.to_s,
                         self.gem_home.sub(Dir.pwd + "/", '')]
  end
end
