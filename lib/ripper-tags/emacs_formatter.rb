module RipperTags
  class EmacsFormatter
    def initialize(tags)
      @tags = tags
    end

    def build
      data = []
      @tags.each do |tag|
        data << "#{tag[:pattern]}\x7F#{tag[:name]}\x01#{tag[:line]},0"
      end
      data.join("\n")
    end
  end
end
