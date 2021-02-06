+++
title = "Add Flattr to Octopress"
date = "2013-01-20"
slug = "2013/01/20/add-flattr-to-octopress"
description = "how to add flattr button and flattr payment link to your octopress"
published = true
Categories = ["flattr", "octopress", "feed"]
+++

**Update** add payment relation to header, thanks to [@voxpelli](https://twitter.com/voxpelli)

In this article I will show how to add [{% img left https://flattr.com/_img/icons/flattr_logo_16.png 14 14 %}Flattr](https://flattr.com/)
to your [{% img left /favicon.png 14 14 %} octopress](http://octopress.org) blog and feed.

First of all add your flattr user name (also known as user id) to the
configuration:

```yaml _config.yml
# Flattr
flattr_user: YourFlattrName
```
To add a flattr button to the sharing section of your posts, add this template:

<pre><code>
&lt;a class="FlattrButton" style="display:none;"
    title="{{ page.title }}"
    data-flattr-uid="{{ site.flattr_user }}"
    data-flattr-tags="{{ page.categories | join: "," }}"
    data-flattr-button="compact"
    data-flattr-category="text"
    href="{{ site.url }}{{ page.url }}"&gt;
    {% if page.description %}{{ page.description }}{% else %}{{page.content | truncate: 500}}{% endif %}
&lt;/a&gt;
</code></pre>

and add the following javascript to your custom head.html

<pre><code>
{% if site.flattr_user %}
&lt;script type="text/javascript"&gt;
/* &lt;![CDATA[ */
    (function() {
        var s = document.createElement('script'), t = document.getElementsByTagName('script')[0];
        s.type = 'text/javascript';
        s.async = true;
        s.src = '//api.flattr.com/js/0.6/load.js?mode=auto';
        t.parentNode.insertBefore(s, t);
    })();
/* ]]&gt; */
&lt;/script&gt;
{% endif %}
</code></pre>

Now include it in your sharing template:

<pre><code>
&lt;div class="share"&gt;
    {% if site.flattr_user %}
    {% include post/flattr_button.html %}
    {% endif %}
    ...
&lt;/div&gt;
</code></pre>

The result will look like this:

<div>
<a class="FlattrButton" style="display:none;"
    title="{{ page.title }}"
    data-flattr-uid="{{ site.flattr_user }}"
    data-flattr-tags="{{ page.categories | join: "," }}"
    data-flattr-button="compact"
    data-flattr-category="text"
    href="{{ site.url }}{{ page.url }}">
    {% if page.description %}{{ page.description }}{% else %}{{page.content | truncate: 500}}{% endif %}
</a>
</div>

To make flattr discoverable by programs (feed reader, podcatcher, browser extensions...), a [payment relation link](http://developers.flattr.net/feed/) is needed in html head as well as in the atom feed.

First add this (lengthy) template...

<pre><code>
{% if post %}
{% assign item = post %}
{% else %}
{% assign item = page %}
{% endif %}

{% capture flattr_url %}{{ site.url }}{{ item.url }}{% endcapture %}

{% capture flattr_title %}{% if item.title %}{{ item.title }}{% else %}{{ site.title }}{% endif %}{% endcapture %}

{% capture flattr_description %}{% if item.description %}{{ item.description}}{% else index == true %}{{ site.description }}{% endif %}{% endcapture %}

{% capture flattr_param %}url={{ flattr_url | cgi_escape }}&amp;user_id={{site.flattr_user | cgi_escape }}&amp;title={{ flattr_title | cgi_escape }}&amp;category=text&amp;description={{ flattr_description | truncate: 1000 | cgi_escape }}&amp;tags={{ item.categories | join: "," | cgi_escape }}{% endcapture %}
</code></pre>

... then include it in your feed ...

<pre><code>
---
layout: null
---
&lt;?xml version="1.0" encoding="utf-8"?&gt;
&lt;feed xmlns="http://www.w3.org/2005/Atom"&gt;
  &lt;title&gt;&lt;![CDATA[{{ site.title }}]]&gt;&lt;/title&gt;

  ...

  {% for post in site.posts limit: 20 %}
  &lt;entry&gt;
    &lt;title type="html"&gt;&lt;![CDATA[{{ post.title | cdata_escape }}]]&gt;&lt;/title&gt;
    &lt;link href="{{ site.url }}{{ post.url }}"/&gt;
    &lt;updated&gt;{{ post.date | date_to_xmlschema }}&lt;/updated&gt;
    &lt;id&gt;{{ site.url }}{{ post.id }}&lt;/id&gt;
    {% if site.flattr_user %}
    {% include flattr_param.html %}
    &lt;link rel="payment" href="https://flattr.com/submit/auto?{{ flattr_param }}" type="text/html" /&gt;
    {% endif %}
    &lt;content type="html"&gt;&lt;![CDATA[
      {{ post.content | expand_urls: site.url | cdata_escape }}
    ]]&gt;&lt;/content&gt;
  &lt;/entry&gt;
  {% endfor %}
&lt;/feed&gt;
</code></pre>

and in your head template:

<pre><code>
{% if site.flattr_user %}
&lt;script type="text/javascript"&gt;
/* &lt;![CDATA[ */
    (function() {
        var s = document.createElement('script'), t = document.getElementsByTagName('script')[0];
        s.type = 'text/javascript';
        s.async = true;
        s.src = '//api.flattr.com/js/0.6/load.js?mode=auto';
        t.parentNode.insertBefore(s, t);
    })();
/* ]]&gt; */
&lt;/script&gt;

{% include flattr_param.html %}
&lt;link rel="payment" href="https://flattr.com/submit/auto?{{ flattr_param }}" type="text/html" /&gt;
{% endif %}
</code></pre>

Because not (yet) all feed reader support this feature, you can add a dedicated flattr link.

Therefor create a new template:

<pre><code>
{% include flattr_param.html %}
&lt;a href="https://flattr.com/submit/auto?url={{ flattr_param }}"&gt;
      &lt;img src="https://api.flattr.com/button/flattr-badge-large.png"
           alt="Flattr this"/&gt;
&lt;/a&gt;
</code></pre>

Compared to the other button, this one will not require javascript, which isn't
always available in feed readers.

Finally add it your feed template:

<pre><code>
---
layout: null
---
&lt;?xml version="1.0" encoding="utf-8"?&gt;
&lt;feed xmlns="http://www.w3.org/2005/Atom"&gt;
  &lt;title&gt;&lt;![CDATA[{{ site.title }}]]&gt;&lt;/title&gt;

  ...

  {% for post in site.posts limit: 20 %}
  &lt;entry&gt;
    &lt;title type="html"&gt;&lt;![CDATA[{{ post.title | cdata_escape }}]]&gt;&lt;/title&gt;
    &lt;link href="{{ site.url }}{{ post.url }}"/&gt;
    &lt;updated&gt;{{ post.date | date_to_xmlschema }}&lt;/updated&gt;
    &lt;id&gt;{{ site.url }}{{ post.id }}&lt;/id&gt;
    {% if site.flattr_user %}
    {% include flattr_param.html %}
    &lt;link rel="payment" href="https://flattr.com/submit/auto?{{ flattr_param }}" type="text/html" /&gt;
    {% endif %}
    &lt;content type="html"&gt;&lt;![CDATA[
      {{ post.content | expand_urls: site.url | cdata_escape }}
      {% if site.flattr_user %} {% include flattr_feed_button.html %} {% endif %}
    ]]&gt;&lt;/content&gt;
  &lt;/entry&gt;
  {% endfor %}
&lt;/feed&gt;
</code></pre>

This will add a flattr button to each entry in your feed.

Preview:

{% include flattr_param.html %}
[{% img left //api.flattr.com/button/flattr-badge-large.png Alt Flattr this %}](https://flattr.com/submit/auto?{{ flattr_param }})

That's all folks! I hope you will become rich by your flattr income.
