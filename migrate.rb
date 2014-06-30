#!/bin/ruby

require 'pg'

article_query = '
select a.title
,      a.title_slug
,      a.summary
,      a.body
,      a.date_published
,      string_agg(t.name, \', \') as tags
from blog_article a
join auth_user u on u.id = a.user_id
right outer join tagging_taggeditem ti on ti.object_id = a.id
right outer join tagging_tag t on t.id = ti.tag_id
where u.username = \'jaketrent\'
and   a.active = true
group by a.title
,      a.title_slug
,      a.summary
,      a.body
,      a.date_published
--limit 1
'

conn = PGconn.open dbname: 'rockycode'
res  = conn.exec article_query

def code_type_conversions
  {
    django: 'python',
    xquery: '',
    filesystem: ''
  }
end

def replace_code_types(code_type)
  code_type_conversions[code_type.to_sym] or code_type
end

def keys_to_sym(row)
  row.inject({}){|memo,(k,v)| memo[k.to_sym] = v; memo}
end

# TODO: convert links `alt text <http://something>`_
# TODO: convert images  .. image http://something
# TODO: handle blank lines in codeblocks better
def format_body(body)
  has_codeblocks = body =~ /\.\. code-block::/
  has_code = body =~ /<code/
  has_indent_code = body =~ /    :::/

  if has_codeblocks
    convert_codeblocks body
  elsif has_code
    convert_code body
  elsif has_indent_code
    convert_indent_code body
  else
    body
  end
end

def convert_codeblocks(body)
  is_in_codeblock = false
  had_one_allowed_blank_line = false

  body.lines.map(&:chomp).map do |line|
    is_codeblock_start = line =~ /^\.\. code-block.*$/
    if is_codeblock_start
      code_type = replace_code_types line.gsub(/^\.\. code-block:: ?(\w+).*$/, '\1')
      line = "```#{code_type}"
      is_in_codeblock = true
    elsif is_in_codeblock
      is_blank_line = line =~ /^$/
      is_codeblock_body = line =~ /^\s\S+$/

      if is_blank_line and not had_one_allowed_blank_line
        line = nil
        had_one_allowed_blank_line = true
      elsif is_codeblock_body
        line = line.gsub!(/^\s(.+)$/, '\1')
      else
        is_in_codeblock = false
        had_one_allowed_blank_line = false
        line = line + "\n```"
      end
    end

    line
  end.reject(&:nil?).join("\n")
end

def convert_indent_code(body)
  is_in_codeblock = false

  body.lines.map(&:chomp).map do |line|
    is_indent_start = line =~ /^    :::.*$/

    if is_indent_start
      code_type = replace_code_types line.gsub(/^    :::(\w*).*$/, '\1')
      line = "```#{code_type}"
      is_in_codeblock = true
    elsif is_in_codeblock
      is_indented = line =~ /^    .*/

      if is_indented
        line = line.gsub(/^    (.+)$/, '\1')
      else
        line = "```\n" + line
        is_in_codeblock = false
      end
    end

    line
  end.reject(&:nil?).join("\n")
end

def convert_code(body)
  body.lines.map(&:chomp).map do |line|
    is_code_start = line =~ /<code/
    is_code_end = line =~ /<\/code>/
    if is_code_start
      code_type = replace_code_types line.gsub(/^<code class="(\w+)".*$/, '\1')
      line = "```#{code_type}"
    elsif is_code_end
      line = "```"
    end

    line
  end.reject(&:nil?).join("\n")
end


def to_octopress(article)
  formatted_date = article[:date_published].gsub(/:[^:]*$/, '')
  description = article[:summary][0..155]
  formatted_body = format_body article[:body]

  "
---
layout: post
title: \"#{article[:title]}\"
date: #{formatted_date}
comments: true
categories: [Code, #{article[:tags]}]
description: #{description}
keywords: #{article[:tags]}
published: true
---

#{article[:summary]}
<!--more-->

#{formatted_body}

  "
end

# eg, 2012-09-26-developer-relations-for-internal-developers.md
def gen_filename(article)
  formatted_date = article[:date_published].gsub(/^(\S+).*/, '\1')
  formatted_date + '-' + article[:title_slug] + '.md'
end

def write_file(article)
  file = File.new('articles/' + gen_filename(article), 'w')
  file.puts(to_octopress(article))
end

res.each do |row|
  write_file keys_to_sym row
end
