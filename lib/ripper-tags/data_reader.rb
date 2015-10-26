require 'pp'
require 'ripper-tags/parser'

module RipperTags
  class FileFinder
    attr_reader :options

    def initialize(options)
      @options = options
    end

    def exclude_patterns
      @exclude ||= Array(options.exclude).map { |pattern|
        if pattern.index('*')
          Regexp.new(Regexp.escape(pattern).gsub('\\*', '[^/]+'))
        else
          pattern
        end
      }
    end

    def exclude_file?(file)
      base = File.basename(file)
      exclude_patterns.any? {|ex|
        case ex
        when Regexp then base =~ ex
        else base == ex
        end
      } || exclude_patterns.any? {|ex|
        case ex
        when Regexp then file =~ ex
        else file.include?(ex)
        end
      }
    end

    def include_file?(file)
      (options.all_files || file =~ /\.rb\z/) && !exclude_file?(file)
    end

    def resolve_file(file, &block)
      if File.directory?(file)
        if options.recursive
          Dir.entries(file).each do |name|
            unless '.' == name || '..' == name
              resolve_file(File.join(file, name), &block)
            end
          end
        end
      else
        yield file if include_file?(file)
      end
    end

    def each_file(&block)
      return to_enum(__method__) unless block_given?
      options.files.each do |file|
        resolve_file(file, &block)
      end
    end
  end

  class DataReader
    attr_reader :options
    attr_accessor :read_mode

    def initialize(options)
      @options = options
      @read_mode = defined?(::Encoding) ? 'r:utf-8' : 'r'
    end

    def file_finder
      FileFinder.new(options)
    end

    def read_file(filename)
      str = File.open(filename, read_mode) {|f| f.read }
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
      file_finder.each_file do |file|
        begin
          $stderr.puts "Parsing file #{file}" if options.verbose
          extractor = tag_extractor(file)
        rescue => err
          if options.force
            $stderr.puts "Error parsing `#{file}': #{err.message}"
          else
            raise err
          end
        else
          extractor.tags.each do |tag|
            yield tag
          end
        end
      end
    end

    def debug_dump(obj)
      pp(obj, $stderr)
    end

    def parse_file(contents, filename)
      sexp = Parser.new(contents, filename).parse
      debug_dump(sexp) if options.debug
      sexp
    end

    def tag_extractor(file)
      file_contents = read_file(file)
      debug_dump(Ripper.sexp(file_contents)) if options.verbose_debug
      sexp = parse_file(file_contents, file)
      Visitor.new(sexp, file, file_contents)
    end
  end
end
