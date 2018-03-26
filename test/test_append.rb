require 'test/unit'
require 'stringio'
require 'ostruct'
require 'set'
require 'ripper-tags'

class VimAppendTest < Test::Unit::TestCase
  def test_vim_append
    Tempfile.open("tags") do |tmp|
      tmp.write(vim_header)
      tmp.write(%(SomeComponent\t./src/components/some_component/index.jsx\t/^class SomeComponent extends React.Component {$/;"\tC\n))
      tmp.write(%(X\t./xmarksthespot.rb\t/^X = 42$/;"\tC\n))
      tmp.rewind

      vim = appending_vim_formatter(tmp.path)
      vim.with_output do |out|
        vim.write build_tag(
          :kind => 'class', :name => 'C', full_name: 'A::B::C',
          :pattern => "class C < D",
          :class => 'A::B', :inherits => 'D'), out
      end
      tmp.rewind
      assert_equal <<-TAGS, tmp.read
!_TAG_FILE_FORMAT	2	/extended format; --format=1 will not append ;" to lines/
!_TAG_FILE_SORTED	1	/0=unsorted, 1=sorted, 2=foldcase/
A::B::C	./script.rb	/^class C < D$/;"	c	inherits:D
C	./script.rb	/^class C < D$/;"	c	class:A.B	inherits:D
SomeComponent	./src/components/some_component/index.jsx	/^class SomeComponent extends React.Component {$/;"	C
X	./xmarksthespot.rb	/^X = 42$/;"	C
TAGS
    end
  end

  def test_vim_append_duplicates
    Tempfile.open("tags") do |tmp|
      tmp.write(vim_header)
      tmp.write(%(C\t./script.rb\t/^class C < D$/;"\tc\tclass:A.B\tinherits:D\n))
      tmp.write(%(X\t./xmarksthespot.rb\t/^X = 42$/;"\tC\n))
      tmp.rewind

      vim = appending_vim_formatter(tmp.path)
      vim.with_output do |out|
          vim.write build_tag(
            :kind => 'class', :name => 'C', full_name: 'A::B::C',
            :pattern => "class C < D",
            :class => 'A::B', :inherits => 'D'), out
        end
      tmp.rewind
      assert_equal <<-TAGS, tmp.read
!_TAG_FILE_FORMAT	2	/extended format; --format=1 will not append ;" to lines/
!_TAG_FILE_SORTED	1	/0=unsorted, 1=sorted, 2=foldcase/
A::B::C	./script.rb	/^class C < D$/;"	c	inherits:D
C	./script.rb	/^class C < D$/;"	c	class:A.B	inherits:D
X	./xmarksthespot.rb	/^X = 42$/;"	C
TAGS
    end
  end

  def vim_header
    %(!_TAG_FILE_FORMAT\t2\t/extended format; --format=1 will not append ;" to lines/\n) +
    %(!_TAG_FILE_SORTED\t1\t/0=unsorted, 1=sorted, 2=foldcase/\n)
  end

  def build_tag(attrs = {})
    { :kind => 'class',
      :line => 1,
      :path => './script.rb',
      :access => 'public',
    }.merge(attrs)
  end

  def appending_vim_formatter(path)
    options = OpenStruct.new(:format => 'vim', :extra_flags => %w[q].to_set, :tag_file_name => path, :append => true)
    RipperTags.formatter_for(options)
  end
end

module EmacsUtils
  def fixture_tags
    [{ line: "4", name: "X", path: "x.rb", pattern: "class X", class: "" },
     { line: "5", name: "foo", path: "x.rb", pattern: "    def foo", class: "" },
     { line: "12", name: "SomeComponent", path: "y.js", pattern: "class SomeComponent extends React.Component {", class: "" },
     { line: "14", name: "componentWillMount", path: "y.js", pattern: "  componentWillMount() {", class: "" }]
  end

  def fixture_lines
    # Nonzero byte offsets and wrong section sizes. Both are ignored/recalculated later
    ["\f",
     "x.rb,1234",
     "class X\x7FX\x014,12",
     "    def foo\x7Ffoo\x015,999",
     "\f",
     "y.js,9999",
     "class SomeComponent extends React.Component {\x7FSomeComponent\x0112,133",
     "  componentWillMount() {\x7FcomponentWillMount\x0114,19"]
  end
end

class EmacsAppendTest < Test::Unit::TestCase
  include EmacsUtils

  def appending_emacs_formatter(path)
    options = OpenStruct.new(:format => 'emacs', :tag_file_name => path, :append => true)
    RipperTags.formatter_for(options)
  end

  def test_emacs_append
    Tempfile.open("TAGS") do |tmp|
      tmp.write(fixture_lines.join("\n"))
      tmp.rewind

      subject = appending_emacs_formatter(tmp.path)
      subject.with_output do |out|
        subject.write build_tag(
          :kind => 'class', :name => 'C', full_name: 'A::B::C',
          :pattern => "class C < D",
          :class => 'A::B', :inherits => 'D'), out
      end
      tmp.rewind

      # Section sizes are rewritten, and tag byte offsets are always zero
      assert_equal([
          "\f", "./script.rb,18",
          "class C < D\x7FC\x011,0",
          "\f", "x.rb,34",
          "class X\x7FX\x014,0",
          "    def foo\x7Ffoo\x015,0",
          "\f", "y.js,114",
          "class SomeComponent extends React.Component {\x7FSomeComponent\x0112,0",
          "  componentWillMount() {\x7FcomponentWillMount\x0114,0",
          ""
        ].join("\n"),
        tmp.read)
    end
  end

  def test_emacs_append_duplicates
    Tempfile.open("TAGS") do |tmp|
      tmp.write(fixture_lines.join("\n"))
      tmp.rewind

      subject = appending_emacs_formatter(tmp.path)
      subject.with_output do |out|
        subject.write build_tag(
          kind: 'class', name: 'X',
          pattern: "class X", path: "x.rb", line: 3 # Different line 
          ), out
      end
      tmp.rewind

      # Section sizes are rewritten, and tag byte offsets are always zero
      assert_equal([
          "\f", "x.rb,34",
          "class X\x7FX\x013,0",
          "    def foo\x7Ffoo\x015,0",
          "\f", "y.js,114",
          "class SomeComponent extends React.Component {\x7FSomeComponent\x0112,0",
          "  componentWillMount() {\x7FcomponentWillMount\x0114,0",
          ""
        ].join("\n"),
        tmp.read)
    end

  end

  def build_tag(attrs = {})
    { :kind => 'class',
      :line => 1,
      :path => './script.rb',
      :access => 'public',
    }.merge(attrs)
  end
end

class EmacsTagsProcessorTest < Test::Unit::TestCase
  include EmacsUtils

  def processor(options = {})
    ::RipperTags::EmacsTagsProcessor.new(options[:path]).tap do |obj|
      obj.instance_variable_set :@tags, options.fetch(:tags, [])
    end
  end

  def test_read_sections
    Tempfile.open("tags") do |tmp|
      tmp.write(fixture_lines.join("\n"))
      tmp.rewind

      subject = processor(path: tmp.path)
      subject.read

      assert_equal(fixture_tags, subject.instance_variable_get(:@tags))
    end
  end

  def test_save_section_emits_tags
    out = []
    subject = processor(tags: fixture_tags)

    subject.save_section("x.rb") { |tag| out.push(tag) }
    assert_equal(
      [{ line: "4", name: "X", path: "x.rb", pattern: "class X", class: "" },
       { line: "5", name: "foo", path: "x.rb", pattern: "    def foo", class: "" }],
    out)
  end

  def test_save_rest_emits_sections
    out = []
    subject = processor(tags: fixture_tags)
    subject.save_rest { |filename| out.push(filename) }
    assert_equal(%w(x.rb y.js), out) 
  end

  def test_save_rest_omits_empty
    out = []
    subject = processor(tags: fixture_tags)
    subject.remove(path: "x.rb", name: "X")
    subject.remove(path: "x.rb", name: "foo")
    subject.save_rest { |filename| out.push(filename) }
    assert_equal(%w(y.js), out)
  end

end
