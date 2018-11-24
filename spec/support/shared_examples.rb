# frozen_string_literal: true
RSpec.shared_examples 'responds with 404' do
  let(:json) { JSON[subject.body].deep_symbolize_keys }

  it 'responds with 404 and and error message' do
    expect(subject.status).to eq(404)
    expect(json).to eq(
      success: false,
      message: 'Record not found'
    )
  end
end
