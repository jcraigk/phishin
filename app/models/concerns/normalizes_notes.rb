module NormalizesNotes
  extend ActiveSupport::Concern

  included do
    # Strip the trailing period from single-sentence notes; leave
    # multi-sentence notes, ellipses, and other punctuation alone
    normalizes :notes, with: lambda { |notes|
      notes = notes.strip
      next notes unless notes.match?(/(?<!\.)\.\z/)
      next notes if notes.delete_suffix(".").match?(/\.\s/)
      notes.delete_suffix(".")
    }
  end
end
