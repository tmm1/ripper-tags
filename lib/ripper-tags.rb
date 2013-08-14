require 'optparse'
require 'ostruct'
require 'ripper-tags/parser'
require 'ripper-tags/data_reader'
require 'ripper-tags/default_formatter'
require 'ripper-tags/emacs_formatter'
require 'ripper-tags/vim_formatter'
require 'ripper-tags/json_formatter'

module RipperTags
  def self.default_options
    OpenStruct.new \
      json: false,
      debug: false,
      vim: false,
      emacs: false,
      tag_file_name: "./tags",
      verbose_debug: false,
      verbose: false,
      force: false,
      files: %w[.],
      recursive: false,
      all_files: false
  end

  def self.option_parser(options)
    OptionParser.new do |opts|
      opts.banner = "Usage: #{opts.program_name} [options] FILES..."

      opts.separator ""

      opts.on("-e", "--emacs", "Output emacs format to tags file") do
        options.emacs = true
      end
      opts.on("-f", "--tag-file (FILE|-)", "Filename to output tags to, default #{options.tag_file_name}",
             '"-" outputs to standard output') do |fname|
        options.tag_file_name = fname
      end
      opts.on("-J", "--json", "Output nodes as json") do
        options.json = true
      end
      opts.on("-A", "--all-files", "Parse all files as ruby files") do
        options.all_files = true
      end
      opts.on("-R", "--recursive", "Descend recursively into given directory") do
        options.recursive = true
      end
      opts.on("-V", "--vim", "Output vim optimized format to tags file") do
        options.vim = true
      end

      opts.separator " "

      opts.on_tail("-d", "--debug", "Output parse tree") do
        options.debug = true
      end
      opts.on_tail("--debug-verbose", "Output parse tree verbosely") do
        options.verbose_debug = true
      end
      opts.on_tail("-v", "--verbose", "Print additional information on stderr") do
        options.verbose = true
      end
      opts.on_tail("--force", "Skip files with parsing errors") do
        options.force = true
      end
      opts.on_tail("-h", "--help", "Show this message") do
        $stderr.puts opts
        exit
      end

      yield(opts, options) if block_given?
    end
  end

  def self.process_args(argv, run = method(:run))
    option_parser(default_options) do |optparse, options|
      file_list = optparse.parse(argv)
      if !file_list.empty? then options.files = file_list
      elsif !options.recursive then abort(optparse.banner)
      end
      return run.call(options)
    end
  end

  def self.formatter_for(options)
    options.formatter ||
    if options.vim
      RipperTags::VimFormatter
    elsif options.emacs
      RipperTags::EmacsFormatter
    elsif options.json
      RipperTags::JSONFormatter
    else
      RipperTags::DefaultFormatter
    end.new(options)
  end

  def self.run(options)
    tags = RipperTags::DataReader.new(options).read.flatten
    formatter = formatter_for(options)
    formatter.with_output do |out|
      tags.each do |tag|
        formatter.write(tag, out)
      end
    end
  end
end
