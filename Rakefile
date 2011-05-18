require "rubygems"
require "hoe"

$:.unshift "lib"
require "isolate/rake"

# TODO: build sandboxing into rubygems and make it a first class citizen in Hoe
Isolate.now! :system => false do
  env "development" do
    gem "hoe-seattlerb", "> 0"
    gem "minitest",   "~> 2.1"
    gem "hoe-doofus", "~> 1.0.0"
    gem "hoe-git",    "~> 1.3"
    gem "ZenTest",    "~> 4.5"
  end
end

Hoe.plugins.delete :rubyforge
Hoe.plugin :isolate, :doofus, :git, :minitest

Hoe.spec "isolate" do
  developer "John Barnette", "code@jbarnette.com"
  developer "Ryan Davis",    "ryand-ruby@zenspider.com"

  require_rubygems_version ">= 1.8.2"

  self.extra_rdoc_files = Dir["*.rdoc"]
  self.history_file     = "CHANGELOG.rdoc"
  self.readme_file      = "README.rdoc"
end
