require 'test/unit'
require 'ostruct'
require 'tempfile'
require 'ripper-tags/emacs_formatter'
require 'ripper-tags/emacs_append_formatter'
require 'ripper-tags/vim_formatter'
require 'ripper-tags/vim_append_formatter'

class FormattersAppendTest < Test::Unit::TestCase
  def build_tag(name, path)
    { :name => name,
      :path => path,
      :pattern => "def #{name}",
      :kind => 'method',
      :line => 1
    }
  end

  def test_vim_append
    file = Tempfile.new('ripper-tags')
    begin
      options = OpenStruct.new(:tag_file_name => file.path)
      fmt = RipperTags::VimFormatter.new(options)
      fmt.with_output do |out|
        fmt.write(build_tag('apple', 'one.rb'), out)
        fmt.write(build_tag('blueberry', 'two.rb'), out)
        fmt.write(build_tag('cranberry', 'three.rb'), out)
        fmt.write(build_tag('date', 'four.rb'), out)
      end

      fmt = RipperTags::VimAppendFormatter.new(fmt)
      fmt.with_output do |out|
        fmt.write(build_tag('donut', 'four.rb'), out)
        fmt.write(build_tag('bagel', 'two.rb'), out)
      end

      assert_equal <<EOF, File.read(file.path)
!_TAG_FILE_FORMAT\t2\t/extended format; --format=1 will not append ;\" to lines/
!_TAG_FILE_SORTED\t1\t/0=unsorted, 1=sorted, 2=foldcase/
apple\tone.rb\t/^def apple$/;\"\tf
bagel\ttwo.rb\t/^def bagel$/;\"\tf
cranberry\tthree.rb\t/^def cranberry$/;\"\tf
donut\tfour.rb\t/^def donut$/;\"\tf
EOF
    ensure
      file.unlink
    end
  end

  def test_emacs_append
    file = Tempfile.new('ripper-tags')
    begin
      options = OpenStruct.new(:tag_file_name => file.path)
      fmt = RipperTags::EmacsFormatter.new(options)
      fmt.with_output do |out|
        fmt.write(build_tag('apple', 'one.rb'), out)
        fmt.write(build_tag('blueberry', 'two.rb'), out)
        fmt.write(build_tag('cranberry', 'three.rb'), out)
        fmt.write(build_tag('date', 'four.rb'), out)
      end

      fmt = RipperTags::EmacsAppendFormatter.new(fmt)
      fmt.with_output do |out|
        fmt.write(build_tag('donut', 'four.rb'), out)
        fmt.write(build_tag('bagel', 'two.rb'), out)
      end

      assert_equal <<EOF, File.read(file.path)
\f\nfour.rb,20
def donut\u007Fdonut\u00011,0
\f\ntwo.rb,20
def bagel\u007Fbagel\u00011,0
\f\none.rb,20
def apple\u007Fapple\u00011,0
\f\nthree.rb,28
def cranberry\u007Fcranberry\u00011,0
EOF
    ensure
      file.unlink
    end
  end
end
