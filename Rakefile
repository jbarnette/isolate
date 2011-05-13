require "rubygems"
require "hoe"

$:.unshift "lib"
require "isolate/rake"

Hoe.plugins.delete :rubyforge
Hoe.plugin :isolate, :doofus, :git

Hoe.spec "isolate" do
  developer "John Barnette", "code@jbarnette.com"
  developer "Ryan Davis",    "ryand-ruby@zenspider.com"

  require_rubygems_version ">= 1.8.2"

  self.extra_rdoc_files = Dir["*.rdoc"]
  self.history_file     = "CHANGELOG.rdoc"
  self.readme_file      = "README.rdoc"
  self.testlib          = :minitest

  dependency "minitest",   "~> 2.1.0", :development
  dependency "hoe-doofus", "~> 1.0.0", :development
  dependency "hoe-git",    "~> 1.3.0", :development
end

def changelog_section code
  name = {
    :major   => "major enhancement",
    :minor   => "minor enhancement",
    :bug     => "bug fix",
    :unknown => "unknown",
  }[code]

  changes = $changes[code]
  count = changes.size
  name += "s" if count > 1
  name.sub!(/fixs/, 'fixes')

  return if count < 1

  puts "* #{count} #{name}:"
  puts
  changes.sort.each do |line|
    puts "  * #{line}"
  end
  puts
end

desc "Print the current changelog."
task "git:newchangelog" do
  # This must be in here until rubygems depends on the version of hoe that has
  # git_tags
  # TODO: get this code back into hoe-git
  module Hoe::Git
    module_function :git_tags, :git_svn?, :git_release_tag_prefix
  end

  tag   = ENV["FROM"] || Hoe::Git.git_tags.last
  range = [tag, "HEAD"].compact.join ".."
  cmd   = "git log #{range} '--format=tformat:%B|||%aN|||%aE|||'"
  now   = Time.new.strftime "%Y-%m-%d"

  changes = `#{cmd}`.split(/\|\|\|/).each_slice(3).map do |msg, author, email|
    msg.split(/\n/).reject { |s| s.empty? }
  end

  changes = changes.flatten

  next if changes.empty?

  $changes = Hash.new { |h,k| h[k] = [] }

  codes = {
    "!" => :major,
    "+" => :minor,
    "*" => :minor,
    "-" => :bug,
    "?" => :unknown,
  }

  codes_re = Regexp.escape codes.keys.join

  changes.each do |change|
    if change =~ /^\s*([#{codes_re}])\s*(.*)/ then
      code, line = codes[$1], $2
    else
      code, line = codes["?"], change.chomp
    end

    $changes[code] << line
  end

  puts "=== #{ENV['VERSION'] || 'NEXT'} / #{now}"
  puts
  changelog_section :major
  changelog_section :minor
  changelog_section :bug
  changelog_section :unknown
  puts
end
