class Lingen::Application
  def self.run!(*argv)
    if argv.empty?
      source_files = Dir.glob(File.expand_path("*.lingen"))
    else
      source_files = argv
    end

    if source_files.empty?
      puts "No input files"
      return 1
    end

    for source_file in source_files
      if source_file =~ /\.lingen$/
        output_file = source_file.sub(/\.lingen$/, '.output')
      else
        output_file = source_file + ".output"
      end
      begin
        rule = eval File.read(source_file), source_file
        if (rule[:seed])
          srand rule[:seed]
        else
          srand
        end

        lingen = Lingen::Module.new(rule)
        count = (rule[:iterations] or 5)
        count.times { l.populate() }

        output = (rule[:output] or (output_file))
        File.open(output, 'w') { |file| file.write(l.system) }

      rescue Exception => e
        # Keep the portion of stack trace that belongs to the .lingen file
        backtrace = e.backtrace.grep(Regexp.new(File.expand_path(source_file)))
        raise e.class, e.message, backtrace
      end
    end
    return 0
  end
end
