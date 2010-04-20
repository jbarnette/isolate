require "rubygems"
require "hoe"

Hoe.plugin :doofus, :git

Hoe.spec "isolate" do
  developer "John Barnette", "jbarnette@rubyforge.org"
  developer "Ryan Davis",    "ryand-ruby@zenspider.com"

  require_ruby_version     ">= 1.8.7"
  require_rubygems_version ">= 1.3.6"

  self.extra_rdoc_files = Dir["*.rdoc"]
  self.history_file     = "CHANGELOG.rdoc"
  self.readme_file      = "README.rdoc"
  self.testlib          = :minitest

  extra_dev_deps << ["minitest", "~> 1.4"]
end
