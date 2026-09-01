import { FontAwesomeIcon } from "@fortawesome/react-fontawesome";
import { faCheck, faXmark } from "@fortawesome/free-solid-svg-icons";
import React, { useContext, useState } from "react";
import { EditorContext } from "./AdminShowEditor";
import useJobRunner from "./useJobRunner";
import { adminPost } from "./adminApi";
import { uploadFile, collectFiles, isMp3 } from "./DirectUploader";

const ACTION_LABEL = { replace: "replaces existing audio", fill: "fills empty track" };

const BulkAudioDrop = () => {
  const { show, reload } = useContext(EditorContext);
  const [dragging, setDragging] = useState(false);
  const [uploading, setUploading] = useState(null);
  const [plan, setPlan] = useState(null);
  const [uploadError, setUploadError] = useState(null);
  const { run, busy, status, error } = useJobRunner();

  const reset = () => {
    setPlan(null);
    setUploading(null);
    setUploadError(null);
  };

  const stage = async (files) => {
    if (files.length === 0) {
      setUploadError("No mp3 files found in that drop.");
      return;
    }
    reset();
    setUploading({ done: 0, total: files.length });

    const signedIds = [];
    try {
      for (const file of files) {
        signedIds.push(await uploadFile(file));
        setUploading((prev) => ({ ...prev, done: signedIds.length }));
      }
      const result = await adminPost(`/shows/${show.date}/bulk_audio_match`, {
        signed_ids: signedIds,
      });
      setPlan(result);
    } catch (e) {
      setUploadError(e.message);
    } finally {
      setUploading(null);
    }
  };

  const apply = () => {
    const assignments = plan.matches.map((m) => ({
      signed_id: m.signed_id,
      track_id: m.track_id,
    }));
    if (
      !window.confirm(
        `Apply ${assignments.length} files to ${show.date}? Replaced originals are backed up.`
      )
    ) {
      return;
    }
    run(
      () => adminPost(`/shows/${show.date}/bulk_audio_apply`, { assignments }),
      async () => {
        setPlan(null);
        await reload();
      }
    );
  };

  const counts = plan && {
    replace: plan.matches.filter((m) => m.action === "replace").length,
    fill: plan.matches.filter((m) => m.action === "fill").length,
  };

  return (
    <div className="admin-bulk-audio">
      <div
        className={`admin-dropzone${dragging ? " is-dragging" : ""}`}
        onDragOver={(e) => {
          e.preventDefault();
          setDragging(true);
        }}
        onDragLeave={() => setDragging(false)}
        onDrop={(e) => {
          e.preventDefault();
          setDragging(false);
          // webkitGetAsEntry must run before the handler returns, which
          // collectFiles does synchronously ahead of its first await.
          collectFiles(e.dataTransfer, isMp3)
            .then(stage)
            .catch((err) => setUploadError(err.message));
        }}
      >
        <p>Drop a show folder of mp3s here to replace and fill track audio.</p>
      </div>

      {uploading && (
        <p className="admin-audio-status">
          Uploading {uploading.done} of {uploading.total}
        </p>
      )}

      {plan && (
        <div className="admin-modal-overlay" onClick={reset}>
        <div className="admin-modal admin-modal-wide admin-bulk-plan" onClick={(e) => e.stopPropagation()}>
          <h3>Bulk audio upsert</h3>
          <p>
            {counts.replace} to replace, {counts.fill} to fill,{" "}
            {plan.unmatched_filenames.length} unmatched.
          </p>

          {plan.matches.length > 0 && (
            <ul className="admin-bulk-matches">
              {plan.matches.map((m) => (
                <li key={m.signed_id} className={`is-${m.action}`}>
                  <span className="admin-bulk-position">{m.position}</span>
                  <span className="admin-bulk-title">{m.title}</span>
                  <span className="admin-bulk-filename">{m.filename}</span>
                  <span className="admin-bulk-action">{ACTION_LABEL[m.action]}</span>
                </li>
              ))}
            </ul>
          )}

          {plan.unmatched_filenames.length > 0 && (
            <div className="admin-bulk-unmatched">
              <h4>Unmatched files</h4>
              <ul>
                {plan.unmatched_filenames.map((name) => (
                  <li key={name}>{name}</li>
                ))}
              </ul>
            </div>
          )}

          {plan.tracks_without_audio.length > 0 && (
            <div className="admin-bulk-gaps">
              <h4>Tracks still without audio</h4>
              <ul>
                {plan.tracks_without_audio.map((t) => (
                  <li key={t.track_id}>
                    {t.position}. {t.title}
                  </li>
                ))}
              </ul>
            </div>
          )}

          <div className="admin-modal-actions">
            <button type="button" onClick={apply} disabled={busy || plan.matches.length === 0}>
              <FontAwesomeIcon icon={faCheck} /> Apply {plan.matches.length} files
            </button>
            <button type="button" onClick={reset} disabled={busy}>
              <FontAwesomeIcon icon={faXmark} /> Cancel
            </button>
          </div>
          {status && <span className="admin-audio-status">{status}</span>}
          {error && <p className="admin-error">{error}</p>}
        </div>
        </div>
      )}

      {status && <span className="admin-audio-status">{status}</span>}
      {(error || uploadError) && <p className="admin-error">{error || uploadError}</p>}
    </div>
  );
};

export default BulkAudioDrop;
