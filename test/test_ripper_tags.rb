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

  def test_extract_access
    tags = extract(<<-EOC)
      class Test
        def abc() end
      private
        def def() end
      protected
        def ghi() end
      public
        def jkl() end
      end
    EOC

    assert_equal nil,         tags.find{ |t| t[:name] == 'abc' }[:access]
    assert_equal 'private',   tags.find{ |t| t[:name] == 'def' }[:access]
    assert_equal 'protected', tags.find{ |t| t[:name] == 'ghi' }[:access]
    assert_equal 'public',    tags.find{ |t| t[:name] == 'jkl' }[:access]
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
end
