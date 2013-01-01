## ripper-tags

fast, accurate ctags generator for ruby source code using Ripper

### usage (bin)

```
$ ripper-tags /usr/lib/ruby/1.8/timeout.rb
   30  module   Timeout
   35   class   Timeout::Error < Interrupt
   37   class   Timeout::ExitException < Exception
   40   const   Timeout::THIS_FILE
   41   const   Timeout::CALLER_OFFSET
   52     def   Timeout#timeout
  100     def   Object#timeout
  108   const   TimeoutError

$ ripper-tags --debug /usr/lib/ruby/1.8/timeout.rb
[[:module,
  ["Timeout", 30],
  [[:class, ["Error", 35], ["Interrupt", 35], []],
   [:class, ["ExitException", 37], ["Exception", 37], []],
   [:assign, "THIS_FILE", 40],
   [:assign, "CALLER_OFFSET", 41],
   [:def, "timeout", 52]]],
 [:def, "timeout", 100],
 [:assign, "TimeoutError", 108]]

$ ripper-tags --vim /usr/lib/ruby/1.8/timeout.rb
!_TAG_FILE_FORMAT	2	/extended format; --format=1 will not append ;" to lines/
!_TAG_FILE_SORTED	1	/0=unsorted, 1=sorted, 2=foldcase/
CALLER_OFFSET	/usr/lib/ruby/1.8/timeout.rb	/^  CALLER_OFFSET = ((c = caller[0]) && THIS_FILE =~ c) ? 1 : 0$/;"	C	class:Timeout
Error	/usr/lib/ruby/1.8/timeout.rb	/^  class Error < Interrupt$/;"	c	class:Timeout	inherits:Interrupt
ExitException	/usr/lib/ruby/1.8/timeout.rb	/^  class ExitException < ::Exception # :nodoc:$/;"	c	class:Timeout	inherits:Exception
THIS_FILE	/usr/lib/ruby/1.8/timeout.rb	/^  THIS_FILE = \/\\A#{Regexp.quote(__FILE__)}:\/o$/;"	C	class:Timeout
Timeout	/usr/lib/ruby/1.8/timeout.rb	/^module Timeout$/;"	m
TimeoutError	/usr/lib/ruby/1.8/timeout.rb	/^TimeoutError = Timeout::Error # :nodoc:$/;"	C	class:
timeout	/usr/lib/ruby/1.8/timeout.rb	/^def timeout(n, e = nil, &block) # :nodoc:$/;"	f	class:Object
timeout	/usr/lib/ruby/1.8/timeout.rb	/^  def timeout(sec, klass = nil)$/;"	f	class:Timeout

$ ripper-tags --json /usr/lib/ruby/1.8/timeout.rb
{"full_name":"Timeout","name":"Timeout","kind":"module","line":30,"language":"Ruby","path":"/usr/lib/ruby/1.8/timeout.rb","pattern":"module Timeout"}
{"full_name":"Timeout::Error","name":"Error","class":"Timeout","inherits":"Interrupt","kind":"class","line":35,"language":"Ruby","path":"/usr/lib/ruby/1.8/timeout.rb","pattern":"  class Error < Interrupt"}
{"full_name":"Timeout::ExitException","name":"ExitException","class":"Timeout","inherits":"Exception","kind":"class","line":37,"language":"Ruby","path":"/usr/lib/ruby/1.8/timeout.rb","pattern":"  class ExitException < ::Exception # :nodoc:"}
{"name":"THIS_FILE","full_name":"Timeout::THIS_FILE","class":"Timeout","kind":"constant","line":40,"language":"Ruby","path":"/usr/lib/ruby/1.8/timeout.rb","pattern":"  THIS_FILE = /\\A#{Regexp.quote(__FILE__)}:/o"}
{"name":"CALLER_OFFSET","full_name":"Timeout::CALLER_OFFSET","class":"Timeout","kind":"constant","line":41,"language":"Ruby","path":"/usr/lib/ruby/1.8/timeout.rb","pattern":"  CALLER_OFFSET = ((c = caller[0]) && THIS_FILE =~ c) ? 1 : 0"}
{"name":"timeout","full_name":"Timeout#timeout","class":"Timeout","kind":"method","line":52,"language":"Ruby","path":"/usr/lib/ruby/1.8/timeout.rb","pattern":"  def timeout(sec, klass = nil)"}
{"name":"timeout","full_name":"Object#timeout","class":"Object","kind":"method","line":100,"language":"Ruby","path":"/usr/lib/ruby/1.8/timeout.rb","pattern":"def timeout(n, e = nil, &block) # :nodoc:"}
{"name":"TimeoutError","full_name":"TimeoutError","class":"","kind":"constant","line":108,"language":"Ruby","path":"/usr/lib/ruby/1.8/timeout.rb","pattern":"TimeoutError = Timeout::Error # :nodoc:"}
```

### usage (api)

``` ruby
require 'tag_ripper'
tags = TagRipper.extract("def abc() end", "mycode.rb")
```
