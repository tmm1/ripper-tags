require 'test/unit'
require 'stringio'
require 'ostruct'
require 'ripper-tags'

class FormattersTest < Test::Unit::TestCase
  def build_tag(attrs = {})
    { :kind => 'class',
      :line => 1,
      :path => './script.rb',
      :access => 'public',
    }.merge(attrs)
  end

  def formatter_for(opts)
    options = OpenStruct.new(opts)
    RipperTags.formatter_for(options)
  end

  def test_default
    default = formatter_for(:tag_file_name => '-')

    tags = []
    tags << build_tag(:line => 1, :kind => 'class', :full_name => 'A::B', :inherits => 'C')
    tags << build_tag(:line => 2, :kind => 'method', :full_name => 'A::B#imethod')
    tags << build_tag(:line => 3, :kind => 'singleton method', :full_name => 'A::B.smethod')

    output = capture_stdout do
      default.with_output do |out|
        tags.each { |tag| default.write(tag, out) }
      end
    end

    assert_equal <<-OUT, output
    1   class   A::B < C
    2     def   A::B#imethod
    3     def   A::B.smethod
    OUT
  end

  def test_vim
    vim = formatter_for(:vim => true)
    assert_equal %{C\t./script.rb\t/^class C < D$/;"\tc\tclass:A.B\tinherits:D}, vim.format(build_tag(
      :kind => 'class', :name => 'C',
      :pattern => "class C < D",
      :class => 'A::B', :inherits => 'D'
    ))
    assert_equal %{M\t./script.rb\t/^module M$/;"\tm\tclass:A.B}, vim.format(build_tag(
      :kind => 'module', :name => 'M',
      :pattern => "module M",
      :class => 'A::B'
    ))
    assert_equal %{imethod\t./script.rb\t/^  def imethod(*args)$/;"\tf\tclass:A.B}, vim.format(build_tag(
      :kind => 'method', :name => 'imethod',
      :pattern => "  def imethod(*args)",
      :class => 'A::B'
    ))
    assert_equal %{smethod\t./script.rb\t/^  def self.smethod(*args)$/;"\tF\tclass:A.B}, vim.format(build_tag(
      :kind => 'singleton method', :name => 'smethod',
      :pattern => "  def self.smethod(*args)",
      :class => 'A::B'
    ))
  end

  def capture_stdout
    old_stdout, $stdout = $stdout, StringIO.new
    begin
      yield
    ensure
      out = $stdout.string
      $stdout = old_stdout
      return out
    end
  end
end
