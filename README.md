## ripper-tags

fast, accurate ctags generator for ruby source code using Ripper

### usage (command-line)

Typical usage:

```
ripper-tags -R --exclude=vendor
```

This parses all `*.rb` files in the current project, excluding ones in `vendor/`
directory, and saves tags in Vim format to a file named `./tags`.

To see all available options:

```
ripper-tags --help
```

### usage (api)

``` ruby
require 'ripper-tags/parser'
tags = RipperTags::Parser.extract("def abc() end", "mycode.rb")
```
