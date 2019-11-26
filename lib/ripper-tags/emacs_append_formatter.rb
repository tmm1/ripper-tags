require 'set'

module RipperTags
  class EmacsAppendFormatter
    # Wraps an EmacsFormatter
    def initialize(fmt)
      raise 'append is only possible to a file' if fmt.stdout?
      @formatter = fmt
    end

    def with_output
      old_sections = parse_tag_file
      @seen_filenames = Set.new

      @formatter.with_output do |out|
        yield out
        @formatter.flush_file_section(out)

        old_sections.each do |filename, data|
          next if @seen_filenames.include?(filename)
          @formatter.write_section(filename, data, out)
        end
      end
    end

    def write(tag, out)
      @formatter.write(tag, out)
      @seen_filenames << @formatter.relative_path(tag)
    end

    def parse_tag_file
      section_map = {}
      File.open(@formatter.options.tag_file_name) do |old_file|
        while line = old_file.read(2)
          raise 'expected "\f\n", got %p' % line unless "\x0C\n" == line
          filename, length = old_file.gets.chomp.split(',')
          section_map[filename] = old_file.read(length.to_i)
        end
      end
      section_map
    end
  end
end
