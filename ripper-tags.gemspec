version_from_source = lambda do |file|
  File.open(File.expand_path("../#{file}", __FILE__)) do |source|
    source.detect { |line| line =~ /\bversion\b.+"(.+?)"/i }
  end
  $1
end

Gem::Specification.new do |s|
  s.name = 'ripper-tags'
  s.version = version_from_source.call('lib/ripper-tags.rb')

  s.summary = 'ctags generator for ruby code'
  s.description = 'fast, accurate ctags generator for ruby source code using Ripper'
  s.homepage = 'https://github.com/tmm1/ripper-tags'

  s.authors = ['Mislav Marohnić', 'Aman Gupta']
  s.email = ['mislav.marohnic@gmail.com', 'aman@tmm1.net']

  s.require_paths = ['lib']
  s.bindir = 'bin'
  s.executables << 'ripper-tags'
  s.required_ruby_version = '>= 1.9'

  s.license = 'MIT'

  s.files = `git ls-files -z -- README* LICENSE* bin lib`.split("\0")
end
