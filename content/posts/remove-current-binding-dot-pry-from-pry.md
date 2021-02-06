+++
title = "Remove Current Binding Dot Pry From Pry"
date = "2014-11-14"
slug = "2014/11/14/remove-current-binding-dot-pry-from-pry"
Categories = []
+++

If you are a ruby user and find it annoying to remove [binding.pry](http://pryrepl.org/) by hand, you may
find the following snippet useful. (Put it in your ~/.pryrc to use it)

```ruby .pryrc
Pry.config.commands.command "remove-pry", "Remove current pry" do
  require 'pry/commands/edit/file_and_line_locator'
  file_name, remove_line =
Pry::Command::Edit::FileAndLineLocator.from_binding(_pry_.current_binding)
  temp_file = Tempfile.new('foo')
  i = 0
  File.foreach(file_name) do |line|
    i += 1
    if i == remove_line
      line.gsub!(/binding.pry(\s)?/, "")
      temp_file.write line unless line =~ /\A[[:space:]]*\z/
    else
      temp_file.write line
    end
  end
  temp_file.close
  FileUtils.cp(temp_file.path, file_name)
end
```

**Usage**

Before:
```ruby debug.rb
# ...
if foo == :bar
  binding.pry
  a_shiny_method
end
# ...
```

```ruby in pry
pry> remove-pry
```

After:
```ruby debug.rb
# ...
if foo == :bar
  a_shiny_method
end
# ...
```
