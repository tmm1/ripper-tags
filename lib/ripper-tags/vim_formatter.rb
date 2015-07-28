require 'ripper-tags/default_formatter'

module RipperTags
  class VimFormatter < DefaultFormatter
    def supported_flags() ['q'] end

    def include_qualified_names?
      return @include_qualified_names if defined? @include_qualified_names
      @include_qualified_names = extra_flag?('q')
    end

    def header
      <<-EOC
!_TAG_FILE_FORMAT\t2\t/extended format; --format=1 will not append ;" to lines/
!_TAG_FILE_SORTED\t1\t/0=unsorted, 1=sorted, 2=foldcase/
      EOC
    end

    # prepend header and sort lines before closing output
    def with_output
      super do |out|
        out.puts header
        @queued_write = []
        yield out
        @queued_write.sort.each do |line|
          out.puts(line)
        end
      end
    end

    def write(tag, out)
      @queued_write << format(tag)
      if include_qualified_names? && tag[:full_name] != tag[:name] && constant?(tag)
        @queued_write << format(tag, :full_name)
      end
    end

    def display_constant(const)
      const.to_s.gsub('::', '.')
    end

    def display_pattern(tag)
      tag.fetch(:pattern).to_s.gsub('\\','\\\\\\\\').gsub('/','\\/')
    end

    def display_class(tag)
      if tag[:class]
        "\tclass:%s" % display_constant(tag[:class])
      else
        ""
      end
    end

    def display_inheritance(tag)
      if tag[:inherits] && 'class' == tag[:kind]
        "\tinherits:%s" % display_constant(tag[:inherits])
      else
        ""
      end
    end

    def display_kind(tag)
      case tag.fetch(:kind)
      when 'method' then 'f'
      when 'singleton method' then 'F'
      when 'constant' then 'C'
      when 'scope', 'belongs_to', 'has_one', 'has_many', 'has_and_belongs_to_many'
        'F'
      else tag[:kind].slice(0,1)
      end
    end

    def format(tag, name_field = :name)
      "%s\t%s\t/^%s$/;\"\t%s%s%s" % [
        tag.fetch(name_field),
        relative_path(tag),
        display_pattern(tag),
        display_kind(tag),
        name_field == :full_name ? nil : display_class(tag),
        display_inheritance(tag),
      ]
    end
  end
end
