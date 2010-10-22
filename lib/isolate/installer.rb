require "rubygems/dependency_installer"

module Isolate
  class Installer < Gem::DependencyInstaller
    def initialize sandbox
      super :development => false,
        :generate_rdoc   => false,
        :generate_ri     => false,
        :install_dir     => sandbox.path

      # reset super's use of sandbox.path exclusively
      @source_index = Gem.source_index
    end
  end
end
