FactoryBot.define do
  factory :like do
    user
    association :likable, factory: :show
  end
end
