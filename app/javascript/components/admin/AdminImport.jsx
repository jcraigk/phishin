import React, { useEffect, useRef, useState } from "react";
import { useNavigate, Link } from "react-router";
import { adminPost, adminPatch, pollJob, isPollAbort } from "./adminApi";
import { uploadFile, collectFiles, isStagingSource } from "./DirectUploader";

let nextFileId = 0;

// Two ways in: an archive.org identifier the server fetches itself, or files
// dropped here (a zip, a folder of flacs or mp3s, notes). Either lands in
// lossless staging; the editor takes over from there.
const AdminImport = () => {
  const navigate = useNavigate();
  const [step, setStep] = useState("date");
  const [date, setDate] = useState("");
  const [dateExists, setDateExists] = useState(false);
  const [archiveItem, setArchiveItem] = useState("");
  const [files, setFiles] = useState([]);
  const [dragging, setDragging] = useState(false);
  const [taperNotes, setTaperNotes] = useState("");
  const [jobId, setJobId] = useState(null);
  const [jobStatus, setJobStatus] = useState(null);
  const [starting, setStarting] = useState(false);
  const [error, setError] = useState(null);
  const fileInputRef = useRef(null);

  useEffect(() => {
    if (!jobId) return undefined;
    const controller = new AbortController();

    pollJob(jobId, { onUpdate: setJobStatus, signal: controller.signal })
      .then(() => navigate(`/admin/shows/${date}`))
      .catch((e) => {
        if (!isPollAbort(e)) setError(e.message);
      });

    return () => controller.abort();
  }, [jobId, date, navigate]);

  const createDraft = async () => {
    setError(null);
    setDateExists(false);
    try {
      await adminPost("/shows", { date });
      setStep("upload");
    } catch (e) {
      if (e.status === 409) setDateExists(true);
      else setError(e.message);
    }
  };

  const addFiles = (fileList) => {
    const additions = Array.from(fileList)
      .filter(isStagingSource)
      .map((f) => ({
        id: ++nextFileId,
        file: f,
        name: f.name,
        progress: 0,
        signedId: null,
        failed: false,
      }));
    if (additions.length === 0) return;
    setFiles((prev) => [...prev, ...additions]);

    const updateEntry = (id, changes) => {
      setFiles((prev) =>
        prev.map((f) => (f.id === id ? { ...f, ...changes } : f))
      );
    };

    additions.forEach(async (entry) => {
      try {
        const signedId = await uploadFile(entry.file, (progress) => {
          updateEntry(entry.id, { progress });
        });
        updateEntry(entry.id, { progress: 100, signedId });
      } catch (e) {
        updateEntry(entry.id, { failed: true });
        setError(`${entry.name}: ${e.message}`);
      }
    });
  };

  const uploaded = files.filter((f) => f.signedId);
  const pending = files.some((f) => !f.signedId && !f.failed);
  const item = archiveItem.trim();
  const canProceed = (uploaded.length > 0 || item !== "") && !pending && !starting;

  const proceed = async () => {
    setError(null);
    setStarting(true);
    try {
      if (taperNotes.trim() !== "") {
        await adminPatch(`/shows/${date}`, { taper_notes: taperNotes });
      }
      const { job_id: id } = await adminPost(`/shows/${date}/ingest`, {
        signed_ids: uploaded.map((f) => f.signedId),
        archive_item: item || undefined,
      });
      setStep("ingesting");
      setJobId(id);
    } catch (e) {
      setError(e.message);
    } finally {
      setStarting(false);
    }
  };

  const fileLabel = (f) => {
    if (f.failed) return "failed";
    if (f.signedId) return "uploaded";
    return `${f.progress}%`;
  };

  return (
    <div className="admin-import">
      <h1>Import Show</h1>
      {error && <p className="admin-error">{error}</p>}

      {step === "date" && (
        <div className="admin-import-step">
          <label htmlFor="admin-import-date">Show date</label>
          <input
            id="admin-import-date"
            type="date"
            value={date}
            onChange={(e) => setDate(e.target.value)}
          />
          <button type="button" onClick={createDraft} disabled={!date}>
            Start Import
          </button>
          {dateExists && (
            <p>
              A show already exists for {date}.{" "}
              <Link to={`/admin/shows/${date}`}>Open it in the editor</Link>.
            </p>
          )}
        </div>
      )}

      {step === "upload" && (
        <div className="admin-import-step">
          <h2>{date}</h2>

          <label htmlFor="admin-import-archive">archive.org item</label>
          <input
            id="admin-import-archive"
            type="text"
            placeholder="ph2024-07-19.flac16"
            value={archiveItem}
            onChange={(e) => setArchiveItem(e.target.value)}
          />
          <p className="admin-import-or">or</p>

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
              // The entries the collector reads are cleared once this handler
              // returns, so capture the transfer before the first await.
              const { dataTransfer } = e;
              collectFiles(dataTransfer, isStagingSource)
                .then(addFiles)
                .catch((err) => setError(err.message));
            }}
          >
            <p>Drop a zip, a show folder, or audio files (flac, shn, wav, mp3) and notes here, or</p>
            <input
              ref={fileInputRef}
              type="file"
              accept=".zip,.rar,.7z,.flac,.shn,.wav,.aiff,.mp3,.txt"
              multiple
              onChange={(e) => {
                addFiles(e.target.files);
                // Allow re-selecting the same filename after a failed upload
                if (fileInputRef.current) fileInputRef.current.value = "";
              }}
            />
          </div>

          {files.length > 0 && (
            <ul className="admin-file-list">
              {files.map((f) => (
                <li key={f.id} className={f.failed ? "admin-error" : undefined}>
                  <span className="admin-file-name">{f.name}</span>
                  <span className="admin-file-status">{fileLabel(f)}</span>
                </li>
              ))}
            </ul>
          )}

          <label htmlFor="admin-import-notes">Taper notes</label>
          <textarea
            id="admin-import-notes"
            rows={6}
            placeholder="Left blank, notes come from the upload's text file or the archive.org description."
            value={taperNotes}
            onChange={(e) => setTaperNotes(e.target.value)}
          />

          <button type="button" onClick={proceed} disabled={!canProceed}>
            Stage Show
          </button>
        </div>
      )}

      {step === "ingesting" && (
        <div className="admin-import-step">
          <h2>Staging {date}</h2>
          <progress max="100" value={jobStatus?.progress ?? 0} />
          <p>{jobStatus?.message}</p>
        </div>
      )}
    </div>
  );
};

export default AdminImport;
