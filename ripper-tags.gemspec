def version_from_source(file)
  File.open(File.expand_path("../#{file}", __FILE__)) do |source|
    source.each { |line| return $1 if line =~ /\bversion\b.+"(.+?)"/i }
  end
end

Gem::Specification.new do |s|
  s.name = 'ripper-tags'
  s.version = version_from_source('lib/ripper-tags.rb')

  s.summary = 'ctags generator for ruby code'
  s.description = 'fast, accurate ctags generator for ruby source code using Ripper'

  s.homepage = 'http://github.com/tmm1/ripper-tags'
  s.has_rdoc = false

  s.authors = ['Aman Gupta']
  s.email = ['aman@tmm1.net']

  s.add_dependency 'yajl-ruby'

  s.require_paths = ['lib']
  s.bindir = 'bin'
  s.executables << 'ripper-tags'

  s.license = 'MIT'

  s.files = `git ls-files -z -- README* LICENSE* bin lib`.split("\0")
end
