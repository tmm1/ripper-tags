require 'tempfile'
require 'test/unit'
require 'ostruct'
require 'ripper-tags/data_reader'

class DataReaderTest < Test::Unit::TestCase
  FIXTURES = File.expand_path('../fixtures', __FILE__)

  def fixture(path)
    File.join(FIXTURES, path)
  end

  def find_files(*files)
    opts = files.last.is_a?(Hash) ? files.pop : {}
    options = OpenStruct.new({:files => files, :recursive => true}.merge(opts))
    finder = RipperTags::FileFinder.new(options)
    finder.each_file.to_a
  end

  def test_encoding
    with_default_encoding('utf-8') do
      options = OpenStruct.new(:files => [fixture('encoding.rb')])
      reader = RipperTags::DataReader.new(options)
      tags = reader.each_tag.to_a
      assert_equal 'Object#encoding', tags[0][:full_name]
    end
  end

  def test_encoding_non_utf8_default
    with_default_encoding('us-ascii') do
      options = OpenStruct.new(:files => [fixture('encoding.rb')])
      reader = RipperTags::DataReader.new(options)
      tags = reader.each_tag.to_a
      assert_equal 'Object#encoding', tags[0][:full_name]
    end
  end

  def test_file_finder
    files = in_fixtures { find_files('.', :exclude => %w[_git]) }
    expected = %w[
      encoding.rb
      very/deep/script.rb
      very/inter.rb
    ]
    assert_equal expected, files.sort
  end

  def test_file_finder_no_exclude
    files = in_fixtures { find_files('.', :exclude => []) }
    assert files.include?('_git/hooks/hook.rb'), files.inspect
  end

  def test_file_finder_exclude
    files = in_fixtures { find_files('.', :exclude => %w[_git very]) }
    expected = %w[ encoding.rb ]
    assert_equal expected, files.sort
  end

  def test_file_finder_exclude_glob
    files = in_fixtures { find_files('.', :exclude => %w[_git very/deep/*]) }
    expected = %w[
      encoding.rb
      very/inter.rb
    ]
    assert_equal expected, files.sort
  end

  def test_file_finder_cleanpath
    files = in_fixtures { find_files('./very/../encoding.rb', 'very//inter.rb') }
    expected = %w[
      encoding.rb
      very/inter.rb
    ]
    assert_equal expected, files.sort
  end

  def in_fixtures
    Dir.chdir(FIXTURES) { yield }
  end

  def with_default_encoding(name)
    if defined?(Encoding)
      old_default = Encoding.default_external
      ignore_warnings { Encoding.default_external = name }
      begin
        yield
      ensure
        ignore_warnings { Encoding.default_external = old_default }
      end
    else
      yield
    end
  end

  def test_input_file
    test_inputs = %w[encoding.rb very/inter.rb]
    with_tempfile do |tempfile|
      test_inputs.each { |line| tempfile.puts(line) }
      tempfile.close
      in_fixtures do
        assert_equal test_inputs, find_files(:input_file => tempfile.path)
      end
    end
  end

  def test_input_file_as_stdin
    test_inputs = %w[encoding.rb very/inter.rb]
    fake_stdin = StringIO.new(test_inputs.join("\n"))
    orig_stdin, $stdin = $stdin, fake_stdin
    begin
      in_fixtures do
        assert_equal test_inputs, find_files(:input_file => "-")
      end
    ensure
      $stdin = orig_stdin
    end
  end

  def with_tempfile
    file = Tempfile.new("test-ripper-tags")
    begin
      yield file
    ensure
      file.close unless file.closed?
      File.delete(file.path)
    end
  end

  def ignore_warnings
    old_verbose = $-w
    $-w = false
    begin
      yield
    ensure
      $-w = old_verbose
    end
  end
end
