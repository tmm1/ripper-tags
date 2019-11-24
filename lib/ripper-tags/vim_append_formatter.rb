require 'set'

module RipperTags
  class VimAppendFormatter
    # Wraps a VimFormatter
    def initialize(fmt)
      raise 'append is only possible to a file' if fmt.stdout?
      @formatter = fmt
    end

    def with_output
      orig_lines = File.readlines(@formatter.options.tag_file_name)
      @seen_filenames = Set.new

      @formatter.with_output do |out|
        yield out

        orig_lines.each do |line|
          f1, f2, = line.split("\t", 3)
          # skip repeating header entries
          next if f1 == '!_TAG_FILE_FORMAT' || f1 == '!_TAG_FILE_SORTED'
          # skip old tags for newly processed files
          next if f1.index('!_TAG_') != 0 && @seen_filenames.include?(f2)
          # preserve other tags from original file
          @formatter.write_line(line)
        end
      end
    end

    def write(tag, out)
      @formatter.write(tag, out)
      @seen_filenames << @formatter.relative_path(tag)
    end
  end
end
