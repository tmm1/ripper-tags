module RipperTags
  class DefaultFormatter
    attr_reader :options

    def initialize(options)
      @options = options
    end

    def with_output
      if '-' == options.tag_file_name
        yield $stdout
      else
        File.open(options.tag_file_name, 'w+') do |outfile|
          yield outfile
        end
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
