FactoryBot.define do
  factory :like do
    user
    likable { association :show }
  end
end
