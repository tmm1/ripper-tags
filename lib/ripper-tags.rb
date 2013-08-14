require 'optparse'
require 'ostruct'
require 'ripper-tags/parser'
require 'ripper-tags/data_reader'
require 'ripper-tags/default_formatter'
require 'ripper-tags/emacs_formatter'
require 'ripper-tags/vim_formatter'
require 'ripper-tags/json_formatter'

options = OpenStruct.new(
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
)

all_tags = []

opt_parse = OptionParser.new do |opts|
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
end
opt_parse.parse!(ARGV)

if ARGV.size > 0
  options.files = ARGV
else
  $stderr.puts opt_parse
  exit
end

tags = RipperTags::DataReader.new(options).read.flatten


formatter = if options.vim
              RipperTags::VimFormatter
            elsif options.emacs
              RipperTags::EmacsFormatter
            elsif options.json
              RipperTags::JSONFormatter
            else
              RipperTags::DefaultFormatter
            end

if tags && !tags.empty?
  if options.tag_file_name == '-'
    $stdout.print(formatter.new(tags).build)
  else
    File.open(options.tag_file_name, "w+") do |tag_file|
      tag_file.print(formatter.new(tags).build)
    end
  end
end
