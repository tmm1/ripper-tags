require 'optparse'
require 'ostruct'
require 'set'
require 'ripper-tags/parser'
require 'ripper-tags/data_reader'
require 'ripper-tags/default_formatter'
require 'ripper-tags/emacs_formatter'
require 'ripper-tags/emacs_append_formatter'
require 'ripper-tags/vim_formatter'
require 'ripper-tags/vim_append_formatter'
require 'ripper-tags/json_formatter'

module RipperTags
  def self.version() "0.9.1" end

  FatalError = Class.new(RuntimeError)

  def self.default_options
    OpenStruct.new \
      :format => nil,
      :formatter => nil,
      :extra_flags => Set.new,
      :tag_file_name => nil,
      :tag_file_append => false,
      :tag_relative => nil,
      :debug => false,
      :verbose_debug => false,
      :verbose => false,
      :force => false,
      :files => %w[.],
      :recursive => false,
      :exclude => %w[.git],
      :all_files => false,
      :fields => Set.new,
      :excmd => nil,
      :input_file => nil
  end

  class ForgivingOptionParser < OptionParser
    attr_accessor :ignore_unsupported_options

    def load_options_file(file)
      @argv.unshift(*File.readlines(file).flat_map { |line|
        line.strip!.match(/(=|\s)/)
        ($1 == "" || $1 == "=") ? line : line.split(/\s+/, 2)
      })
    end

    private

    def parse_in_order(argv = default_argv, *)
      exceptions = []
      @argv = argv

      loop do
        begin
          super
          break
        rescue OptionParser::InvalidOption => err
          exceptions << err
        end
      end

      if exceptions.any? && !ignore_unsupported_options
        raise exceptions.first
      end

      argv
    end
  end

  def self.option_parser(options)
    flags_string_to_set = lambda do |string, set|
      flags = string.split("")
      operation = :add
      if flags[0] == "+" || flags[0] == "-"
        operation = :delete if flags.shift == "-"
      else
        set.clear
      end
      flags.each { |f| set.send(operation, f) }
    end

    ForgivingOptionParser.new do |opts|
      opts.banner = "Usage: #{opts.program_name} [options] FILES..."
      opts.version = version

      opts.separator ""

      opts.on("-f", "--tag-file (FILE|-)", "File to write tags to (default: `./tags')",
             '"-" outputs to standard output') do |fname|
        options.tag_file_name = fname
      end
      opts.on("-a", "--append[=yes|no]", "Append tags to existing file") do |value|
        options.tag_file_append = value != "no"
      end
      opts.on("--tag-relative[=yes|no|always|never]", "Make file paths relative to the directory of the tag file") do |value|
        options.tag_relative = value || true
      end
      opts.on("-L", "--input-file=FILE", "File to read paths to process from (use `-` for stdin)") do |file|
        options.input_file = file
      end
      opts.on("-R", "--recursive", "Descend recursively into subdirectories") do
        options.recursive = true
      end
      opts.on("--recurse=[yes|no]", "Alias for --recursive") do |value|
        options.recursive = value != 'no'
      end
      opts.on("--exclude PATTERN", "Exclude a file, directory or pattern") do |pattern|
        if pattern.empty?
          options.exclude.clear
        else
          options.exclude << pattern
        end
      end
      opts.on("--excmd=(number|pattern|mixed|combined)", "Type of EX command to find tags in vim with (default: pattern)") do |excmd|
        options.excmd = excmd
      end
      opts.on("-n", "Equivalent to --excmd=number.") do
        options.excmd = "number"
      end
      opts.on("--fields=+ln", "Add extra fields to output") do |flags|
        flags_string_to_set.call(flags, options.fields)
      end
      opts.on("--all-files", "Parse all files in recursive mode (default: parse `*.rb' files)") do
        options.all_files = true
      end

      opts.separator " "

      opts.on("--format (emacs|json|custom)", "Set output format (default: vim)") do |fmt|
        options.format = fmt
      end
      opts.on("-e", "--emacs", "Output Emacs format (default if `--tag-file' is `TAGS')") do
        options.format = "emacs"
      end
      opts.on("--extra=FLAGS", "Specify extra flags for the formatter") do |flags|
        flags_string_to_set.call(flags, options.extra_flags)
      end

      opts.separator ""

      opts.on_tail("-d", "--debug", "Output parse tree") do
        options.debug = true
      end
      opts.on_tail("--debug-verbose", "Output parse tree verbosely") do
        options.verbose_debug = true
      end
      opts.on_tail("-V", "--verbose", "Print additional information on stderr") do
        options.verbose = true
      end
      opts.on_tail("--force", "Always exit with error code 0, even when parse errors occur") do
        options.force = true
      end
      opts.on_tail("--list-kinds=LANG", "Print tag kinds that this parser supports and exit") do |lang|
        if lang.downcase == "ruby"
          puts((<<-OUT).gsub(/^ +/, ''))
            c  classes
            f  methods
            m  modules
            F  singleton methods
            C  constants
            a  aliases
          OUT
          exit
        else
          $stderr.puts "Error: language %p is not supported" % lang
          exit 1
        end
      end
      opts.on_tail("--options=FILE", "Read additional options from file") do |file|
        opts.load_options_file(file)
      end
      opts.on_tail("--ignore-unsupported-options", "Don't fail when unsupported options given, just skip them") do
        opts.ignore_unsupported_options = true
      end
      opts.on_tail("-v", "--version", "Print version information") do
        puts opts.ver
        exit
      end

      yield(opts, options) if block_given?
    end
  end

  def self.process_args(argv, run = method(:run))
    option_parser(default_options) do |optparse, options|
      file_list = optparse.parse(argv)

      if !file_list.empty?
        options.files = file_list
      elsif !(options.recursive || options.input_file)
        raise OptionParser::InvalidOption, "needs either a list of files, `-L`, or `-R' flag"
      end

      options.tag_file_name ||= options.format == 'emacs' ? './TAGS' : './tags'
      options.format ||= File.basename(options.tag_file_name) == 'TAGS' ? 'emacs' : 'vim'
      options.tag_relative = options.format == "emacs" if options.tag_relative.nil?

      case options.tag_relative
      when true, false, 'yes', 'no', 'always', 'never'
      else
        raise OptionParser::InvalidOption, 'unsupported value for --tag-relative: %p' % options.tag_relative
      end

      return run.call(options)
    end
  end

  def self.formatter_for(options)
    return options.formatter unless options.formatter.nil?

    if options.tag_file_append
      case options.format
      when "vim"   then RipperTags::VimAppendFormatter.new(RipperTags::VimFormatter.new(options))
      when "emacs" then RipperTags::EmacsAppendFormatter.new(RipperTags::EmacsFormatter.new(options))
      else
        raise FatalError, "--append is only supported for vim/emacs; got #{options.format.inspect}"
      end
    else
      case options.format
      when "vim"    then RipperTags::VimFormatter.new(options)
      when "emacs"  then RipperTags::EmacsFormatter.new(options)
      when "json"   then RipperTags::JSONFormatter.new(options)
      when "custom" then RipperTags::DefaultFormatter.new(options)
      else
        raise FatalError, "unknown format: #{options.format.inspect}"
      end
    end
  end

  def self.run(options)
    reader = RipperTags::DataReader.new(options)
    formatter = formatter_for(options)
    formatter.with_output do |out|
      reader.each_tag do |tag|
        formatter.write(tag, out)
      end
    end
    if reader.error_count > 0 && !options.force && reader.error_count == reader.file_count
      exit 1
    end
  rescue FatalError => err
    $stderr.puts "%s: %s" % [
      File.basename($0),
      err.message
    ]
    exit 1
  end
end
