export const STOP_IMPORT_CONFIRM = "Stop this import? Everything it has imported so far is deleted.";

export const deleteDraftMessage = (trackCount) =>
  trackCount > 0
    ? `The draft, its ${trackCount} tracks, audio, tags and likes are removed permanently.`
    : "The draft and its staged audio are removed permanently.";
