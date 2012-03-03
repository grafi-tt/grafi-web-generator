# encoding: utf-8

def make_summary(item, my_path = nil, option={})
  default_option = {created: true, updated: true, tag: true}
  option.merge! default_option
  @summary_template ||= ERB.new(File.read('layouts/summary_item.erb', encoding: 'UTF-8'), nil, '-')
  @summary_template.result(binding)
end
