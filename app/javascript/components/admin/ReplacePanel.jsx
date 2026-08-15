import React, { useContext, useRef, useState } from "react";
import { EditorContext } from "./AdminShowEditor";
import useJobRunner from "./useJobRunner";
import { adminPost } from "./adminApi";
import { uploadFile } from "./DirectUploader";

const ReplacePanel = ({ track }) => {
  const { reload } = useContext(EditorContext);
  const [progress, setProgress] = useState(null);
  const [uploadError, setUploadError] = useState(null);
  const fileInputRef = useRef(null);
  const { run, busy, status, error } = useJobRunner();

  const replace = async (file) => {
    if (!file) return;
    if (!window.confirm(`Replace the audio for "${track.title}" with ${file.name}?`)) return;
    setUploadError(null);
    setProgress(0);
    let signedId;
    try {
      signedId = await uploadFile(file, setProgress);
    } catch (e) {
      setUploadError(e.message);
      setProgress(null);
      return;
    }
    setProgress(null);
    await run(
      () => adminPost(`/tracks/${track.id}/replace_audio`, { signed_id: signedId }),
      () => reload()
    );
  };

  return (
    <div className="admin-audio-panel">
      <h4>Replace audio</h4>
      <input
        ref={fileInputRef}
        type="file"
        accept=".mp3,audio/mpeg"
        disabled={busy || progress !== null}
        onChange={(e) => {
          const file = e.target.files[0];
          // Allow re-selecting the same filename after a failed upload
          e.target.value = "";
          replace(file);
        }}
      />
      {progress !== null && <progress max="100" value={progress} />}
      {status && <span className="admin-audio-status">{status}</span>}
      {(error || uploadError) && <p className="admin-error">{error || uploadError}</p>}
    </div>
  );
};

export default ReplacePanel;
