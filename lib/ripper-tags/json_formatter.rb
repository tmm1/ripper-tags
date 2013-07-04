class TagRipper
  class JSONFormatter
    def initialize(tags)
      @tags = tags
    end
    def build
      @tags.map do |tag|
        Yajl.dump(tag)
      end.join("\n")
    end
  end
end
