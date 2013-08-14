require 'ripper-tags/default_formatter'

module RipperTags
  class EmacsFormatter < DefaultFormatter
    def format(tag)
      "%s\x7F%s\x01%d,0" % [
        tag[:pattern],
        tag[:name],
        tag[:line],
      ]
    end
  end
end
