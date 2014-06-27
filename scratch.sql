-- SELECT TAGS FOR ARTICLE
select string_agg(t.name, ',')
from tagging_taggeditem ti
join tagging_tag t on t.id = ti.tag_id
where object_id = 359;

-- SELECT ARTICLES
select a.title
,      a.title_slug
,      a.summary
,      a.body
,      a.date_published
,      a.active
,      a.user_id
,      string_agg(t.name, ',') as tags
from blog_article a
join auth_user u on u.id = a.user_id
right outer join tagging_taggeditem ti on ti.object_id = a.id
right outer join tagging_tag t on t.id = ti.tag_id
where u.username = 'jaketrent'
group by a.title
,      a.title_slug
,      a.summary
,      a.body
,      a.date_published
,      a.active
,      a.user_id;

