require "prism"

module RipperTags
  class PrismParser
    def self.extract(data, file = "(eval)")
      visitor = PrismVisitor.new(file)
      Prism.parse(data).value.accept(visitor)
      visitor.tags
    end
  end

  class PrismVisitor < Prism::Visitor
    attr_reader :tags
    def initialize(file)
      @tags = []
      @file = file
      @context = []
      @is_singleton_class = false
    end
    
    def visit_def_node(node)
      context_prefix = @context.last || "Object"
      context_separator = node.receiver.is_a?(Prism::SelfNode) || @is_singleton_class ? "." : "#"
      @tags << {
        :name => node.name.to_s,
        :full_name => "#{context_prefix}#{context_separator}#{node.name}",
        :class => nil,
        :inherits => nil,
        :kind => "method",
        :line => node.name_loc.start_line,
        :language => "Ruby",
        :path => @file,
        :pattern => nil,
        :access => nil
      }
      super
    end

    def visit_alias_method_node(node)
      context_prefix = @context.last || "Object"
      context_separator = @is_singleton_class ? "." : "#"
      @tags << {
        :name => node.new_name.unescaped,
        :full_name => "#{context_prefix}#{context_separator}#{node.new_name.unescaped}",
        :class => nil,
        :inherits => nil,
        :kind => "method",
        :line => node.new_name.value_loc.start_line,
        :language => "Ruby",
        :path => @file,
        :pattern => nil,
        :access => nil
      } if node.new_name.is_a?(Prism::SymbolNode)
      super
    end
    
    def visit_constant_write_node(node)
      @tags << {
        :name => node.name.to_s,
        :full_name => full_name(node),
        :class => nil,
        :inherits => nil,
        :kind => "constant",
        :line => node.name_loc.start_line,
        :language => "Ruby",
        :path => @file,
        :pattern => nil,
        :access => nil
      }
      super
    end
    
    def visit_constant_path_write_node(node)
      @tags << {
        :name => node.target.child.name.to_s,
        :full_name => full_name(node.target),
        :class => nil,
        :inherits => nil,
        :kind => "constant",
        :line => node.location.start_line,
        :language => "Ruby",
        :path => @file,
        :pattern => nil,
        :access => nil
      }
      super
    end
    
    def visit_class_node(node)
      module_name = full_name(node.constant_path)
      @tags << {
        :name => node.name.to_s,
        :full_name => module_name,
        :class => nil,
        :inherits => nil,
        :kind => "class",
        :line => node.location.start_line,
        :language => "Ruby",
        :path => @file,
        :pattern => nil,
        :access => nil
      }
      @context << module_name
      super
      @context.pop
    end
    
    def visit_module_node(node)
      module_name = full_name(node.constant_path)
      @tags << {
        :name => node.name.to_s,
        :full_name => module_name,
        :class => nil,
        :inherits => nil,
        :kind => "module",
        :line => node.location.start_line,
        :language => "Ruby",
        :path => @file,
        :pattern => nil,
        :access => nil
      }
      @context << module_name
      super
      @context.pop
    end
    
    def visit_call_node(node)
      if node.name == :class_eval && (node.receiver.is_a?(Prism::ConstantReadNode) || node.receiver.is_a?(Prism::ConstantPathNode))
        module_name = full_name(node.receiver)
        @context << module_name
        super
        @context.pop
      else
        super
      end
    end
    
    # FIXME: not deep nesting safe
    def visit_singleton_class_node(node)
      return super unless node.expression.is_a?(Prism::SelfNode)
      @is_singleton_class = true
      super
      @is_singleton_class = false
    end

  private
    def full_name(node)
      context_prefix = @context.empty? ? "" : "#{@context.last}::"
      case node
      when Prism::ConstantReadNode
        context_prefix + node.name.to_s
      when Prism::ConstantWriteNode
        context_prefix + node.name.to_s
      when Prism::ConstantPathNode
        context_prefix + "#{full_name(node.parent)}::#{node.child.name}"
      else
        raise "don't know how to extract full_name of #{node.type}"
      end
    end
  end
end
