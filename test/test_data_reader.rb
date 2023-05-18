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
      erb_template.rb
      very/deep/script.rb
      very/inter.rb
    ]
    assert_equal expected, files.sort
  end

  def test_file_finder_no_exclude
    files = in_fixtures { find_files('.', :exclude => []) }
    assert_include files, '_git/hooks/hook.rb'
  end

  def test_file_finder_exclude
    files = in_fixtures { find_files('.', :exclude => %w[_git very]) }
    expected = %w[ encoding.rb erb_template.rb ]
    assert_equal expected, files.sort
  end

  def test_file_finder_exclude_glob
    files = in_fixtures { find_files('.', :exclude => %w[_git very/deep/*]) }
    expected = %w[
      encoding.rb
      erb_template.rb
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

  def test_file_finder_all
    files = in_fixtures { find_files('.', :all_files => true) }
    assert_include files, 'non-script.txt'
    assert_include files, 'very/deep/non-ruby.py'
  end

  def test_file_finder_always_include_exact_match
    files = in_fixtures { find_files('non-script.txt', 'very', :all_files => false) }
    expected = %w[
      non-script.txt
      very/deep/script.rb
      very/inter.rb
    ]
    assert_equal expected, files.sort
  end

  def test_file_finder_exact_match_respects_exclude
    files = in_fixtures { find_files('encoding.rb', :exclude => ['encoding']) }
    assert_equal [], files
  end

  def test_file_finder_no_recursive
    files = in_fixtures { find_files('encoding.rb', 'very', :recursive => false) }
    expected = %w[
      encoding.rb
    ]
    assert_equal expected, files.sort
  end

  def test_unreadable_directory
    in_fixtures do
      Dir.mkdir('unreadable', 0300)
      File.write('unreadable/will_be_ignored.rb', 'def foo;end')

      begin
        files = nil
        stderr = capture_stderr do
          files = find_files('.', verbose: false)
        end
        assert_not_include files, 'unreadable/will_be_ignored.rb'
        assert_equal stderr, "#{File.basename($0)}: skipping unreadable directory `unreadable'\n"
      ensure
        File.delete('unreadable/will_be_ignored.rb')
        Dir.rmdir('unreadable')
      end
    end
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

  def test_survive_errors
    # should not raise if we hit an error when processing a file
    options = OpenStruct.new(:files => [fixture('encoding.rb'), fixture('erb_template.rb')])
    reader = RipperTags::DataReader.new(options)
    stderr = capture_stderr do
      reader.each_tag.to_a
    end
    if RUBY_VERSION.to_f >= 2.3 && RUBY_VERSION.to_f < 3.2
      assert_include(stderr, "ArgumentError parsing `#{fixture('erb_template.rb')}'")
    else
      assert_equal("", stderr)
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

  def capture_stderr
    old_stderr, $stderr = $stderr, StringIO.new
    begin
      yield
      $stderr.string
    ensure
      $stderr = old_stderr
    end
  end
end
