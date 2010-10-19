$:.unshift "./lib"
require "isolate/now"

require "hoe"

Hoe.plugins.delete :rubyforge
Hoe.plugin :doofus, :git, :isolate

Hoe.spec "isolate" do
  developer "John Barnette", "code@jbarnette.com"
  developer "Ryan Davis",    "ryand-ruby@zenspider.com"

  require_ruby_version     ">= 1.8.6"
  require_rubygems_version ">= 1.3.6"

  self.extra_rdoc_files = Dir["*.rdoc"]
  self.history_file     = "CHANGELOG.rdoc"
  self.readme_file      = "README.rdoc"
  self.testlib          = :minitest
end
