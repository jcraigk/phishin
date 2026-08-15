import React, { useContext, useState } from "react";
import { EditorContext } from "./AdminShowEditor";
import PreviewPlayer from "./PreviewPlayer";
import useJobRunner from "./useJobRunner";
import { adminPost, fetchJobAudio } from "./adminApi";

const seconds = (ms) => Math.round((ms || 0) / 100) / 10;

const CombinePanel = ({ track, previous }) => {
  const { show, reload, setGapsStale } = useContext(EditorContext);
  const [previewUrl, setPreviewUrl] = useState(null);
  const [previewed, setPreviewed] = useState(false);
  const { run, busy, status, error } = useJobRunner();

  const previousSeconds = seconds(previous.duration);
  const trackSeconds = seconds(track.duration);
  const bothHaveAudio =
    previous.audio_status !== "missing" && track.audio_status !== "missing";
  const mergedTitle = `${previous.title} > ${track.title}`;

  const renderPreview = () =>
    run(
      () => adminPost(`/tracks/${track.id}/combine_preview`),
      async (job) => {
        setPreviewUrl(bothHaveAudio ? await fetchJobAudio(job.id, 0) : null);
        setPreviewed(true);
      }
    );

  const applyCombine = () => {
    const message =
      `Combine "${track.title}" into "${previous.title}"? ` +
      `This destroys one track row and leaves a single track titled ` +
      `"${mergedTitle}". Likes, tags, and playlist entries move to the ` +
      `surviving track, and both original audio files are backed up.`;
    if (!window.confirm(message)) return;
    run(
      () => adminPost(`/tracks/${track.id}/combine_apply`),
      async () => {
        setPreviewUrl(null);
        setPreviewed(false);
        await reload();
        if (show.published) setGapsStale(true);
      }
    );
  };

  return (
    <div className="admin-audio-panel">
      <h4>Combine with previous</h4>

      <p className="admin-audio-note">
        Position {previous.position} "{previous.title}" and position{" "}
        {track.position} "{track.title}" become one track titled "{mergedTitle}".
      </p>

      {bothHaveAudio ? (
        <p className="admin-audio-note">
          Audio: {previousSeconds.toFixed(1)}s plus {trackSeconds.toFixed(1)}s
          becomes about {(previousSeconds + trackSeconds).toFixed(1)}s.
        </p>
      ) : (
        <p className="admin-audio-note">
          Only one of these tracks has audio, so nothing is joined. The surviving
          track keeps whichever file exists, and the preview has nothing to play.
        </p>
      )}

      <PreviewPlayer label="Joined audio" url={previewUrl} />

      <div className="admin-audio-actions">
        <button type="button" onClick={renderPreview} disabled={busy}>
          Render Preview
        </button>
        <button
          type="button"
          className="admin-danger"
          onClick={applyCombine}
          disabled={busy || !previewed}
        >
          Apply Combine
        </button>
        {!previewed && (
          <span className="admin-audio-status">
            Render a preview and listen to the seam before applying.
          </span>
        )}
        {status && <span className="admin-audio-status">{status}</span>}
      </div>

      {error && <p className="admin-error">{error}</p>}
    </div>
  );
};

export default CombinePanel;
