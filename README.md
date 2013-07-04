## ripper-tags

fast, accurate ctags generator for ruby source code using Ripper

### usage (bin)

   Usage: ripper-tags [options] (file/directory)

    -e, --emacs                      Output emacs format to tags file
    -f, --tag-file FILE              Filename to output tags to, default ./tags
    -J, --json                       Output nodes as json
    -A, --all-files                  Parse all files as ruby files
    -R, --recursive                  Descend recursively into given directory
    -V, --vim                        Output vim optimized format to tags file

    -d, --debug                      Output parse tree
    -v, --verbose                    Output parse tree verbosely
    -h, --help                       Show this message


---

As a binary, ripper-tags will always create a file if tags are available (default is ``./tags``). This can be overridden
with the ``-f/--tag-file`` option.

Usually, you want to either add a file on the command line or use the ``-R/--recursive`` option.

### usage (api)

``` ruby
require 'tag_ripper'
tags = TagRipper.extract("def abc() end", "mycode.rb")
```
