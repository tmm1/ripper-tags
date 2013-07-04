require 'pp'
require 'optparse'
require 'ostruct'
require 'ripper'
require 'ripper_tags/tag_ripper'
require 'ripper-tags/data_reader'
require 'ripper-tags/default_formatter'
require 'ripper-tags/emacs_formatter'
require 'ripper-tags/vim_formatter'
require 'ripper-tags/json_formatter'
require 'yajl'

options = OpenStruct.new(
  json: false,
  debug: false,
  vim: false,
  emacs: false,
  tag_file_name: "./tags",
  verbose: false,
  files: %w[.],
  recursive: false,
  all_files: false
)

all_tags = []

opt_parse = OptionParser.new do |opts|
  opts.banner = "Usage: ripper-tags [options] (file/directory)"
  opts.separator ""
  opts.on("-e", "--emacs", "Output emacs format to tags file") do
    options.emacs = true
  end
  opts.on("-f", "--tag-file FILE", "Filename to output tags to, default #{options.tag_file_name}") do |fname|
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
  opts.on_tail("-v", "--verbose", "Output parse tree verbosely") do
    options.verbose = options.debug
  end
  opts.on_tail("-h", "--help", "Show this message") do
    $stderr.puts opts
    exit
  end
end
opt_parse.parse!(ARGV)

if ARGV.size > 0
  options.files = ARGV
end

tags = TagRipper::DataReader.new(options).read.flatten


formatter = if options.vim
              TagRipper::VimFormatter
            elsif options.emacs
              TagRipper::EmacsFormatter
            elsif options.json
              TagRipper::JSONFormatter
            else
              TagRipper::DefaultFormatter
            end

if tags && !tags.empty?
  File.open(options.tag_file_name, "w+") do |tag_file|
    tag_file.print(formatter.new(tags).build)
  end
end
