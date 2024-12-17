require "prism"

module RipperTags
  # Prism-powered tag parser based on Prism walk_tree functionality; very bare-bones.
  class ParserPrismWalk
    def self.extract(data, file = "(eval)")
      new(data, file).tag_nodes.map(&:to_hash)
    end

    def initialize(code, filename)
      @code = code
      @filename = filename
    end
    
    def tag_nodes
      return to_enum(__method__) unless block_given?
      parsed_doc = Prism.parse(@code)
      walk_tree(Context.new(@filename), parsed_doc.value) do |context, node|
        # TODO: support more node types!
        case node.type
        when :def_node
          yield TagWrapper.new(context, node, :method)
          context
        else
          context
        end
      end
    end
    
    def walk_tree(context, node, &block)
      new_context = block.call(context, node)
      # FIXME: find an alternative to Prism's compact_child_nodes with fewer array instances
      node.compact_child_nodes.each do |child_node|
        walk_tree(new_context, child_node, &block)
      end
    end
    
    class Context
      attr_reader :filename
      def initialize(filename)
        @filename = filename
      end
    end

    class TagWrapper
      attr_reader :kind
      def initialize(context, node, kind)
        @context = context
        @node = node
        @kind = kind
      end

      def name
        @node.name.to_s
      end

      def start_line
        @node.name_loc.start_line
      end

      def to_hash
        context_prefix = "Object"
        context_separator = "#"
        {
          :name => name,
          :full_name => "#{context_prefix}#{context_separator}#{@node.name}",
          :class => nil,
          :inherits => nil,
          :kind => @kind.to_s,
          :line => start_line,
          :language => "Ruby",
          :path => @context.filename,
          :pattern => nil,
          :access => nil
        }
      end
    end
  end
end
