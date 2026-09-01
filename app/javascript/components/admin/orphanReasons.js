// TimestampShifter's reason vocabulary. An admin reading a queue should not
// have to work out what "past_new_end" meant for the tag in front of them.
export const ORPHAN_REASONS = {
  audio_replaced:
    "The audio file was replaced wholesale. The old offsets cannot be mapped " +
    "onto audio nobody has measured, so every timestamp on the track was set " +
    "aside for review.",
  before_new_start:
    "The moment sat before the start of the audio that survived, so it was cut " +
    "away from the front of the track.",
  past_new_end:
    "The moment sat past the end of the audio that survived, so it was cut away " +
    "from the end of the track.",
};

export const reasonText = (reason) =>
  ORPHAN_REASONS[reason] || `Orphaned with reason "${reason}".`;
