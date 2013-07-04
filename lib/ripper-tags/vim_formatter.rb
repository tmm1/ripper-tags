class TagRipper
  class VimFormatter
    def header
      <<-EOC
!_TAG_FILE_FORMAT\t2\t/extended format; --format=1 will not append ;" to lines/
!_TAG_FILE_SORTED\t1\t/0=unsorted, 1=sorted, 2=foldcase/
      EOC
    end
    def footer
      ''
    end

    def initialize(tags)
      @tags = tags.sort_by { |t| t[:name] }
    end

    def body
      data = []
      @tags.each do |tag|
        kwargs = ''
        kwargs << "\tclass:#{tag[:class].gsub('::','.')}" if tag[:class]
        kwargs << "\tinherits:#{tag[:inherits].gsub('::','.')}" if tag[:inherits]

        kind = case tag[:kind]
               when 'method' then 'f'
               when 'singleton method' then 'F'
               when 'constant' then 'C'
               else tag[:kind].slice(0,1)
               end

        code = tag[:pattern].gsub('\\','\\\\\\\\').gsub('/','\\/')
        data << "%s\t%s\t/^%s$/;\"\t%c%s" % [tag[:name], tag[:path], code, kind, kwargs]
      end
      data.join("\n")
    end

    def build
      '' << header << body << footer
    end
  end
end
