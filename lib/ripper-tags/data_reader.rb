require 'pp'
require 'ripper-tags/parser'

module RipperTags
  class DataReader

    attr_reader :options

    def initialize(options)
      @options = options
    end

    def find_files
      options.files.inject([]) do |files, file_or_directory|
        if options.recursive && File.directory?(file_or_directory)
          files << Dir["#{file_or_directory}/**/*"]
        else
          files << file_or_directory
        end
      end.flatten
    end

    def parse_file?(filename)
      options.all_files || filename.end_with?('.rb')
    end

    def read_file(filename)
      File.read(filename)
    end

    def each_tag
      find_files.each do |file|
        next unless parse_file?(file)
        begin
          $stderr.puts "Parsing file #{file}" if options.verbose
          file_contents = read_file(file)
          sexp = Parser.new(file_contents, file).parse
          visitor = Visitor.new(sexp, file, file_contents)
          if options.verbose_debug
            pp Ripper.sexp(file_contents)
          elsif options.debug
            pp sexp
          end
        rescue => e
          $stderr.puts "Error parsing #{file}"
          raise e unless options.force
        else
          visitor.tags.each do |tag|
            yield tag
          end
        end
      end
      nil
    end
  end
end
