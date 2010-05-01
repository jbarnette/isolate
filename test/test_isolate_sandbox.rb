require "isolate/test"

class TestIsolateSandbox < Isolate::Test
  WITH_HOE = "test/fixtures/with-hoe"

  def setup
    @sandbox = sandbox
    super
  end

  def test_activate
    @sandbox = sandbox :path => WITH_HOE

    refute_loaded_spec "hoe"
    @sandbox.gem "hoe"

    result = @sandbox.activate
    assert_equal @sandbox, result
    assert_loaded_spec "hoe"
  end

  def test_activate_environment_explicit
    @sandbox = sandbox :path => WITH_HOE

    @sandbox.gem "rubyforge"
    @sandbox.environment(:borg) { gem "hoe" }
    @sandbox.activate :borg

    assert_loaded_spec "hoe"
    assert_loaded_spec "rubyforge"
  end

  def test_activate_environment_implicit
    s = sandbox :path => WITH_HOE

    s.gem "rubyforge"
    s.environment(:borg) { gem "hoe" }

    s.activate
    refute_loaded_spec "hoe"
    assert_loaded_spec "rubyforge"
  end

  def test_activate_install
    s = sandbox :path => WITH_HOE, :install => true
    s.gem "foo"

    # rescuing because activate, well, actually tries to activate
    begin; s.activate; rescue Gem::LoadError; end

    assert_equal ["foo", Gem::Requirement.default],
      Gem::DependencyInstaller.value.shift
  end

  # TODO: cleanup with 2 versions of same gem, 1 activated
  # TODO: install with 1 older version, 1 new gem to be installed

  def test_cleanup
    s = sandbox :path => WITH_HOE, :install => true, :cleanup => true
    s.activate # no gems on purpose

    expected = [["hoe",       "2.3.3", WITH_HOE],
                ["rake",      "0.8.7", WITH_HOE],
                ["rubyforge", "1.0.4", WITH_HOE]]

    assert_equal expected, Gem::Uninstaller.value
  end

  def test_disable
    home, path, bin = ENV.values_at "GEM_HOME", "GEM_PATH", "PATH"
    load_path  = $LOAD_PATH.dup

    @sandbox.enable

    refute_equal home, ENV["GEM_HOME"]
    refute_equal path, ENV["GEM_PATH"]
    refute_equal bin,  ENV["PATH"]

    refute_equal load_path, $LOAD_PATH

    result = @sandbox.disable
    assert_same @sandbox, result

    assert_equal home, ENV["GEM_HOME"]
    assert_equal path, ENV["GEM_PATH"]
    assert_equal bin,  ENV["PATH"]
    assert_equal load_path, $LOAD_PATH
  end

  def test_enable
    refute_empty Gem.find_files("hoe.rb"),
      "There's a hoe.rb somewhere in the current env."

    assert_same @sandbox, @sandbox.enable

    assert_equal @sandbox.path, ENV["GEM_PATH"]
    assert_equal @sandbox.path, ENV["GEM_HOME"]
    assert ENV["PATH"].include?(File.join(@sandbox.path, "bin")), "in path"

    assert_equal [], Gem.find_files("hoe.rb"),
      "Can't find hoe.rb now, 'cause we're activated!"

    assert_empty Gem.loaded_specs
    assert_equal [@sandbox.path], Gem.path
  end

  def test_enable_idempotent_path_env
    bin  = File.join @sandbox.path, "bin"
    path = ENV["PATH"] = [bin, ENV["PATH"]].join(File::PATH_SEPARATOR)

    @sandbox.enable
    assert_equal path, ENV["PATH"]
  end

  def test_idempotent_rubyopt_env
    @sandbox.enable
    rubyopt = ENV["RUBYOPT"]
    @sandbox.disable

    refute_equal rubyopt, ENV["RUBYOPT"]

    ENV["RUBYOPT"] = rubyopt
    @sandbox.enable
    assert_equal rubyopt, ENV["RUBYOPT"]
  end

  def test_environment
    @sandbox.gem "none"

    @sandbox.environment "test", "ci" do
      gem "test-ci"

      environment "production" do
        gem "test-ci-production"
      end
    end

    none, test_ci, test_ci_production = @sandbox.entries

    assert_equal [], none.environments
    assert_equal %w(test ci), test_ci.environments
    assert_equal %w(test ci production), test_ci_production.environments
  end

  def test_gem
    g = @sandbox.gem "foo"
    assert_includes @sandbox.entries, g

    assert_equal "foo", g.name
    assert_equal Gem::Requirement.create(">= 0"), g.requirement
  end

  def test_gem_multi_calls
    g  = @sandbox.gem "foo"
    g2 = @sandbox.gem "foo", :foo => :bar

    @sandbox.gem "foo", :bar => :baz

    assert_same g, g2
    assert_equal :bar, g.options[:foo]
    assert_equal :baz, g.options[:bar]

    @sandbox.gem "foo", "> 1.7"
    assert_equal Gem::Requirement.new("> 1.7"), g.requirement

    @sandbox.environment :corge do
      gem "foo"
    end

    @sandbox.environment :plurgh do
      gem "foo"
    end

    assert_equal %w(corge plurgh), g.environments
  end

  def test_gem_multi_requirements
    g = @sandbox.gem "foo", "= 1.0", "< 2.0"
    assert_equal Gem::Requirement.create(["= 1.0", "< 2.0"]), g.requirement
  end

  def test_gem_options
    g = @sandbox.gem "foo", :source => "somewhere"
    assert_equal "somewhere", g.options[:source]
  end

  def test_initialize_defaults
    s = Isolate::Sandbox.new

    assert_equal [], s.entries
    assert_equal [], s.environments
    assert_match(/tmp\/isolate/, s.path)

    assert s.cleanup?
    assert s.install?
    assert s.system?
    assert s.verbose?
    assert s.multiruby?
  end

  def test_initialize_override_defaults
    s = Isolate::Sandbox.new :path => "x", :cleanup => false,
      :install => false, :system => false,
      :verbose => false, :multiruby => false

    assert_equal File.expand_path("x"), s.path

    refute s.cleanup?
    refute s.install?
    refute s.system?
    refute s.verbose?
    refute s.multiruby?
  end

  # First the specifically requested file, then the block (if given),
  # THEN the local override file (if it exists).

  def test_initialize_file_and_block
    s = sandbox :file => "test/fixtures/override.rb" do
      environment :foo do
        gem "monkey", "2.0", :args => "--panic"
      end
    end

    monkey = s.entries.first

    assert_equal %w(foo bar), monkey.environments
    assert_equal "--asplode", monkey.options[:args]
    assert_equal Gem::Requirement.new("2.0"), monkey.requirement
  end

  def test_options
    @sandbox.options :hello => :monkey
    assert_equal :monkey, @sandbox.options[:hello]
  end

  def test_path
    s = sandbox :multiruby => false do
      options :path => "tmp/foo"
    end

    assert_equal File.expand_path("tmp/foo"), s.path

    v = [Gem.ruby_engine, RbConfig::CONFIG["ruby_version"]].join "-"
    s = sandbox :multiruby => true
    p = File.expand_path("tmp/isolate/#{v}")

    assert_equal p, s.path

    s = sandbox :path => "tmp/isolate/#{v}", :multiruby => false
    assert_equal p, s.path
  end

  def assert_loaded_spec name
    assert Gem.loaded_specs[name],
      "#{name} is a loaded gemspec, and it shouldn't be!"
  end

  def refute_loaded_spec name
    refute Gem.loaded_specs[name],
      "#{name} is NOT a loaded gemspec, and it should be!"
  end

  def sandbox *args, &block
    opts = {
      :install   => false,
      :system    => false,
      :verbose   => false,
      :multiruby => false
    }

    opts.merge! args.pop if Hash === args.last
    Isolate::Sandbox.new opts, &block
  end
end
