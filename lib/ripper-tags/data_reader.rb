class TagRipper
  class DataReader

    attr_reader :options
    attr_accessor :data

    def initialize(options)
      @options = options
    end

    def read_files
      options.files.inject([]) do |files, file_or_directory|
        if options.recursive && (File.directory?(file_or_directory))
          files << Dir["#{file_or_directory}/**/*"]
        else
          files << file_or_directory
        end
        files.flatten
      end
    end

    def parse_file?(file, data)
      data && ( options.all_files || file =~ /\.rb\z/ || data =~ /\A!#\S+\s*ruby/)
    rescue ArgumentError
      false #probably a binary file.
    end

    def read
      read_files.inject([]) do |tags, file|
        $stderr.puts "Reading file #{file}" if options.debug || options.verbose
        data = File.read(file) unless File.directory?(file)
        if x = parse_file?(file, data)
          $stderr.puts "Parsing file #{file}" if options.debug || options.verbose
          sexp = TagRipper.new(data, file).parse
          v = TagRipper::Visitor.new(sexp, file, data)
          if options.verbose
            pp Ripper.sexp(data)
          elsif options.debug
            pp sexp
          end
          tags << v.tags if v
        end
        tags
      end

    end
  end
end
