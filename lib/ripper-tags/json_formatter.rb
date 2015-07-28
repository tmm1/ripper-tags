begin
  require 'yajl'
rescue LoadError
  require 'json'
end
require 'ripper-tags/default_formatter'

module RipperTags
  class JSONFormatter < DefaultFormatter
    if defined?(::Yajl)
      def format(tag)
        Yajl.dump(tag)
      end
    else
      def format(tag)
        JSON.dump(tag)
      end
    end
  end
end
