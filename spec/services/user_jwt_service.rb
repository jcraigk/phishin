require "rails_helper"
require "jwt"

RSpec.describe UserJwtService do
  let(:user) { create(:user) }
  let(:secret_key) { Rails.application.secret_key_base }
  let(:service) { described_class.call(user) }

  describe "#call" do
    it "returns a JWT token" do
      token = service
      decoded_token = JWT.decode(token, secret_key, true, { algorithm: "HS256" })

      expect(decoded_token).to be_an_instance_of(Array)
      expect(decoded_token.first["sub"]).to eq(user.id)
    end

    it "sets the expiration time to 1 year from now" do
      token = service
      decoded_token = JWT.decode(token, secret_key, true, { algorithm: "HS256" })
      exp = Time.at(decoded_token.first["exp"])

      expect(exp).to be_within(1.second).of(1.year.from_now)
    end

    it "uses the HS256 algorithm" do
      token = service
      header = JWT.decode(token, nil, false).last

      expect(header["alg"]).to eq("HS256")
    end
  end
end
