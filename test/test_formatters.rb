require 'test/unit'
require 'stringio'
require 'ostruct'
require 'set'
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

  def test_custom
    default = formatter_for(:format => 'custom', :tag_file_name => '-')

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
    1     class   A::B < C
    2       def   A::B#imethod
    3       def   A::B.smethod
    OUT
  end

  def test_vim
    vim = formatter_for(:format => 'vim')
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

  def test_vim_with_language_field
    vim = formatter_for(:format => 'vim', :fields => %w(l).to_set)
    assert_equal %{M\t./script.rb\t/^module M$/;"\tm\tclass:A.B\tlanguage:Ruby}, vim.format(build_tag(
      :kind => 'module', :name => 'M',
      :pattern => "module M",
      :class => 'A::B'
    ))
  end

  def test_vim_with_line_numbers
    vim = formatter_for(:format => 'vim', :fields => %w(n).to_set)
    assert_equal %{C\t./script.rb\t/^class C < D$/;"\tc\tline:1}, vim.format(build_tag(
      :kind => 'class', :name => 'C',
      :pattern => "class C < D"
    ))
    assert_equal %{C\t./script.rb\t/^class C < D$/;"\tc\tline:42}, vim.format(build_tag(
      :kind => 'class', :name => 'C',
      :pattern => "class C < D",
      :line => 42
    ))
    assert_equal %{C\t./script.rb\t/^class C < D$/;"\tc\tline:105499}, vim.format(build_tag(
      :kind => 'class', :name => 'C',
      :pattern => "class C < D",
      :line => 105499
    ))
  end

  def test_vim_with_excmd_number
    vim = formatter_for(:format => 'vim', :excmd => "number")
    assert_equal %{C\t./script.rb\t1;"\tc}, vim.format(build_tag(
      :kind => 'class', :name => 'C',
      :pattern => "class C < D"
    ))
    assert_equal %{C\t./script.rb\t42;"\tc}, vim.format(build_tag(
      :kind => 'class', :name => 'C',
      :pattern => "class C < D",
      :line => 42
    ))
    assert_equal %{C\t./script.rb\t105499;"\tc}, vim.format(build_tag(
      :kind => 'class', :name => 'C',
      :pattern => "class C < D",
      :line => 105499
    ))
  end

  def test_vim_with_excmd_combined
    vim = formatter_for(:format => 'vim', :excmd => 'combined')
    assert_equal %{C\t./script.rb\t41;/^class C < D$/;"\tc}, vim.format(build_tag(
      :kind => 'class', :name => 'C',
      :pattern => "class C < D",
      :line => 42
    ))
    assert_equal %{C\t./script.rb\t105498;/^class C < D$/;"\tc}, vim.format(build_tag(
      :kind => 'class', :name => 'C',
      :pattern => "class C < D",
      :line => 105499
    ))
  end

  def test_vim_with_fully_qualified
    vim = formatter_for(:format => 'vim', :extra_flags => %w[q].to_set, :tag_file_name => '-')

    output = capture_stdout do
      vim.with_output do |out|
        vim.write build_tag(
          :kind => 'class', :name => 'C', :full_name => 'A::B::C',
          :pattern => "class C < D",
          :class => 'A::B', :inherits => 'D'
        ), out
      end
    end

    assert_equal <<-TAGS, output
!_TAG_FILE_FORMAT\t2\t/extended format; --format=1 will not append ;" to lines/
!_TAG_FILE_SORTED\t1\t/0=unsorted, 1=sorted, 2=foldcase/
A::B::C\t./script.rb\t/^class C < D$/;"\tc\tinherits:D
C\t./script.rb\t/^class C < D$/;"\tc\tclass:A.B\tinherits:D
TAGS
  end

  def test_emacs
    emacs = formatter_for(:format => 'emacs')
    assert_equal %{  class C < D\x7FC\x015,0}, emacs.format(build_tag(
      :kind => 'class', :name => 'C',
      :pattern => "  class C < D", :line => 5,
      :class => 'A::B', :inherits => 'D'
    ))
  end

  def test_emacs_with_fully_qualified
    emacs = formatter_for(:format => 'emacs', :extra_flags => %w[q].to_set, :tag_file_name => '-')

    output = capture_stdout do
      emacs.with_output do |out|
        emacs.write build_tag(
          :kind => 'class', :name => 'C', :full_name => 'A::B::C',
          :pattern => "class C < D",
          :class => 'A::B', :inherits => 'D'
        ), out
      end
    end

    assert_equal <<-TAGS, output
