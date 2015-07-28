require 'test/unit'
require 'stringio'
require 'set'
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

  def test_exclude_add_patterns
    options = process_args(%w[-R --exclude vendor --exclude=bundle/*])
    assert_equal %w[.git vendor bundle/*], options.exclude
  end

  def test_exclude_clear
    options = process_args(%w[-R --exclude=])
    assert_equal [], options.exclude
  end

  def test_TAGS_triggers_to_emacs_format
    options = process_args(%w[-f ./TAGS script.rb])
    assert_equal './TAGS', options.tag_file_name
    assert_equal 'emacs', options.format
  end

  def test_tag_relative_off_by_default
    options = process_args(%w[ -R ])
    assert_equal false, options.tag_relative
  end

  def test_tag_relative_on
    options = process_args(%w[--tag-relative hello.rb])
    assert_equal true, options.tag_relative
    assert_equal %w[hello.rb], options.files
  end

  def test_tag_relative_explicit_yes
    options = process_args(%w[-R --tag-relative=yes])
    assert_equal true, options.tag_relative
  end

  def test_tag_relative_explicit_no
    options = process_args(%w[-R --tag-relative=no])
    assert_equal false, options.tag_relative
  end

  def test_tag_relative_on_for_emacs
    options = process_args(%w[ -R -e ])
    assert_equal true, options.tag_relative
  end

  def test_no_extra_flags_by_default
    options = process_args(%w[ -R ])
    assert options.extra_flags.empty?
  end

  def test_extra_flags
    options = process_args(%w[ -R --extra=ab ])
    assert_equal %w[a b].to_set, options.extra_flags
  end

  def test_extra_flag_modifiers
    options = process_args(%w[ -R --extra=xy --extra=abc --extra=-ac --extra=+de ])
    assert_equal %w[b d e].to_set, options.extra_flags
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
