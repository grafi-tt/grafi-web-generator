# encoding: utf-8

require 'shellwords'
def create_archive
  title = "記事一覧（作成日時順）"
  content = <<-'EOH'
<ul>
<%= sorted_articles.map{|item|"<li>#{link_to(item[:title]+item[:created_at].strftime("(%Y-%m-%d)"), item.path)}</li>"}.join("\n") %>
</ul>
  EOH
  item = Nanoc3::Item.new(
    content, {is_hidden: true, extension: 'html', title: title}, "/archive/", binary: false
  )
  @items << item
end

def create_tag_pages
  all_tags.each do |tag,slug|
    title = "#{tag}に関するページ一覧"
    content = <<-"EOH"
<ul>
<% items = items_with_tag(#{tag.dump}) %>
    EOH
    content += <<-'EOH'
<%= items.map{|item|"<li>#{link_to(item[:title], item.path)}</li>"}.join("\n") %>
</ul>
    EOH
    @items << Nanoc3::Item.new(
      content, {is_hidden: true, extension: 'html', title: title}, "/tag/#{slug}/", binary: false
    )
  end
end
def add_kinds
  article_extensions = %w(txt html xhtml md)
  @items.select{|item|item.identifier =~ %r!^/pages/! && article_extensions.include?(item[:extension])}.each do |item|
    item[:kind] = 'article'
  end
end

def add_titles
  @items.select{|item|item.identifier =~ %r!^/pages/! && item[:extension] == 'txt'}.each do |item|
    match = item.raw_content.match(/\A= *(.*?) *=?$/)
    item[:title] = match[1] if match && !item[:title]
  end
end

def add_times
  @items.select{|item|item[:kind] == 'article'}.each do |item|
    item[:created_at] ||= Time.now
  end
end

def add_indexes
  sorted_updated_articles.each_with_index{|item,i|item[:index]=i}
end

def add_git_timestamps
  table = Hash.new
  dirs = %w(pages assets resources)
  dirs.each do |dir|
    str = `cd content/#{dir}; git --no-pager log --name-only --pretty=format:'%ci'`
    str.split(/^\n/).each do |chunk; time|
      chunk.lines.each do |line|
        if !time
          time = Time.strptime(line.chomp, '%F %T %:z')
        else
          line.chomp!
          (table[line.sub(%r!(.*)\..*?$!,"/#{dir}/\\1/").sub(%r!index/$!,'')] ||= []) << time unless line =~ /yaml$/
        end
      end
    end
  end
  @items.each do |item|
    if table[item.identifier]
      item[:updated_at] ||= table[item.identifier].first
      item[:created_at] ||= table[item.identifier].last
    end
  end
end
