require 'ripper'

class TagRipper < Ripper
  def self.extract(data, file='(eval)')
    sexp = new(data, file).parse
    Visitor.new(sexp, file, data).tags
  end

  SCANNER_EVENTS.each do |event|
    module_eval(<<-End, __FILE__, __LINE__ + 1)
      def on_#{event}(tok)
        [tok, lineno]
      end
    End
  end

  def on_stmts_add(first, *rest)
    (first || []) + rest.compact
  end

  def on_module(name, body)
    [:module, name, *body.compact]
  end
  def on_class(name, superclass, body)
    superclass.flatten!(1) if superclass
    [:class, name, superclass, *body.compact]
  end
  def on_def(method, args, body)
    [:def, *method]
  end
  def on_defs(receiver, op, method, args, body)
    receiver.flatten!(1) if receiver
    [:defs, receiver && receiver[0], *method]
  end
  def on_alias(lhs, rhs)
    [:alias, lhs[0], rhs[0], rhs[1]]
  end
  def on_assign(lhs, rhs)
    return if lhs.nil?
    return if lhs[0] == :field
    return if lhs[0] == :aref_field
    [:assign, *lhs.flatten(1)]
  end
  def on_sclass(name, body)
    [:sclass, name && name.flatten(1), *body.compact]
  end
  def on_field(lhs, op, rhs)
    [:field, lhs && lhs[0], rhs[0], rhs[1]]
  end
  def on_aref_field(*args)
    [:aref_field, *args]
  end

  def on_const_path_ref(a, b)
    a.flatten!(1)
    [[a && a[0], b[0]].join('::'), b[1]]
  end
  alias on_const_path_field on_const_path_ref

  def on_binary(*args)
  end

  def on_command(name, *args)
    # if name =~ /^(attr_|alias)/
    #   [name.to_sym, *args]
    # end
  end
  def on_bodystmt(*args)
    args
  end
  def on_if(condition, success, failure)
    ret = [success, failure].flatten(1).compact
    ret.any?? ret : nil
  end

  def on_unless_mod(condition, success)
    nil
  end
  alias on_if_mod on_unless_mod

  def on_var_ref(*args)
    on_vcall(*args) || args
  end

  def on_vcall(name)
    [name[0].to_sym] if name[0].to_s =~ /private|protected|public$/
  end

  def on_call(lhs, op, rhs)
    [:call, lhs && lhs[0], rhs && rhs[0], rhs[1]]
  end

  def on_do_block(*args)
    args
  end

  def on_method_add_block(method, body)
    return unless method and body
    if method[2] == 'class_eval'
      [:class_eval, [
        method[1].is_a?(Array) ? method[1][0] : method[1],
        method[3]
      ], body.last]
    end
  end

  class Visitor
    attr_reader :tags

    def initialize(sexp, path, data)
      @path = path
      @lines = data.split("\n")
      @namespace = []
      @tags = []

      process(sexp)
    end

    def emit_tag(kind, line, opts={})
      @tags << opts.merge(
        :kind => kind.to_s,
        :line => line,
        :language => 'Ruby',
        :path => @path,
        :pattern => @lines[line-1].chomp,
        :access => @current_access
      ).delete_if{ |k,v| v.nil? }
    end

    def process(sexp)
      return unless sexp
      return if Symbol === sexp

      case sexp[0]
      when Array
        sexp.each{ |child| process(child) }
      when Symbol
        name, *args = sexp
        __send__("on_#{name}", *args)
      when String, nil
        # nothing
      end
    end

    def on_module_or_class(kind, name, superclass, body)
      name, line = *name
      @namespace << name

      prev_access = @current_access
      @current_access = nil

      if superclass
        superclass_name = superclass[0] == :call ?
          superclass[1] :
          superclass[0]
      end
      full_name = @namespace.join('::')
      parts = full_name.split('::')
      class_name = parts.pop

      emit_tag kind, line,
        :full_name => full_name,
        :name => class_name,
        :class => parts.any? && parts.join('::') || nil,
        :inherits => superclass_name

      process(body)
    ensure
      @current_access = prev_access
      @namespace.pop
    end

    def on_module(name, body)
      on_module_or_class(:module, name, nil, body)
    end

    def on_class(name, superclass, body)
      on_module_or_class(:class, name, superclass, body)
    end

    def on_private()   @current_access = 'private'   end
    def on_protected() @current_access = 'protected' end
    def on_public()    @current_access = 'public'    end

    def on_assign(name, line)
      return unless name =~ /^[A-Z]/

      emit_tag :constant, line,
        :name => name,
        :full_name => (@namespace + [name]).join('::'),
        :class => @namespace.join('::')
    end

    def on_alias(name, other, line)
      ns = (@namespace.empty?? 'Object' : @namespace.join('::'))

      emit_tag :alias, line,
        :name => name,
        :inherits => other,
        :full_name => "#{ns}#{@is_singleton ? '.' : '#'}#{name}",
        :class => ns
    end

    def on_def(name, line)
      kind = @is_singleton ? 'singleton method' : 'method'
      ns = (@namespace.empty?? 'Object' : @namespace.join('::'))

      emit_tag kind, line,
        :name => name,
        :full_name => "#{ns}#{@is_singleton ? '.' : '#'}#{name}",
        :class => ns
    end

    def on_defs(klass, name, line)
      ns = (@namespace + [klass != 'self' ? klass : nil]).compact
      emit_tag 'singleton method', line,
        :name => name,
        :full_name => ns.join('::') + ".#{name}",
        :class => ns.join('::')
    end

    def on_sclass(name, body)
      name, line = *name
      @namespace << name unless name == 'self'
      prev_is_singleton, @is_singleton = @is_singleton, true
      process(body)
    ensure
      @namespace.pop     unless name == 'self'
      @is_singleton = prev_is_singleton
    end

    def on_class_eval(name, body)
      name, line = *name
      @namespace << name
      process(body)
    ensure
      @namespace.pop
    end

    def on_call(*args)
    end
    alias on_aref_field on_call
    alias on_field on_call
  end
end