\x0C
./script.rb,42
class C < D\x7FC\x011,0
class C < D\x7FA::B::C\x011,0
TAGS
  end

  def test_emacs_file_section_headers
    emacs = formatter_for(:format => 'emacs', :tag_file_name => '-')

    tags = []
    tags << build_tag(:line => 1, :path => 'path/to/source.rb', :name => 'imethod', :pattern => 'def imethod')
    tags << build_tag(:line => 2, :path => 'path/to/source.rb', :name => 'smethod', :pattern => 'def self.smethod')
    tags << build_tag(:line => 3, :path => 'path/to/another.rb', :name => 'imethod', :pattern => 'def imethod')

    output = capture_stdout do
      emacs.with_output do |out|
        tags.each { |tag| emacs.write(tag, out) }
      end
    end

    assert_equal <<-OUT, output
\x0C
path/to/source.rb,53
def imethod\x7Fimethod\x011,0
def self.smethod\x7Fsmethod\x012,0
\x0C
path/to/another.rb,24
def imethod\x7Fimethod\x013,0
    OUT
  end

  def test_relative
    formatter = formatter_for(:format => 'custom', :tag_file_name => '.git/tags', :tag_relative => true)
    tag = build_tag(:path => 'path/to/script.rb')
    assert_equal '../path/to/script.rb', formatter.relative_path(tag)
  end

  def test_relative_with_absolute_tags_file_path
    tag_file_name = File.join(Dir.pwd,'.git/tags')
    formatter = formatter_for(:format => 'custom', :tag_file_name => tag_file_name, :tag_relative => true)
    tag = build_tag(:path => 'path/to/script.rb')
    assert_equal '../path/to/script.rb', formatter.relative_path(tag)
  end

  def test_relative_with_common_prefix
    tag_file_name = File.join(Dir.pwd,'path/tags')
    formatter = formatter_for(:format => 'custom', :tag_file_name => tag_file_name, :tag_relative => true)
    tag = build_tag(:path => 'path/to/script.rb')
    assert_equal 'to/script.rb', formatter.relative_path(tag)
  end

  def test_relative_with_absolute_source_path
    formatter = formatter_for(:format => 'custom', :tag_file_name => '/tmp/tags', :tag_relative => true)
    tag = build_tag(:path => '/path/to/script.rb')
    assert_equal '/path/to/script.rb', formatter.relative_path(tag)
  end

  def test_relative_always_with_absolute_source_path
    formatter = formatter_for(:format => 'custom', :tag_file_name => '/tmp/tags', :tag_relative => 'always')
    tag = build_tag(:path => '/path/to/script.rb')
    assert_equal '../path/to/script.rb', formatter.relative_path(tag)
  end

  def test_relative_never_with_relative_source_path
    formatter = formatter_for(:format => 'custom', :tag_file_name => 'tags', :tag_relative => 'never')
    tag = build_tag(:path => 'path/to/script.rb')
    assert_equal "#{Dir.pwd}/path/to/script.rb", formatter.relative_path(tag)
  end

  def test_no_relative
    formatter = formatter_for(:format => 'custom', :tag_file_name => '.git/tags')
    tag = build_tag(:path => 'path/to/script.rb')
    assert_equal 'path/to/script.rb', formatter.relative_path(tag)
  end

  def test_json_format
    json = formatter_for(:format => 'json', :tag_file_name => '-')
    tags = []
    tags << build_tag(:name => 'A')
    tags << build_tag(:name => 'B')

    expected = [
      {"kind"=>"class", "line"=>1, "path"=>"./script.rb", "access"=>"public", "name"=>"A"},
      {"kind"=>"class", "line"=>1, "path"=>"./script.rb", "access"=>"public", "name"=>"B"}
    ]

    output = capture_stdout do
      json.with_output do |out|
        tags.each { |tag| json.write(tag, out) }
      end
    end

    assert_equal expected, JSON.load(output)
  end

  def test_json_stream_format
    json = formatter_for(:format => 'json', :extra_flags => %w[s].to_set, :tag_file_name => '-')
    tags = []
    tags << build_tag(:name => 'A')
    tags << build_tag(:name => 'B')

    expected = [
      {"kind"=>"class", "line"=>1, "path"=>"./script.rb", "access"=>"public", "name"=>"A"},
      {"kind"=>"class", "line"=>1, "path"=>"./script.rb", "access"=>"public", "name"=>"B"}
    ]

    output = capture_stdout do
      json.with_output do |out|
        tags.each { |tag| json.write(tag, out) }
      end
    end

    lines = output.split("\n")
    assert_equal 2, lines.length
    assert_equal expected[0], JSON.load(lines[0])
    assert_equal expected[1], JSON.load(lines[1])
  end

  def capture_stdout
    old_stdout, $stdout = $stdout, StringIO.new
    begin
      yield
      $stdout.string
    ensure
      $stdout = old_stdout
    end
  end
end
