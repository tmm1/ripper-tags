require 'optparse'
require 'ostruct'
require 'set'
require 'ripper-tags/parser'
require 'ripper-tags/data_reader'
require 'ripper-tags/default_formatter'
require 'ripper-tags/emacs_formatter'
require 'ripper-tags/vim_formatter'
require 'ripper-tags/json_formatter'

module RipperTags
  def self.version() "0.3.5" end

  FatalError = Class.new(RuntimeError)

  def self.default_options
    OpenStruct.new \
      :format => nil,
      :extra_flags => Set.new,
      :tag_file_name => nil,
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
      :input_file => nil,
      :ignore_unsupported => false
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

    OptionParser.new do |opts|
      opts.banner = "Usage: #{opts.program_name} [options] FILES..."
      opts.version = version

      opts.separator ""

      opts.on("-f", "--tag-file (FILE|-)", "File to write tags to (default: `./tags')",
             '"-" outputs to standard output') do |fname|
        options.tag_file_name = fname
      end
      opts.on("--tag-relative[=OPTIONAL]", "Make file paths relative to the directory of the tag file") do |value|
        options.tag_relative = value != "no"
      end
      opts.on("-L", "--input-file=FILE", "File to read paths to process trom (use `-` for stdin)") do |file|
        options.input_file = file
      end
      opts.on("-R", "--recursive", "Descend recursively into subdirectories") do
        options.recursive = true
      end
      opts.on("--exclude PATTERN", "Exclude a file, directory or pattern") do |pattern|
        if pattern.empty?
          options.exclude.clear
        else
          options.exclude << pattern
        end
      end
      opts.on("--excmd=number", "Use EX number command to locate tags.") do |excmd|
        options.excmd = excmd
      end
      opts.on("-n", "Equivalent to --excmd=number.") do
        options.excmd = "number"
      end
      opts.on("--fields=+n", "Include line number information in the tag") do |flags|
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
      opts.on_tail("--force", "Skip files with parsing errors") do
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
      opts.on_tail("--ignore-unsupported-options", "Don't fail when unsupported options given, just skip them") do
        options.ignore_unsupported = true
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
      invalid_options = []
      file_list = []

      while argv.size > 0
        begin
          file_list = optparse.parse(argv)
        rescue OptionParser::InvalidOption => err
          err.args.each do |bad_option|
            argv.delete(bad_option)
            invalid_options << bad_option
          end
          retry
        else
          break
        end
      end
      
      if invalid_options.size > 0 && !options.ignore_unsupported
        raise OptionParser::InvalidOption, invalid_options.first
      end

      if !file_list.empty?
        options.files = file_list
      elsif !(options.recursive || options.input_file)
        raise OptionParser::InvalidOption, "needs either a list of files, `-L`, or `-R' flag"
      end

      options.tag_file_name ||= options.format == 'emacs' ? './TAGS' : './tags'
      options.format ||= File.basename(options.tag_file_name) == 'TAGS' ? 'emacs' : 'vim'
      options.tag_relative = options.format == "emacs" if options.tag_relative.nil?

      return run.call(options)
    end
  end

  def self.formatter_for(options)
    options.formatter ||
    case options.format
    when "vim"    then RipperTags::VimFormatter
    when "emacs"  then RipperTags::EmacsFormatter
    when "json"   then RipperTags::JSONFormatter
    when "custom" then RipperTags::DefaultFormatter
    else raise FatalError, "unknown format: #{options.format.inspect}"
    end.new(options)
  end

  def self.run(options)
    reader = RipperTags::DataReader.new(options)
    formatter = formatter_for(options)
    formatter.with_output do |out|
      reader.each_tag do |tag|
        formatter.write(tag, out)
      end
    end
  rescue FatalError => err
    $stderr.puts "%s: %s" % [
      File.basename($0),
      err.message
    ]
    exit 1
  end
end
