namespace :isolate do
  desc "Generate a .gems manifest for your isolated gems."
  task :dotgems, [:env] do |_, args|
    env = args.env || Isolate.env

    File.open ".gems", "wb" do |f|
      Isolate.instance.entries.each do |entry|
        next unless entry.matches? env

        gems  = [entry.name]
        gems << "--version '#{entry.requirement}'"
        gems << "--source #{entry.options[:source]}" if entry.options[:source]

        f.puts gems.join(" ")
      end
    end
  end

  desc "Run an isolated command or subshell."
  task :sh, [:command] do |t, args|
    exec args.command || ENV["SHELL"]
  end
end
