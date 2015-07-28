begin
  require 'yajl/json_gem' unless defined?(::JSON)
rescue LoadError
  require 'json'
end
require 'ripper-tags/default_formatter'

module RipperTags
  class JSONFormatter < DefaultFormatter
    def with_output
      super do |true_out|
        buffer = []
        yield buffer
        true_out << ::JSON.dump(buffer)
      end
    end

    def write(tag, buffer)
      buffer << tag
    end
  end
end
