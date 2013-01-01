Gem::Specification.new do |s|
  s.name = 'ripper-tags'
  s.version = '0.1.0'

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

  s.files = `git ls-files`.split("\n")
end
