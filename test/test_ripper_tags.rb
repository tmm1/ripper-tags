require File.expand_path('../../lib/tag_ripper', __FILE__)
require 'test/unit'

class TagRipperTest < Test::Unit::TestCase
  def test_extract_basics
    tags = TagRipper.extract(<<-EOC)
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
    ], tags.map{ |t| t[:full_name] }
  end

  def test_extract_access
    tags = TagRipper.extract(<<-EOC)
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
end
