# encoding: utf-8

def all_tags
  unless @_tags
    @_tags = YAML.load_file('content/pages/.tags.yaml')
    @items.inject([]){|tags,item|item[:tags] ? tags+item[:tags] : tags}.sort.uniq.each do |tag|
      raise "not defined tag #{tag}" unless @_tags[tag]
    end
  end
  @_tags
end
