import { FontAwesomeIcon } from "@fortawesome/react-fontawesome";
import { faCheck, faCloudArrowUp, faSpinner, faXmark } from "@fortawesome/free-solid-svg-icons";
import React, { useContext, useState } from "react";
import { EditorContext } from "./AdminShowEditor";
import useJobRunner from "./useJobRunner";
import { adminPost, pollJob } from "./adminApi";
import { uploadFile, collectFiles, isMp3, isStagingSource } from "./DirectUploader";

const ACTION_LABEL = { replace: "replaces existing audio", fill: "fills empty track" };

const BulkAudioDrop = () => {
  const { show, reload } = useContext(EditorContext);
  const [open, setOpen] = useState(false);
  const [dragging, setDragging] = useState(false);
  const [uploading, setUploading] = useState(null);
  const [preparing, setPreparing] = useState(null);
  const [plan, setPlan] = useState(null);
  const [uploadError, setUploadError] = useState(null);
  const { run, busy, status, error } = useJobRunner();

  const reset = () => {
    setPlan(null);
    setUploading(null);
    setUploadError(null);
  };

  const close = () => {
    reset();
    setOpen(false);
  };

  const stage = async (files) => {
    if (files.length === 0) {
      setUploadError("No audio files found in that drop.");
      return;
    }
    reset();
    const totalBytes = files.reduce((sum, file) => sum + file.size, 0) || 1;
    let doneBytes = 0;
    setUploading({ done: 0, total: files.length, percent: 0, filename: files[0].name });

    let signedIds = [];
    try {
      for (const file of files) {
        setUploading((prev) => ({ ...prev, filename: file.name }));
        signedIds.push(
          await uploadFile(file, (percent) =>
            setUploading((prev) => ({
              ...prev,
              percent: Math.min(
                99,
                Math.round(((doneBytes + (file.size * percent) / 100) / totalBytes) * 100)
              ),
            }))
          )
        );
        doneBytes += file.size;
        setUploading((prev) => ({
          ...prev,
          done: signedIds.length,
          percent: Math.round((doneBytes / totalBytes) * 100),
        }));
      }
      // Anything beyond bare mp3s takes a server-side pass to unpack archives
      // and transcode lossless sources before the filename matching runs.
      if (files.some((file) => !isMp3(file))) {
        setUploading(null);
        setPreparing({ message: "Preparing files", percent: 0 });
        const { job_id: jobId } = await adminPost(
          `/shows/${show.date}/bulk_audio_prepare`,
          { signed_ids: signedIds }
        );
        const job = await pollJob(jobId, {
          onUpdate: (j) =>
            setPreparing({
              message: j.message || "Preparing files",
              percent: j.progress ?? 0,
            }),
        });
        signedIds = job.payload.signed_ids;
      }
      const result = await adminPost(`/shows/${show.date}/bulk_audio_match`, {
        signed_ids: signedIds,
      });
      setPlan(result);
    } catch (e) {
      setUploadError(e.message);
    } finally {
      setUploading(null);
      setPreparing(null);
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
        close();
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
      <button type="button" onClick={() => setOpen(true)}>
        <FontAwesomeIcon icon={faCloudArrowUp} /> Update audio
      </button>

      {open && !plan && (
        <div className="admin-modal-overlay" onClick={close}>
          <div className="admin-modal admin-modal-wide" onClick={(e) => e.stopPropagation()}>
            <h3>Update audio</h3>
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
                collectFiles(e.dataTransfer, isStagingSource)
                  .then(stage)
                  .catch((err) => setUploadError(err.message));
              }}
            >
              <p>
                Drop a show folder, zip, or audio files (flac, shn, wav, mp3)
                here to replace and fill track audio.
              </p>
            </div>
            {uploading && (
              <>
                <p className="admin-progress-line">
                  <FontAwesomeIcon icon={faSpinner} spin /> Uploading{" "}
                  {Math.min(uploading.done + 1, uploading.total)} of {uploading.total}:{" "}
                  {uploading.filename} ({uploading.percent ?? 0}%)
                </p>
                <progress className="admin-progress-bar" max="100" value={uploading.percent ?? 0} />
              </>
            )}
            {preparing && (
              <>
                <p className="admin-progress-line">
                  <FontAwesomeIcon icon={faSpinner} spin /> {preparing.message} (
                  {preparing.percent}%)
                </p>
                <progress className="admin-progress-bar" max="100" value={preparing.percent} />
              </>
            )}
            {uploadError && <p className="admin-error">{uploadError}</p>}
            <div className="admin-modal-actions">
              <button type="button" onClick={close}>
                <FontAwesomeIcon icon={faXmark} /> Cancel
              </button>
            </div>
          </div>
        </div>
      )}

      {plan && (
        <div className="admin-modal-overlay" onClick={close}>
        <div className="admin-modal admin-modal-wide admin-bulk-plan" onClick={(e) => e.stopPropagation()}>
          <h3>Update audio</h3>
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
            <button type="button" onClick={close} disabled={busy}>
              <FontAwesomeIcon icon={faXmark} /> Cancel
            </button>
          </div>
          {status && <span className="admin-audio-status">{status}</span>}
          {error && <p className="admin-error">{error}</p>}
        </div>
        </div>
      )}

    </div>
  );
};

export default BulkAudioDrop;
