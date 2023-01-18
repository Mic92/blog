+++
title = "Pubsubhubbub With Octopress"
date = "2013-01-02"
slug = "2013/01/02/pubsubhubbub-with-octopress"
Categories = ["superfeedr", "octopress", "pubsubhubbub", "real-time"]
+++

In this article I explain how to set up octopress with
[pubsubhubbub](https://en.wikipedia.org/wiki/PubSubHubbub), to get push-enabled
feeds. In my example I use [superfeedr](http://superfeedr.com/), which is free
to use.

After you signup up a hub, in my case
[higgsboson.superfeedr.com](http://higgsboson.superfeedr.com), you have to add a
hub reference to your atom feed.

```yaml _config.yml
# ....

# pubsubhubbub
hub_url: http://higgsboson.superfeedr.com/ # <--- replace this with your hub
```

Insert this line:

{% raw %}

```xml
    {% if site.hub_url %}<link href="{{ site.hub_url }}" rel="hub"/>{% endif %}
```

{% endraw %}

into `source/atom.xml`. So it looks like this:

{% raw %}

```xml source/atom.xml
<?xml version="1.0" encoding="utf-8"?>
<feed xmlns="http://www.w3.org/2005/Atom">

  <title><![CDATA[{{ site.title }}]]></title>
  <link href="{{ site.url }}/atom.xml" rel="self"/>
  <link href="{{ site.url }}/"/>
  {% if site.hub_url %}<link href="{{ site.hub_url }}" rel="hub"/>{% endif %}
  <updated>{{ site.time | date_to_xmlschema }}</updated>
  <id>{{ site.url }}/</id>
  <author>
    <name><![CDATA[{{ site.author | strip_html }}]]></name>
    {% if site.email %}<email><![CDATA[{{ site.email }}]]></email>{% endif %}
  </author>
  <generator uri="http://octopress.org/">Octopress</generator>

  {% for post in site.posts limit: 20 %}
  <entry>
    <title type="html"><![CDATA[{{ post.title | cdata_escape }}]]></title>
    <link href="{{ site.url }}{{ post.url }}"/>
    <updated>{{ post.date | date_to_xmlschema }}</updated>
    <id>{{ site.url }}{{ post.id }}</id>
    <content type="html"><![CDATA[{{ post.content | expand_urls: site.url | cdata_escape }}]]></content>
  </entry>
  {% endfor %}
</feed>
```

{% endraw %}

To push out updates, you have to ping your hub, this is easily done in your
deploy rake task.

Add these lines to the end of your deploy task in your Rakefile:

```ruby
require 'net/http'
require 'uri'
hub_url = "higgsboson.superfeedr.com" # <--- replace this with your hub
atom_url = "http://blog.higgsboson.tk/atom.xml" # <--- replace this with your full feed url
resp, data = Net::HTTP.post_form(URI.parse(hub_url),
    {'hub.mode' => 'publish',
    'hub.url' => atom_url})
raise "!! Hub notification error: #{resp.code} #{resp.msg}, #{data}" unless resp.code == "204"
puts "## Notified hub (" + hub_url + ") that feed #{atom_url} has been updated"
```

So you end up with something like this:

```ruby Rakefile
desc "Default deploy task"
task :deploy do
  # Check if preview posts exist, which should not be published
  if File.exists?(".preview-mode")
    puts "## Found posts in preview mode, regenerating files ..."
    File.delete(".preview-mode")
    Rake::Task[:generate].execute
  end

  Rake::Task[:copydot].invoke(source_dir, public_dir)
  Rake::Task["#{deploy_default}"].execute

  require 'net/http'
  require 'uri'
  hub_url = "higgsboson.superfeedr.com" # <--- replace this with your hub
  atom_url = "http://blog.higgsboson.tk/atom.xml" # <--- replace this with your full feed url
  resp, data = Net::HTTP.post_form(URI.parse(hub_url),
                                   {'hub.mode' => 'publish',
                                    'hub.url' => atom_url})
  raise "!! Hub notification error: #{resp.code} #{resp.msg}, #{data}" unless resp.code == "204"
  puts "## Notified hub (" + hub_url + ") that feed #{atom_url} has been updated"
end
```

Now whenever you run `rake deploy`, it will automatically update your hub.

If you have a jabber or google talk account, you can easily verify your setup by
adding [push-bot](https://push-bot.appspot.com/) to your contact list and
subscribe to your feed.
