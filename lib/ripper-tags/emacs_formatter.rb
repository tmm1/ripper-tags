require 'ripper-tags/default_formatter'
require 'stringio'

module RipperTags
  # Generates etags format as described in
  # https://en.wikipedia.org/wiki/Ctags#Etags_2
  #
  # The format is non-trivial since it requires section header for each source
  # file to contain the size of tag data in bytes. This is accomplished by
  # buffering tag definitions per-file and flushing them to target IO when a
  # new source file is encountered or when `with_output` block finishes. This
  # assumes that incoming tags are ordered by source file.
  class EmacsFormatter < DefaultFormatter
    attr_reader :original

    def initialize(*)
      super
      @current_file = nil
      @section_io = nil
    end

    def supported_flags() ['q'] end

    def include_qualified_names?
      return @include_qualified_names if defined? @include_qualified_names
      @include_qualified_names = extra_flag?('q')
    end

    def with_output
      super do |io|
        begin
          yield io
          save_rest { |filename| start_file_section(filename, io) }
        ensure
          flush_file_section(io)
        end
      end
    end

    def prepare_output(filename, &block)
      @original = EmacsTagsProcessor.new(filename)
      @original.read if options.append && File.readable?(filename)

      super
    end

    def write(tag, io)
      filename = relative_path(tag)
      section_io = start_file_section(filename, io)
      # In case we have newer symbols for this file - trash old ones
      remove_saved(tag)
      record(section_io, tag)
    end

    def record(io, tag)
      io.puts format(tag)
      if include_qualified_names? && tag[:full_name] != tag[:name] && constant?(tag)
        io.puts format(tag, :full_name)
      end
    end

    def start_file_section(filename, io)
      if filename != @current_file
        flush_file_section(io)

        @current_file = filename
        @section_io = StringIO.new
      else
        @section_io
      end
    end

    def flush_file_section(out)
      if @section_io
        save_section(@current_file) { |tag| record(@section_io, tag) }

        data = @section_io.string
        out.write format_section_header(@current_file, data)
        out.write data
      end
    end

    def format_section_header(filename, data)
      data_size = data.respond_to?(:bytesize) ? data.bytesize : data.size
      "\x0C\n%s,%d\n" % [ filename, data_size ]
    end

    def format(tag, name_field = :name)
      "%s\x7F%s\x01%d,%d" % [
        tag.fetch(:pattern),
        tag.fetch(name_field),
        tag.fetch(:line),
        0,
      ]
    end

    def save_rest(&block)
      @original.save_rest(&block) if @original
    end

    def save_section(filename, &block)
      @original.save_section(filename, &block) if @original
    end

    def remove_saved(tag)
      @original.remove(tag) if @original
    end
  end

  class EmacsTagsProcessor
    def initialize(source)
      @source = source
      @tags = []
    end
    
    TAG_PATTERN = /^(.*)\x7F(.*)\x01(\d+),\d+/

    def read
      lines = File.readlines(@source, "\n")
      filename = nil
      while !lines.empty?
        line = lines.shift
        case line
        when "\f\n" # Section header
          filename, _ = lines.shift.split(",") # Filename is in next line
        else
          pattern, name, linenum = line.scan(TAG_PATTERN).first
          store_tag(linenum, name, pattern, filename)
        end
      end
    end

    def store_tag(line, name, pattern, filename)
      @tags.push({:line => line,
                  :name => name,
                  :path => filename,
                  :pattern => pattern,
                  :class => ""}) # Can't reconstruct class
    end

    def remove(tag)
      @tags.reject! do |old|
        old[:name] == tag[:name] && old[:path] == tag[:path]
      end
    end

    def save_section(path)
      @tags.select { |tag| tag[:path] == path }
           .each { |tag| yield tag }
      @tags.reject! { |tag| tag[:path] == path }
    end

    def save_rest
      @tags.group_by { |tag| tag[:path] }
        .each do |filename, tags|
          yield filename unless tags.count.zero?
        end
    end
  end
end
