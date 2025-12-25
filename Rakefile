require "rubygems"
require "hoe"

$:.unshift "lib"

ENV["GEM_PATH"] ||= ""
ENV["GEM_PATH"] += ":tmp/isolate"
Gem.paths = ENV

require "isolate/rake"

Hoe.plugin :isolate_binaries # minitest -> prism
Hoe.plugin :doofus, :git
Hoe.plugin :minitest, :history, :email # from hoe-seattlerb - :perforce

Hoe.spec "isolate" do
  developer "Ryan Davis",    "ryand-ruby@zenspider.com"
  developer "Eric Hodel",    "drbrain@segment7.net"
  developer "John Barnette", "code@jbarnette.com"

  require_ruby_version ">= 2.7"
  require_rubygems_version ">= 1.8.2"

  self.extra_rdoc_files = Dir["*.rdoc"]
  self.history_file     = "CHANGELOG.rdoc"
  self.readme_file      = "README.rdoc"

  license "MIT"

  # taken from hoe/seattlerb.rb to avoid loading perforce plugin
  # REFACTOR: hoe/seattlerb.rb should just load plugins
  base = "/data/www/docs.seattlerb.org"
  rdoc_locations << "docs-push.seattlerb.org:#{base}/#{remote_rdoc_dir}"

  dependency "hoe-seattlerb", "~> 1.2", :development
  dependency "minitest",      "~> 5.0", :development
  dependency "hoe-doofus",    "~> 1.0", :development
  dependency "hoe-git",       "~> 1.3", :development
  dependency "ZenTest",       "~> 4.5", :development
end

# allow for isolated dependencies
task :check_extra_deps => :isolate do
  # but still install non-isolated
  ENV.delete "GEM_HOME"
  Gem.paths = ENV
end
