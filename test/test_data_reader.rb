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
    finder.each_file.map {|f| f.sub("#{FIXTURES}/", '') }
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
    files = find_files(fixture(''), :exclude => %w[_git])
    expected = %w[
      encoding.rb
      very/deep/script.rb
      very/inter.rb
    ]
    assert_equal expected, files
  end

  def test_file_finder_no_exclude
    files = find_files(fixture(''), :exclude => [])
    assert files.include?('_git/hooks/hook.rb'), files.inspect
  end

  def test_file_finder_exclude
    files = find_files(fixture(''), :exclude => %w[_git very])
    expected = %w[ encoding.rb ]
    assert_equal expected, files
  end

  def test_file_finder_exclude_glob
    files = find_files(fixture(''), :exclude => %w[_git very/deep/*])
    expected = %w[
      encoding.rb
      very/inter.rb
    ]
    assert_equal expected, files
  end

  def with_default_encoding(name)
    if defined?(Encoding)
      old_default = Encoding.default_external
      Encoding.default_external = name
      begin
        yield
      ensure
        Encoding.default_external = old_default
      end
    else
      yield
    end
  end
end
