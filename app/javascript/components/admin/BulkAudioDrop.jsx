import { FontAwesomeIcon } from "@fortawesome/react-fontawesome";
import {
  faCheck,
  faCloudArrowUp,
  faFileAudio,
  faFolderOpen,
  faPause,
  faPlay,
  faXmark,
} from "@fortawesome/free-solid-svg-icons";
import MoonLoader from "react-spinners/MoonLoader";
import React, { useContext, useEffect, useMemo, useRef, useState } from "react";
import { EditorContext } from "./AdminShowEditor";
import useJobRunner from "./useJobRunner";
import { adminPost, pollJob } from "./adminApi";
import { uploadFile, collectFiles, isMp3, isStagingSource } from "./DirectUploader";
import { formatDurationTrack } from "../helpers/utils";
import { GaplessEngine } from "../player/GaplessEngine";
import { WebAudioBackend } from "../player/WebAudioBackend";

const GROUP_LABEL = { replace: "Replace track audio", fill: "Fill empty tracks" };

const BulkAudioDrop = () => {
  const { show, reload } = useContext(EditorContext);
  const [open, setOpen] = useState(false);
  const [dragging, setDragging] = useState(false);
  const [uploading, setUploading] = useState(null);
  const [preparing, setPreparing] = useState(null);
  const [plan, setPlan] = useState(null);
  const [uploadError, setUploadError] = useState(null);
  const { run, busy, status, progress, error } = useJobRunner();
  const cancelSeq = useRef(0);
  const fileInputRef = useRef(null);
  const folderInputRef = useRef(null);
  const previewEngine = useRef(null);
  const [preview, setPreview] = useState({ index: 0, playing: false, time: 0 });
  const [selected, setSelected] = useState(() => new Set());

  useEffect(() => {
    setSelected(new Set((plan?.matches || []).map((m) => m.signed_id)));
  }, [plan]);

  const toggleSelected = (signedId) => {
    setSelected((prev) => {
      const next = new Set(prev);
      if (next.has(signedId)) {
        next.delete(signedId);
      } else {
        next.add(signedId);
      }
      return next;
    });
  };

  const previewList = useMemo(
    () =>
      plan
        ? ["replace", "fill"].flatMap((action) =>
            plan.matches.filter((m) => m.action === action)
          )
        : [],
    [plan]
  );

  useEffect(() => {
    if (previewList.length === 0) return undefined;
    const engine = new GaplessEngine(new WebAudioBackend());
    engine.onTime = (seconds, index) =>
      setPreview((prev) => ({ ...prev, time: seconds, index }));
    engine.onTrackChange = (index) =>
      setPreview((prev) => ({ ...prev, index, time: 0 }));
    engine.onPlayChange = (playing) =>
      setPreview((prev) => ({ ...prev, playing }));
    engine.load(previewList.map((m) => ({ url: m.url, offset: 0, end: null })));
    previewEngine.current = engine;
    setPreview({ index: 0, playing: false, time: 0 });
    return () => {
      engine.destroy();
      previewEngine.current = null;
    };
  }, [previewList]);

  const togglePreview = (flatIndex) => {
    const engine = previewEngine.current;
    if (!engine) return;
    if (preview.index === flatIndex) {
      engine.toggle();
    } else {
      engine.goto(flatIndex, { play: true });
    }
  };
  const abortUpload = useRef(null);
  const pollController = useRef(null);

  const reset = () => {
    setPlan(null);
    setUploading(null);
    setUploadError(null);
  };

  const close = () => {
    cancelSeq.current += 1;
    if (abortUpload.current) abortUpload.current();
    if (pollController.current) pollController.current.abort();
    reset();
    setPreparing(null);
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

    const seq = cancelSeq.current;
    const cancelled = () => cancelSeq.current !== seq;
    let signedIds = [];
    try {
      for (const file of files) {
        setUploading((prev) => ({ ...prev, filename: file.name }));
        signedIds.push(
          await uploadFile(
            file,
            (percent) =>
              setUploading((prev) => ({
                ...prev,
                percent: Math.min(
                  99,
                  Math.round(((doneBytes + (file.size * percent) / 100) / totalBytes) * 100)
                ),
              })),
            (abort) => {
              abortUpload.current = abort;
            }
          )
        );
        if (cancelled()) return;
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
        setPreparing({ message: "Preparing files", percent: 0 });
        const { job_id: jobId } = await adminPost(
          `/shows/${show.date}/bulk_audio_prepare`,
          { signed_ids: signedIds }
        );
        if (cancelled()) return;
        pollController.current = new AbortController();
        const job = await pollJob(jobId, {
          signal: pollController.current.signal,
          onUpdate: (j) =>
            setPreparing({
              message: j.message || "Preparing files",
              percent: j.progress ?? 0,
            }),
        });
        signedIds = job.payload.signed_ids;
      }
      if (cancelled()) return;
      const result = await adminPost(`/shows/${show.date}/bulk_audio_match`, {
        signed_ids: signedIds,
      });
      if (cancelled()) return;
      setPlan(result);
    } catch (e) {
      if (!cancelled()) setUploadError(e.message);
    } finally {
      abortUpload.current = null;
      pollController.current = null;
      if (!cancelled()) {
        setUploading(null);
        setPreparing(null);
      }
    }
  };

  const pickFiles = (e) => {
    const files = Array.from(e.target.files).filter(isStagingSource);
    e.target.value = "";
    stage(files);
  };

  const apply = () => {
    const assignments = plan.matches
      .filter((m) => selected.has(m.signed_id))
      .map((m) => ({
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

  return (
    <div className="admin-bulk-audio">
      <button type="button" onClick={() => setOpen(true)}>
        <FontAwesomeIcon icon={faCloudArrowUp} /> Update audio
      </button>

      {open && !plan && (
        <div className="admin-modal-overlay">
          <div className="admin-modal admin-modal-wide" onClick={(e) => e.stopPropagation()}>
            <h3>Update Audio</h3>
            {!uploading && !preparing && (
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
                here to replace and fill track audio. Include a notes txt to
                name the tracks.
              </p>
              <div className="admin-dropzone-browse">
                <button type="button" onClick={() => fileInputRef.current.click()}>
                  <FontAwesomeIcon icon={faFileAudio} /> Browse files
                </button>
                <button type="button" onClick={() => folderInputRef.current.click()}>
                  <FontAwesomeIcon icon={faFolderOpen} /> Browse folder
                </button>
              </div>
            </div>
            )}
            <input
              ref={fileInputRef}
              type="file"
              multiple
              hidden
              onChange={pickFiles}
            />
            <input
              ref={folderInputRef}
              type="file"
              webkitdirectory=""
              hidden
              onChange={pickFiles}
            />
            {uploading && (
              <>
                <p className="admin-progress-line">
                  {preparing ? (
                    <>
                      <FontAwesomeIcon icon={faCheck} /> Upload complete
                    </>
                  ) : (
                    <>
                      <MoonLoader color="#c7c8ca" size={18} /> Uploading{" "}
                      {Math.min(uploading.done + 1, uploading.total)} of {uploading.total}:{" "}
                      {uploading.filename}
                    </>
                  )}
                </p>
                <progress
                  className="admin-progress-bar"
                  max="100"
                  value={preparing ? 100 : uploading.percent ?? 0}
                />
              </>
            )}
            {preparing && (
              <>
                <p className="admin-progress-line">
                  <MoonLoader color="#c7c8ca" size={18} /> {preparing.message}
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
        <div className="admin-modal-overlay">
        <div className="admin-modal admin-modal-wide admin-bulk-plan" onClick={(e) => e.stopPropagation()}>
          <h3>Update Audio</h3>

          {["replace", "fill"].map((action) => {
            const items = plan.matches.filter((m) => m.action === action);
            if (items.length === 0 && action === "fill") return null;
            return (
              <div key={action} className="admin-bulk-group">
                <h4>
                  {GROUP_LABEL[action]}{" "}
                  <span className="admin-count">{items.length}</span>
                </h4>
                <ul className="admin-bulk-matches">
                  {items.map((m) => {
                    const flatIndex = previewList.indexOf(m);
                    const active = preview.index === flatIndex;
                    return (
                      <li key={m.signed_id}>
                        <input
                          type="checkbox"
                          className="admin-bulk-check"
                          checked={selected.has(m.signed_id)}
                          onChange={() => toggleSelected(m.signed_id)}
                        />
                        <span className="admin-bulk-position">{m.position}</span>
                        <span className="admin-bulk-title">{m.title}</span>
                        <span className="admin-bulk-preview">
                          <button
                            type="button"
                            className="admin-preview-toggle"
                            aria-label={active && preview.playing ? "Pause" : "Play"}
                            onClick={() => togglePreview(flatIndex)}
                          >
                            <FontAwesomeIcon
                              icon={active && preview.playing ? faPause : faPlay}
                            />
                          </button>
                          {active && (
                            <>
                              <input
                                type="range"
                                className="admin-preview-scrub"
                                min="0"
                                max={(m.duration || 0) / 1000}
                                step="0.1"
                                value={preview.time}
                                onChange={(e) =>
                                  previewEngine.current?.seek(Number(e.target.value))
                                }
                              />
                              <span className="admin-preview-time">
                                {formatDurationTrack(preview.time * 1000)}
                              </span>
                            </>
                          )}
                        </span>
                        <span className="admin-bulk-duration">
                          {m.duration ? formatDurationTrack(m.duration) : ""}
                        </span>
                      </li>
                    );
                  })}
                </ul>
              </div>
            );
          })}

          <div className="admin-bulk-unmatched">
            <h4>
              Unmatched files{" "}
              <span className="admin-count">{plan.unmatched_filenames.length}</span>
            </h4>
            {plan.unmatched_filenames.length > 0 && (
              <ul>
                {plan.unmatched_filenames.map((name) => (
                  <li key={name}>{name}</li>
                ))}
              </ul>
            )}
          </div>

          <div className="admin-bulk-gaps">
            <h4>
              Unmatched tracks{" "}
              <span className="admin-count">{plan.unmatched_tracks.length}</span>
            </h4>
          </div>

          <div className="admin-modal-actions">
            <button type="button" onClick={apply} disabled={busy || selected.size === 0}>
              <FontAwesomeIcon icon={faCheck} /> Apply
            </button>
            <button type="button" onClick={close} disabled={busy}>
              <FontAwesomeIcon icon={faXmark} /> Cancel
            </button>
          </div>
          {busy && (
            <>
              <p className="admin-progress-line">
                <MoonLoader color="#c7c8ca" size={18} /> {status || "Applying files"}
              </p>
              <progress className="admin-progress-bar" max="100" value={progress ?? 0} />
            </>
          )}
          {error && <p className="admin-error">{error}</p>}
        </div>
        </div>
      )}

    </div>
  );
};

export default BulkAudioDrop;
