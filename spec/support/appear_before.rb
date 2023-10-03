RSpec::Matchers.define :appear_before do |later_content|
  match do |earlier_content|
    (page.body.index(earlier_content) || 0) < (page.body.index(later_content) || 0)
  end
end
