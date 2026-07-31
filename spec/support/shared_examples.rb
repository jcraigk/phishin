RSpec.shared_examples "normalizes notes" do
  it "strips the trailing period from a single-sentence note" do
    subject.notes = "Trey on a mini drum kit."
    expect(subject.notes).to eq("Trey on a mini drum kit")
  end

  it "keeps the trailing period on a multi-sentence note" do
    subject.notes = "White coils descended. Dancers appeared."
    expect(subject.notes).to eq("White coils descended. Dancers appeared.")
  end

  it "keeps a trailing ellipsis" do
    subject.notes = "The jam trailed off..."
    expect(subject.notes).to eq("The jam trailed off...")
  end

  it "keeps other terminal punctuation" do
    subject.notes = "Happy birthday, Fish!"
    expect(subject.notes).to eq("Happy birthday, Fish!")
  end

  it "strips surrounding whitespace" do
    subject.notes = " Trey on marimba. "
    expect(subject.notes).to eq("Trey on marimba")
  end

  it "leaves nil untouched" do
    subject.notes = nil
    expect(subject.notes).to be_nil
  end

  it "decodes HTML entities" do
    subject.notes = "Big Head Todd &amp; the Monsters played &quot;NICU&quot;"
    expect(subject.notes).to eq('Big Head Todd & the Monsters played "NICU"')
  end

  it "decodes double-encoded and numeric entities" do
    subject.notes = "Fish&#39;s vacuum solo &amp;amp; more"
    expect(subject.notes).to eq("Fish's vacuum solo & more")
  end

  it "leaves plain ampersands unchanged" do
    subject.notes = "Mike & Trey trade licks; R&B jam"
    expect(subject.notes).to eq("Mike & Trey trade licks; R&B jam")
  end
end

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
