module RipperTags
  class DefaultFormatter
    def initialize(tags)
      @tags = tags
    end
    def body
      data = []
      @tags.each do |tag|
        kind = case tag[:kind]
               when /method$/ then 'def'
               when /^const/  then 'const'
               else tag[:kind]
               end

        if kind == 'class' && tag[:inherits]
          suffix = " < #{tag[:inherits]}"
        else
          suffix = ''
        end
        data << "#{tag[:line].to_s.rjust(5)}  #{kind.to_s.rjust(6)}   #{tag[:full_name]}#{suffix}"
      end
      data.join("\n") unless data.empty?
    end
    def build
      body
    end
  end
end
