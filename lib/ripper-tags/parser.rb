require 'ripper'

module RipperTags

class Parser < Ripper
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
    return if first == :~
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
    [:alias, lhs[0], rhs[0], rhs[1]] if lhs && rhs
  end
  def on_assign(lhs, rhs)
    return if lhs.nil?
    return if lhs[0] == :field
    return if lhs[0] == :aref_field
    lhs, line = lhs
    [:assign, lhs, rhs, line]
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
    return if a.nil? || b.nil?
    a.flatten!(1)
    [[a && a[0], b[0]].join('::'), b[1]]
  end
  alias on_const_path_field on_const_path_ref

  def on_binary(*args)
  end

  def on_command(name, *args)
    case name[0]
    when "define_method", "alias_method",
         "has_one", "has_many",
         "belongs_to", "has_and_belongs_to_many",
         "scope", "named_scope",
         /^attr_(accessor|reader|writer)$/
      on_method_add_arg([:fcall, name], args[0])
    end
  end
  def on_bodystmt(*args)
    args
  end
  def on_if(condition, success, failure)
    ret = [success, failure].flatten(1).compact
    ret.any?? ret : nil
  end
  alias on_unless on_if

  def on_unless_mod(condition, success)
    nil
  end
  alias on_if_mod on_unless_mod

  def on_dyna_symbol(*args)
    if args.length == 1 && args[0]
      [args[0], lineno]
    end
  end

  undef on_tstring_content
  def on_tstring_content(str)
    str
  end

  def on_xstring_add(first, arg)
    arg if first.nil?
  end

  def on_var_ref(*args)
    on_vcall(*args) || args
  end

  def on_vcall(name)
    [name[0].to_sym] if name[0].to_s =~ /^(private|protected|public)$/
  end

  def on_call(lhs, op, rhs)
    return unless lhs && rhs
    arg = block = nil
    [:call, lhs[0], rhs[0], arg, block]
  end

  def on_method_add_arg(call, args)
    call_name = call && call[0]
    first_arg = args && :args == args[0] && args[1]

    if :call == call_name && first_arg
      if args.length == 2
        # augment call if a single argument was used
        call = call.dup
        call[3] = args[1]
      end
      call
    elsif :fcall == call_name && first_arg
      name, line = call[1]
      case name
      when "alias_method"
        [:alias, args[1][0], args[2][0], line] if args[1] && args[2]
      when "define_method"
        [:def, args[1][0], line]
      when "scope", "named_scope"
        [:rails_def, :scope, args[1][0], line]
      when /^attr_(accessor|reader|writer)$/
        gen_reader = $1 != 'writer'
        gen_writer = $1 != 'reader'
        args[1..-1].inject([]) do |gen, arg|
          gen << [:def, arg[0], line] if gen_reader
          gen << [:def, "#{arg[0]}=", line] if gen_writer
          gen
        end
      when "has_many", "has_and_belongs_to_many"
        a = args[1][0]
        kind = name.to_sym
        gen = []
        unless a.is_a?(Enumerable) && !a.is_a?(String)
          a = a.to_s
          gen << [:rails_def, kind, a, line]
          gen << [:rails_def, kind, "#{a}=", line]
          if (sing = a.chomp('s')) != a
            # poor man's singularize
            gen << [:rails_def, kind, "#{sing}_ids", line]
            gen << [:rails_def, kind, "#{sing}_ids=", line]
          end
        end
        gen
      when "belongs_to", "has_one"
        a = args[1][0]
        unless a.is_a?(Enumerable) && !a.is_a?(String)
          kind = name.to_sym
          %W[ #{a} #{a}= build_#{a} create_#{a} create_#{a}! ].inject([]) do |all, ident|
            all << [:rails_def, kind, ident, line]
          end
        end
      end
    else
      super
    end
  end

  # handle `Class.new arg` call without parens
  def on_command_call(*args)
    if args.last && :args == args.last[0]
      args_add = args.pop
      call = on_call(*args)
      on_method_add_arg(call, args_add)
    else
      super
    end
  end

  def on_fcall(*args)
    [:fcall, *args]
  end

  def on_args_add(sub, arg)
    if sub
      sub + [arg]
    else
      [:args, arg].compact
    end
  end

  def on_do_block(*args)
    args
  end

  def on_method_add_block(method, body)
    return unless method
    if %w[class_eval module_eval].include?(method[2]) && body
      [:class_eval, [
        method[1].is_a?(Array) ? method[1][0] : method[1],
        method[3]
      ], body.last]
    elsif :call == method[0] && body
      # augment the `Class.new/Struct.new` call with associated block
      call = method.dup
      call[4] = body.last
      call
    else
      super
    end
  end
end

  class Visitor
    attr_reader :tags

    def initialize(sexp, path, data)
      @path = path
      @lines = data.split("\n")
      @namespace = []
      @tags = []
      @is_singleton = false
      @current_access = nil

      process(sexp)
    end

    def emit_tag(kind, line, opts={})
      @tags << {
        :kind => kind.to_s,
        :line => line,
        :language => 'Ruby',
        :path => @path,
        :pattern => @lines[line-1].chomp,
        :access => @current_access
      }.update(opts).delete_if{ |k,v| v.nil? }
    end

    def process(sexp)
      return unless sexp
      return if Symbol === sexp

      case sexp[0]
      when Array
        sexp.each{ |child| process(child) }
      when Symbol
        name, *args = sexp
        __send__("on_#{name}", *args) unless name.to_s.index("@") == 0
      when String, nil
        # nothing
      end
    end

    def on_module_or_class(kind, name, superclass, *body)
      name, line = *name
      @namespace << name

      prev_access = @current_access
      @current_access = nil

      if superclass
        superclass_name = superclass[0] == :call ?
          superclass[1] :
          superclass[0]
        superclass_name = nil unless superclass_name =~ /^[A-Z]/
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

    def on_module(name, *body)
      on_module_or_class(:module, name, nil, *body)
    end

    def on_class(name, superclass, *body)
      on_module_or_class(:class, name, superclass, *body)
    end

    def on_private()   @current_access = 'private'   end
    def on_protected() @current_access = 'protected' end
    def on_public()    @current_access = 'public'    end

    # Ripper trips up on keyword arguments in pre-2.1 Ruby and supplies extra
    # arguments that we just ignore here
    def on_assign(name, rhs, line, *junk)
      return unless name =~ /^[A-Z]/ && junk.empty?

      if rhs && :call == rhs[0] && rhs[1] && "#{rhs[1][0]}.#{rhs[2]}" =~ /^(Class|Module|Struct)\.new$/
        kind = $1 == 'Module' ? :module : :class
        superclass = $1 == 'Class' ? rhs[3] : nil
        superclass.flatten! if superclass
        return on_module_or_class(kind, [name, line], superclass, rhs[4])
      end

      namespace = @namespace
      if name.include?('::')
        parts = name.split('::')
        name = parts.pop
        namespace = namespace + parts
      end

      emit_tag :constant, line,
        :name => name,
        :full_name => (namespace + [name]).join('::'),
        :class => namespace.join('::')
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

    def on_rails_def(kind, name, line)
      ns = (@namespace.empty?? 'Object' : @namespace.join('::'))

      emit_tag kind, line,
        :language => 'Rails',
        :name => name,
        :full_name => "#{ns}.#{name}",
        :class => ns
    end

    def on_sclass(name, body)
      name, _ = *name
      @namespace << name unless name == 'self'
      prev_is_singleton, @is_singleton = @is_singleton, true
      process(body)
    ensure
      @namespace.pop     unless name == 'self'
      @is_singleton = prev_is_singleton
    end

    def on_class_eval(name, body)
      name, _ = *name
      @namespace << name
      process(body)
    ensure
      @namespace.pop
    end

    def on_call(*args)
    end
    alias on_aref_field on_call
    alias on_field on_call
    alias on_fcall on_call
    alias on_args on_call
  end
end
