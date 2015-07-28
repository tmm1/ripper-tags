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
        ensure
          flush_file_section(io)
        end
      end
    end

    def write(tag, io)
      filename = relative_path(tag)
      section_io = start_file_section(filename, io)
      section_io.puts format(tag)
      if include_qualified_names? && tag[:full_name] != tag[:name] && constant?(tag)
        section_io.puts format(tag, :full_name)
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
  end
end
