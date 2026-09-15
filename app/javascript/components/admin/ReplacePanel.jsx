import React, { useContext, useState } from "react";
import { FontAwesomeIcon } from "@fortawesome/react-fontawesome";
import { faXmark } from "@fortawesome/free-solid-svg-icons";
import { EditorContext } from "./AdminShowEditor";
import useJobRunner from "./useJobRunner";
import { adminPost } from "./adminApi";
import { uploadFile } from "./DirectUploader";
import Modal from "./Modal";

const ReplacePanel = ({ track, onClose }) => {
  const { reload } = useContext(EditorContext);
  const [progress, setProgress] = useState(null);
  const [uploadError, setUploadError] = useState(null);
  const { run, busy, status, error } = useJobRunner();

  const working = busy || progress !== null;

  const replace = async (file) => {
    if (!file) return;
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
      async () => {
        await reload();
        onClose();
      }
    );
  };

  return (
    <Modal title="Replace Audio">
      <input
        type="file"
        accept=".mp3,.flac,.shn,.wav,.aiff"
        disabled={working}
        onChange={(e) => {
          const file = e.target.files[0];
          e.target.value = "";
          replace(file);
        }}
      />
      {progress !== null && <progress max="100" value={progress} />}
      {status && <span className="admin-audio-status">{status}</span>}
      {(error || uploadError) && (
        <p className="admin-error">{error || uploadError}</p>
      )}
      <div className="admin-modal-actions">
        <button type="button" disabled={working} onClick={onClose}>
          <FontAwesomeIcon icon={faXmark} /> Cancel
        </button>
      </div>
    </Modal>
  );
};

export default ReplacePanel;
