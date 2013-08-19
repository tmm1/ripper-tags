require 'pathname'

module RipperTags
  class DefaultFormatter
    attr_reader :options

    def initialize(options)
      @options = options
    end

    def stdout?
      '-' == options.tag_file_name
    end

    def with_output
      if stdout?
        yield $stdout
      else
        File.open(options.tag_file_name, 'w+') do |outfile|
          yield outfile
        end
      end
    end

    def tag_file_dir
      @tag_file_dir ||= Pathname.new(options.tag_file_name).dirname
    end

    def relative_path(tag)
      path = tag.fetch(:path)
      if options.tag_relative && !stdout? && path.index('/') != 0
        Pathname.new(path).relative_path_from(tag_file_dir).to_s
      else
        path
      end
    end

    def display_kind(tag)
      case tag.fetch(:kind)
      when /method$/ then 'def'
      when /^const/  then 'const'
      else tag[:kind]
      end
    end

    def display_inheritance(tag)
      if 'class' == tag[:kind] && tag[:inherits]
        " < #{tag[:inherits]}"
      else
        ""
      end
    end

    def format(tag)
      "%5s  %6s   %s%s" % [
        tag.fetch(:line).to_s,
        display_kind(tag),
        tag.fetch(:full_name),
        display_inheritance(tag)
      ]
    end

    def write(tag, io)
      io.puts format(tag)
    end
  end
end
