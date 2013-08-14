require 'test/unit'
require 'stringio'
require 'ripper-tags'

class CliTest < Test::Unit::TestCase
  def process_args(argv)
    RipperTags.process_args(argv, lambda {|o| o})
  end

  def test_empty_args
    err = assert_raise(SystemExit) do
      with_program_name('ripper-tags') do
        capture_stderr do
          RipperTags.process_args([])
        end
      end
    end
    assert_equal "Usage: ripper-tags [options] FILES...", err.message
  end

  def test_invalid_option
    err = assert_raise(OptionParser::InvalidOption) do
      RipperTags.process_args(%[--moo])
    end
    assert_equal "invalid option: --moo", err.message
  end

  def test_recurse_defaults_to_current_dir
    options = process_args(%w[-R])
    assert_equal true, options.recursive
    assert_equal %w[.], options.files
  end

  def with_program_name(name)
    old_name = $0
    $0 = name
    begin
      yield
    ensure
      $0 = old_name
    end
  end

  def capture_stderr
    old_stderr = $stderr
    $stderr = StringIO.new
    begin
      yield
    ensure
      $stderr = old_stderr
    end
  end
end
