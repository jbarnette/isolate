require "minitest/autorun"
require "rubygems/dependency_installer"
require "rubygems/requirement"
require "isolate"

class TestIsolate < MiniTest::Unit::TestCase
  def setup
    @isolate = Isolate.new "tmp/gems"
  end

  def teardown
    @isolate.disable
    Isolate.instance.disable if Isolate.instance
    FileUtils.rm_rf "tmp/gems"
  end

  def test_self_gems
    assert_nil Isolate.instance

    Isolate.gems "test/fixtures/with-hoe" do
      gem "hoe"
    end

    refute_nil Isolate.instance
    assert_equal "test/fixtures/with-hoe", Isolate.instance.path
    assert_equal "hoe", Isolate.instance.entries.first.name
  end

  def test_activate
    @isolate = Isolate.new "test/fixtures/with-hoe"

    assert_nil Gem.loaded_specs["hoe"]

    @isolate.gem "hoe"
    @isolate.activate

    refute_nil Gem.loaded_specs["hoe"]
  end

  def test_activate_environment
    @isolate = Isolate.new "test/fixtures/with-hoe"
    @isolate.gem "rubyforge"

    @isolate.environment "borg" do
      @isolate.gem "hoe"
    end

    @isolate.activate
    assert_nil Gem.loaded_specs["hoe"]
    refute_nil Gem.loaded_specs["rubyforge"]
  end

  def test_activate_environment_explicit
    @isolate = Isolate.new "test/fixtures/with-hoe"

    @isolate.gem "rubyforge"

    @isolate.environment "borg" do
      @isolate.gem "hoe"
    end

    @isolate.activate "borg"
    refute_nil Gem.loaded_specs["hoe"]
    refute_nil Gem.loaded_specs["rubyforge"]
  end

  def test_activate_install
    @isolate = Isolate.new "tmp/gems", :install => true

    @isolate.gem "foo"

    # rescuing because activate, well, actually tries to activate
    begin; @isolate.activate; rescue Gem::LoadError; end

    assert_equal ["foo", Gem::Requirement.default],
      Gem::DependencyInstaller.last_install
  end

  def test_activate_ret
    assert_equal @isolate, @isolate.activate
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
    assert !Gem.find_files("minitest/unit.rb").empty?,
      "There's a minitest/unit in the current env, since we're running it."

    @isolate.enable

    assert_equal @isolate.path, ENV["GEM_PATH"]
    assert_equal @isolate.path, ENV["GEM_HOME"]

    assert_equal [], Gem.find_files("minitest/unit.rb"),
      "Can't find minitest/unit now, 'cause we're activated!"

    assert Gem.loaded_specs.empty?
    assert_equal [@isolate.path], Gem.path
  end

  def test_enable_block
    path = Gem.path.dup
    refute_equal [@isolate.path], Gem.path

    @isolate.enable do
      assert_equal [@isolate.path], Gem.path
    end

    assert_equal path, Gem.path
  end

  def test_enable_ret
    assert_equal @isolate, @isolate.enable
  end

  def test_environment
    @isolate.gem "none"

    @isolate.environment "test", "ci" do
      @isolate.gem "test-ci"

      @isolate.environment "production" do
        @isolate.gem "test-ci-production"
      end
    end

    none, test_ci, test_ci_production = @isolate.entries

    assert_equal [], none.environments
    assert_equal %w(test ci), test_ci.environments
    assert_equal %w(test ci production), test_ci_production.environments
  end

  def test_gem
    g = @isolate.gem "foo"
    assert @isolate.entries.include?(g)

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
    assert_equal "foo/gems", i.path
  end

  def test_initialize_options
    refute @isolate.install?
    refute @isolate.verbose?

    i = Isolate.new "foo/gems", :install => true, :verbose => true
    assert i.install?
    assert i.verbose?
  end
end

# Gem::DependencyInstaller#install is brutally stubbed.

class Gem::DependencyInstaller
  @@last_install = nil
  def self.last_install; @@last_install end

  alias old_install install

  def install name, requirement
    @@last_install = [name, requirement]
  end
end
