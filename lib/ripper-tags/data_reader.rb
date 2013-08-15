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
      str = File.open(filename, 'r:utf-8') {|f| f.read }
      normalize_encoding(str)
    end

    def normalize_encoding(str)
      if str.respond_to?(:encode!)
        # strip invalid byte sequences
        str.encode!('utf-16', :invalid => :replace, :undef => :replace)
        str.encode!('utf-8')
      else
        str
      end
    end

    def each_tag
      return to_enum(__method__) unless block_given?
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
        rescue => err
          if options.force
            $stderr.puts "Error parsing `#{file}': #{err.message}"
          else
            raise err
          end
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
