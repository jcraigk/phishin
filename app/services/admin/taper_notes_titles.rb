module Admin::TaperNotesTitles
  def self.call(notes:, filenames:)
    return {} if notes.blank?
    parsed = Admin::TaperNotesTracklist.call(notes)
    titles = filenames.index_with { |name| (key = Admin::TaperNotesTracklist.key_for(name)) && parsed[key] }
    unresolved = titles.select { |_name, title| title.nil? }.keys
    titles.merge!(Admin::TaperNotesAiTracklist.call(notes:, filenames: unresolved)) if unresolved.any?
    titles.compact
  end
end
