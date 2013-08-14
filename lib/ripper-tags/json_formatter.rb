require 'yajl'
require 'ripper-tags/default_formatter'

module RipperTags
  class JSONFormatter < DefaultFormatter
    def format(tag)
      Yajl.dump(tag)
    end
  end
end
