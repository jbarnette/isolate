namespace :isolate do
  desc "Generate a .gems manifest for your isolated gems."
  task :dotgems do
    File.open ".gems", "wb" do |f|
      Isolate.instance.entries.each do |entry|
        next unless entry.environments.empty?

        gems  = [entry.name]
        gems << "--version '#{entry.requirement}'"
        gems << "--source #{entry.options[:source]}" if entry.options[:source]

        f.puts gems.join(" ")
      end

      # this above all: to thine own self be true
      f.puts "isolate --version '#{Isolate::VERSION}'"
    end
  end

  desc "Run an isolated command or subshell."
  task :sh, [:command] do |t, args|
    exec args.command || ENV["SHELL"]
  end
end
