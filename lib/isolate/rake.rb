namespace :isolate do
  desc "Show current isolated environment."
  task :debug do
    require "pathname"

    sandbox = Isolate.instance
    here    = Pathname Dir.pwd
    path    = Pathname(sandbox.path).relative_path_from here
    files   = sandbox.files.map { |f| Pathname(f) }

    puts
    puts "  sandbox: #{path}"
    puts "      env: #{Isolate.env}"

    files.collect! { |f| f.absolute? ? f.relative_path_from(here) : f }
    puts "    files: #{files.join ', '}"
    puts

    %w(cleanup? enabled? install? multiruby? system? verbose?).each do |flag|
      printf "%10s %s\n", flag, sandbox.send(flag)
    end

    grouped = Hash.new { |h, k| h[k] = [] }
    sandbox.entries.each { |e| grouped[e.environments] << e }

    puts

    grouped.keys.sort.each do |envs|
      title   = "all environments" if envs.empty?
      title ||= envs.join ", "

      puts "[#{title}]"

      grouped[envs].each do |e|
        gem = "gem #{e.name}, #{e.requirement}"
        gem << ", #{e.options.inspect}" unless e.options.empty?
        puts gem
      end

      puts
    end
  end

  desc "Run an isolated command or subshell."
  task :sh, [:command] do |t, args|
    exec args.command || ENV["SHELL"]
  end
end
