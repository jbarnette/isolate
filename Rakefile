require "rubygems"
require "hoe"

$:.unshift "lib"
require "isolate/rake"

Hoe.plugins.delete :rubyforge
Hoe.plugin :isolate, :doofus, :git

Hoe.spec "isolate" do
  developer "John Barnette", "code@jbarnette.com"
  developer "Ryan Davis",    "ryand-ruby@zenspider.com"

  require_ruby_version     ">= 1.8.6"
  require_rubygems_version ">= 1.3.6"

  self.extra_rdoc_files = Dir["*.rdoc"]
  self.history_file     = "CHANGELOG.rdoc"
  self.readme_file      = "README.rdoc"
  self.testlib          = :minitest

  dependency "minitest",   "~> 2.1.0", :development
  dependency "hoe-doofus", "~> 1.0.0", :development
  dependency "hoe-git",    "~> 1.3.0", :development
end
