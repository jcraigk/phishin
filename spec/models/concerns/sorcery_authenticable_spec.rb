require "rails_helper"

RSpec.describe SorceryAuthenticable do
  subject(:user) { create(:user, email:, username: "harryhood") }

  let(:email) { "email.1@example.com" }

  it { is_expected.to have_many(:authentications).dependent(:destroy) }

  it { is_expected.not_to allow_value("email@example.com").for(:username) }
  it { is_expected.not_to allow_value("thisusernameistoolong").for(:username) }
  it { is_expected.to allow_value("emailexamplecom").for(:username) }
  it { is_expected.to validate_uniqueness_of(:email) }
  it { is_expected.to allow_value(email).for(:email) }
  it { is_expected.not_to allow_value("not-an-email").for(:email) }
  it { is_expected.to validate_length_of(:password).is_at_least(5) }

  it "validates password confirmation if password is present" do
    user.password = "password"
    user.password_confirmation = "different_password"
    expect(user).not_to be_valid
    expect(user.errors[:password_confirmation]).to include("doesn't match Password")
  end

  describe "before_save callback" do
    before { user.username = nil }

    it "assigns a username from email before saving" do
      user.save!
      expect(user.username).to eq("email_1")
    end

    it "appends a random hex if username already exists" do
      create(:user, username: "email_1")
      user.username = nil
      user.save!
      expect(user.username).to match(/^email_1_[0-9a-f]{4}$/)
    end
  end
end
