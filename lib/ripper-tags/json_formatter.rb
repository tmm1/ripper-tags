begin
  require 'yajl/json_gem' unless defined?(::JSON)
rescue LoadError
  require 'json'
end
require 'ripper-tags/default_formatter'

module RipperTags
  class JSONFormatter < DefaultFormatter
    def supported_flags() ['s'] end

    def stream_format?
      return @stream_format if defined? @stream_format
      @stream_format = extra_flag?('s')
    end

    def with_output
      super do |true_out|
        buffer = []
        yield buffer

        if stream_format?
          buffer.each { |tag| true_out.puts ::JSON.dump(tag) }
        else
          true_out.write ::JSON.dump(buffer)
        end
      end
    end

    def write(tag, buffer)
      buffer << tag
    end
  end
end
