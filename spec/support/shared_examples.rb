RSpec.shared_examples 'responds with 404' do
  let(:json) { JSON[subject.body].deep_symbolize_keys }

  it 'returns 404' do
    expect(subject.status).to eq(404)
  end

  it 'responds with error message' do
    expect(json).to eq(
      success: false,
      message: 'Record not found'
    )
  end
end
