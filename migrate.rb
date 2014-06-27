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
limit 1
'

conn = PGconn.open dbname: 'rockycode'
res  = conn.exec article_query

def keys_to_sym(row)
  row.inject({}){|memo,(k,v)| memo[k.to_sym] = v; memo}
end

def to_octopress(row)
  formatted_date = row[:date_published].gsub(/:[^:]*$/, '')
  description = row[:summary][0..155]
  formatted_body = row[:body]

  # TODO: convert code blocks in body

  "
  ---
  layout: post
  title: \"#{row[:title]}\"
  date: #{formatted_date}
  comments: true
  categories: [Code, #{row[:tags]}]
  description: #{description}
  keywords: #{row[:tags]}
  published: true
  ---

  #{row[:summary]}

  <!--more-->

  #{formatted_body}

  "
end

res.each do |row|
  puts to_octopress keys_to_sym row
end
