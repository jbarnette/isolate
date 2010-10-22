require "isolate"
require "minitest/autorun"

module Isolate
  class Test < MiniTest::Unit::TestCase
    def setup
      Gem.refresh

      @env = ENV.to_hash
      @lp  = $LOAD_PATH.dup
      @lf  = $LOADED_FEATURES.dup
    end

    def teardown
      Gem::DependencyInstaller.reset_value
      Gem::Uninstaller.reset_value

      ENV.replace @env
      $LOAD_PATH.replace @lp
      $LOADED_FEATURES.replace @lf

      FileUtils.rm_rf "tmp/isolate"
    end
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
