require 'test/unit'
require 'ripper-tags/parser'

class TagRipperTest < Test::Unit::TestCase
  def extract(code)
    RipperTags::Parser.extract(code)
  end

  def inspect(tag)
    raise ArgumentError, "expected tag, got %p" % tag unless tag
    "%d: %s %s%s" % [
      tag[:line],
      tag[:kind],
      tag[:full_name],
      tag[:inherits] ? " < #{tag[:inherits]}" : "",
    ]
  end

  def test_extract_basics
    tags = extract(<<-EOC)
      Const1 = 123
      def gmethod
      end
      module M
        class C
          Const2 = 456
          def imethod
          end
          alias imethod_alias imethod
          def self.cmethod
          end
        end
      end
      class M::C
        def imethod2
        end
        def self.cmethod2
        end
        class << self
          def cmethod3
          end
          alias cmethod_alias cmethod3
        end
      end
      M::C.class_eval do
        def imethod3
        end
        def self.cmethod4
        end
      end
      M::C::Const3 = true
      M.class_eval do
        def imethod5
        end
      end
    EOC

    assert_equal %w[
      Const1
      Object#gmethod
      M
      M::C
      M::C::Const2
      M::C#imethod
      M::C#imethod_alias
      M::C.cmethod
      M::C
      M::C#imethod2
      M::C.cmethod2
      M::C.cmethod3
      M::C.cmethod_alias
      M::C#imethod3
      M::C.cmethod4
      M::C::Const3
      M#imethod5
    ], tags.map{ |t| t[:full_name] }
  end

  def test_nested_constant_definitions
    tags = extract(<<-EOC)
      STATUSES = [
        OPEN = 'open',
      ]

      DISPLAY_MAPPING = {
        CANCELLED = 'cancelled' => 'Cancelled by user',
      }
    EOC

    assert_equal %w[
      OPEN
      STATUSES
      CANCELLED
      DISPLAY_MAPPING
    ], tags.map { |t| t[:name] }

    tags.each do |t|
      assert_equal t[:name], t[:full_name]
    end
  end

  def test_extract_namespaced_constant
    tags = extract(<<-EOC)
      A::B::C = 1
      module A::B
        D::E = 2
      end
    EOC

    assert_equal 3, tags.size

    assert_equal 'C', tags[0][:name]
    assert_equal 'A::B::C', tags[0][:full_name]
    assert_equal 'A::B', tags[0][:class]

    assert_equal 'E', tags[2][:name]
    assert_equal 'A::B::D::E', tags[2][:full_name]
    assert_equal 'A::B::D', tags[2][:class]
  end

  def test_extract_access
    tags = extract(<<-EOC)
      class Test
        def abc() end
      private
        def def() end
      public
        def ghi() end
      protected
        def jkl() end
      public_class_method
        def self.mno() end
      private_class_method
        def self.pqr() end
      end
    EOC

    assert_equal nil,                tags.find{ |t| t[:name] == 'abc' }[:access]
    assert_equal 'private',          tags.find{ |t| t[:name] == 'def' }[:access]
    assert_equal 'public',           tags.find{ |t| t[:name] == 'ghi' }[:access]
    assert_equal 'protected',        tags.find{ |t| t[:name] == 'jkl' }[:access]
    assert_equal 'public',           tags.find{ |t| t[:name] == 'mno' }[:access]
    assert_equal 'singleton method', tags.find{ |t| t[:name] == 'mno' }[:kind]
    assert_equal 'private',          tags.find{ |t| t[:name] == 'pqr' }[:access]
    assert_equal 'singleton method', tags.find{ |t| t[:name] == 'pqr' }[:kind]
  end

  def test_extract_access_scope_inheritance
    %w(private public protected).each do |visibility|
      tags = extract(<<-EOC)
        class Test
        #{visibility}
          def abc() end
          def def() end
          def ghi() end
      EOC

      assert tags.all?{ |t| t[:access] == visibility }
    end
  end

  def test_extract_one_line_definition_access
    %w(private public protected).each do |visibility|
      tags = extract(<<-EOC)
        class Test
          #{visibility} def abc() end
          def def() end
        end
      EOC

      assert_equal visibility, tags.find{ |t| t[:name] == 'abc' }[:access]
      assert_equal nil, tags.find{ |t| t[:name] == 'def' }[:access]
    end

    %w(private_class_method public_class_method).each do |visibility|
      tags = extract(<<-EOC)
        class Test
          #{visibility} def self.abc() end
          def self.def() end
        end
      EOC

      scope = visibility.sub("_class_method", "")
      assert_equal scope, tags.find{ |t| t[:name] == 'abc' }[:access]
      assert_equal nil, tags.find{ |t| t[:name] == 'def' }[:access]
    end
  end

  def test_extract_module_eval
    tags = extract(<<-EOC)
      M.module_eval do
        class C; end
        def imethod; end
      end
    EOC
    assert_equal '2: class M::C', inspect(tags[0])
    assert_equal '3: method M#imethod', inspect(tags[1])
  end

  def test_extract_manual_subclass
    tags = extract(<<-EOC)
      module M
        C = Class.new(Sup::Klass)
        C = Class.new Sup::Klass
        C = Class.new
        C = Class.new(klass)
      end
    EOC
    assert_equal '2: class M::C < Sup::Klass', inspect(tags[1])
    assert_equal '3: class M::C < Sup::Klass', inspect(tags[2])
    assert_equal '4: class M::C', inspect(tags[3])
    assert_equal '5: class M::C', inspect(tags[4])
  end

  def test_extract_assign_from_struct
    tags = extract(<<-EOC)
      module M
        C = Struct.new(:name)
        C = Struct.new :name
      end
    EOC
    assert_equal '2: class M::C', inspect(tags[1])
    assert_equal '3: class M::C', inspect(tags[2])
  end

  def test_extract_class_struct_scope
    tags = extract(<<-EOC)
      module M
        S = Struct.new(:name) do
          def imethod; end
        end
        C = Class.new(SuperClass) do
          def imethod; end
        end
      end
    EOC
    assert_equal '3: method M::S#imethod', inspect(tags[2])
    assert_equal '5: class M::C < SuperClass', inspect(tags[3])
    assert_equal '6: method M::C#imethod', inspect(tags[4])
  end

  def test_extract_manual_module
    tags = extract(<<-EOC)
      class C
        M = Module.new
        M = Module.new do
          def imethod; end
        end
      end
    EOC
    assert_equal '2: module C::M', inspect(tags[1])
    assert_equal '3: module C::M', inspect(tags[2])
    assert_equal '4: method C::M#imethod', inspect(tags[3])
  end

  def test_extract_define_method
    tags = extract(<<-EOC)
      module M
        define_method(:imethod) do |arg|
        end
        define_method :imethod do |arg|
        end
        define_method(:imethod) { |arg| }
      end
    EOC
    assert_equal '2: method M#imethod', inspect(tags[1])
    assert_equal '4: method M#imethod', inspect(tags[2])
    assert_equal '6: method M#imethod', inspect(tags[3])
  end

  def test_ignore_dynamic_define_method
    tags = extract(<<-EOC)
      module M
        define_method(:"imethod_\#{i}") { |arg| }
        define_method("imethod_\#{i}") { |arg| }
      end
    EOC
    assert_equal 1, tags.length
  end

  def test_extract_alias
    tags = extract(<<-EOC)
      module M
        alias :"[]" :get
        alias :"[]=" :set
        alias :set :"[]="
      end
    EOC
    assert_equal '2: alias M#[] < get', inspect(tags[1])
    assert_equal '3: alias M#[]= < set', inspect(tags[2])
    assert_equal '4: alias M#set < []=', inspect(tags[3])
  end

  def test_ignore_dynamic_alias
    tags = extract(<<-EOC)
      module M
        alias :"imethod_\#{i}" :foo
        alias "imethod_\#{i}" :foo
      end
    EOC
    assert_equal 1, tags.length
  end

  def test_extract_alias_method
    tags = extract(<<-EOC)
      module M
        alias_method(:imethod, :foo)
        alias_method :imethod, :foo
      end
    EOC
    assert_equal '2: alias M#imethod < foo', inspect(tags[1])
    assert_equal '3: alias M#imethod < foo', inspect(tags[2])
  end

  def test_ignore_dynamic_alias_method
    tags = extract(<<-EOC)
      module M
        alias_method :"imethod_\#{i}", :foo
        alias_method "imethod_\#{i}", :foo
      end
    EOC
    assert_equal 1, tags.length
  end

  def test_extract_attr_accessor
    tags = extract(<<-EOC)
      module M
        attr_accessor :a, :b
        attr_reader(:a, :b)
        attr_writer(:a, :b)
      end
    EOC
    assert_equal '2: method M#a',  inspect(tags[1])
    assert_equal '2: method M#a=', inspect(tags[2])
    assert_equal '2: method M#b',  inspect(tags[3])
    assert_equal '2: method M#b=', inspect(tags[4])
    assert_equal '3: method M#a',  inspect(tags[5])
    assert_equal '3: method M#b',  inspect(tags[6])
    assert_equal '4: method M#a=', inspect(tags[7])
    assert_equal '4: method M#b=', inspect(tags[8])
  end

  def test_extract_rails_associations
    tags = extract(<<-EOC)
      class C
        belongs_to :org, :touch => true
        has_one :author, :dependent => :destroy
        has_many :posts
        has_and_belongs_to_many :tags, :join_table => 'c_tags'
      end
    EOC
    assert_equal 19, tags.length
    assert_equal 'Rails', tags[1][:language]

    assert_equal '2: belongs_to C.org', inspect(tags[1])
    assert_equal '2: belongs_to C.org=', inspect(tags[2])
    assert_equal '2: belongs_to C.build_org', inspect(tags[3])
    assert_equal '2: belongs_to C.create_org', inspect(tags[4])
    assert_equal '2: belongs_to C.create_org!', inspect(tags[5])

    assert_equal '3: has_one C.author', inspect(tags[6])
    assert_equal '3: has_one C.author=', inspect(tags[7])
    assert_equal '3: has_one C.build_author', inspect(tags[8])
    assert_equal '3: has_one C.create_author', inspect(tags[9])
    assert_equal '3: has_one C.create_author!', inspect(tags[10])

    assert_equal '4: has_many C.posts', inspect(tags[11])
    assert_equal '4: has_many C.posts=', inspect(tags[12])
    assert_equal '4: has_many C.post_ids', inspect(tags[13])
    assert_equal '4: has_many C.post_ids=', inspect(tags[14])

    assert_equal '5: has_and_belongs_to_many C.tags', inspect(tags[15])
    assert_equal '5: has_and_belongs_to_many C.tags=', inspect(tags[16])
    assert_equal '5: has_and_belongs_to_many C.tag_ids', inspect(tags[17])
    assert_equal '5: has_and_belongs_to_many C.tag_ids=', inspect(tags[18])
  end

  def test_extract_rails_scopes
    tags = extract(<<-EOC)
      class C
        named_scope(:red) { {:conditions=>{:color => 'red'}} }
        scope :red, where(:color => 'red')
      end
    EOC
    assert_equal 'Rails', tags[1][:language]

    assert_equal '2: scope C.red',  inspect(tags[1])
    assert_equal '3: scope C.red',  inspect(tags[2])
  end

  def test_extract_delegate
    tags = extract(<<-EOC)
      class C
        delegate :foo,
                 :bar, to: :thingy
        delegate :x, to: :thingy, prefix: true
        delegate :y, to: :thingy, prefix: :pos

        delegate :z, :to => :thingy, :prefix => true
        delegate :gamma, :to => :thingy, :prefix => :radiation

        delegate :exist?, to: :@model
        delegate :count, to: :@items, prefix: :itm

        def thingy
          Object.new
        end
      end
    EOC

    assert_equal 10, tags.count
    assert_equal '2: method C#foo', inspect(tags[1])
    assert_equal '3: method C#bar', inspect(tags[2])
    assert_equal '4: method C#thingy_x', inspect(tags[3])
    assert_equal '5: method C#pos_y', inspect(tags[4])
    assert_equal '7: method C#thingy_z', inspect(tags[5])
    assert_equal '8: method C#radiation_gamma', inspect(tags[6])
    assert_equal '10: method C#exist?', inspect(tags[7])
    assert_equal '11: method C#itm_count', inspect(tags[8])
  end

  def test_invalid_delegate
    tags = extract(<<-EOC)
      class C
        delegate
        delegate "foo"
        delegate [1, 2]
      end
    EOC

    assert_equal 1, tags.count
  end

  def test_extract_def_delegator
    tags = extract(<<-EOC)
      class F
        def_delegator :@things, :[]
        def_delegator :@things, :size, :count
      end
    EOC

    assert_equal 3, tags.count
    assert_equal '2: method F#[]', inspect(tags[1])
    assert_equal '3: method F#count', inspect(tags[2])
  end

  def test_extract_def_delegators
    tags = extract(<<-EOC)
      class F
        def_delegators :@things, :foo, :bar
      end
    EOC

    assert_equal 3, tags.count
    assert_equal '2: method F#foo', inspect(tags[1])
    assert_equal '2: method F#bar', inspect(tags[2])
  end

  def test_extract_from_erb
    tags = extract(<<-EOC)
      class NavigationTest < ActionDispatch::IntegrationTest
      <% unless options[:skip_active_record] -%>
        fixtures :all
      <% end -%>

        # test "the truth" do
        #   assert true
        # end
      end
    EOC

    assert_equal 1, tags.size
    assert_equal 'NavigationTest', tags[0][:name]
  end

  def test_extract_with_keyword_variables
    tags = extract(<<-EOC)
      class Foo
        @public
        @protected
        @private
      end
    EOC

    assert_equal 1, tags.size
    assert_equal 'Foo', tags[0][:name]
  end

  def test_extract_associations_with_class_name
    tags = extract(<<-EOC)
      class Foo
        belongs_to Bar
        has_one Bar
        has_and_belongs_to_many Bar
        has_many Bar
      end
    EOC

    assert_equal 1, tags.size
    assert_equal 'Foo', tags[0][:name]
  end

  def test_extract_class_with_ensure
    tags = extract(<<-EOC)
      class Foo
        i = 1
      ensure
        i = 2
      end
    EOC

    assert_equal 1, tags.size
    assert_equal 'Foo', tags[0][:name]
  end

  def test_extract_class_with_mutiple_rescue_clauses
    tags = extract(<<-EOC)
      class Foo
        i = 1
      rescue ArgumentError
        i = 2
      rescue TypeError
        i = 3
      end
    EOC

    assert_equal 1, tags.size
    assert_equal 'Foo', tags[0][:name]
  end

  def test_extract_within_conditional
    tags = extract(<<-EOC)
      if 1
        def foo() end
      end
      unless 2
        def bar() end
      end
    EOC

    assert_equal 2, tags.size
    assert_equal 'foo', tags[0][:name]
    assert_equal 'bar', tags[1][:name]
  end

  def test_keyword_arguments
    tags = extract(<<-EOC)
      class A
        def foo(o:)
          x = { :a => 1 }
          y = { :b => 2 }
        end
      end
    EOC

    if RUBY_VERSION < '2.1'
      # Ruby 1.9 and 2.0 trip up on keyword argument syntax
      assert_equal 1, tags.size
      assert_equal 'A', tags[0][:name]
    else
      assert_equal 2, tags.size
      assert_equal 'A', tags[0][:name]
      assert_equal 'foo', tags[1][:name]
    end
  end

  def test_attr_protected
    tags = extract(<<-EOC)
      class A
        attr_protected
      end
    EOC

    assert_equal 1, tags.size
    assert_equal 'A', tags[0][:name]
  end

  def test_heredoc
    tags = extract(<<-EOC)
      def foo
        puts "hello", <<~EOF
          world
        EOF
      end

      def bar; end
    EOC

    assert_equal 2, tags.size
    assert_equal 'foo', tags[0][:name]
    assert_equal 'bar', tags[1][:name]
  end

  def test_heredoc_backticks
    tags = extract(<<-EOC)
      class A
        b(<<~EOF)
          `c`
        EOF
      end
    EOC

    assert_equal 1, tags.size
  end

  def test_bare_bang
    tags = extract(<<-EOC)
      if condition
      elsif !other
        # `!other` triggered crash in `elsif` clause
      end
      # also triggered when bare:
      !condition
    EOC

    assert_equal 0, tags.size
  end
end
