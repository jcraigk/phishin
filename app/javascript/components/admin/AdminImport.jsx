import React, { useRef, useState } from "react";
import { useNavigate } from "react-router";
import { FontAwesomeIcon } from "@fortawesome/react-fontawesome";
import { faCloudArrowUp } from "@fortawesome/free-solid-svg-icons";
import { adminPost } from "./adminApi";
import IngestProgress from "./IngestProgress";
import { uploadFile, collectFiles, isStagingSource } from "./DirectUploader";

let nextFileId = 0;

// Brings new audio into the catalog: paste an archive.org URL, or drop a
// folder of files. The show date comes from the item metadata or the taper
// notes in the upload, never from a picker. Audio is staged in the background
// and the show editor opens when staging lands.
// The archive.org item name, taken from the pasted URL so the progress card
// can be titled before the job reports anything.
const archiveItemName = (url) => {
  const match = url.trim().match(/archive\.org\/(?:details|download)\/([^/?#]+)/);
  return match ? match[1] : url.trim();
};

const AdminImport = () => {
  const navigate = useNavigate();
  const [step, setStep] = useState("pick");
  const [date, setDate] = useState("");
  const [archiveUrl, setArchiveUrl] = useState("");
  const [source, setSource] = useState("");
  const [files, setFiles] = useState([]);
  const [dragging, setDragging] = useState(false);
  const [jobId, setJobId] = useState(null);
  const [starting, setStarting] = useState(false);
  const [error, setError] = useState(null);
  const fileInputRef = useRef(null);

  // One paste does everything: the server reads the show date off the item,
  // creates the draft if needed, and stages the lossless files in the
  // background with the item description as taper notes.
  const importFromArchive = async () => {
    setError(null);
    setStarting(true);
    try {
      setSource(archiveItemName(archiveUrl));
      const res = await adminPost("/shows/archive_import", { url: archiveUrl.trim() });
      setDate(res.date);
      setStep("ingesting");
      setJobId(res.job_id);
    } catch (e) {
      setError(e.message);
    } finally {
      setStarting(false);
    }
  };

  // Same idea for a dropped folder: the server reads the date out of the
  // taper notes (or the filenames) and stages from there.
  const importFromUpload = async () => {
    setError(null);
    setStarting(true);
    try {
      setSource("uploaded files");
      const res = await adminPost("/shows/upload_import", {
        signed_ids: uploaded.map((f) => f.signedId),
      });
      setDate(res.date);
      setStep("ingesting");
      setJobId(res.job_id);
    } catch (e) {
      setError(e.message);
    } finally {
      setStarting(false);
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
  const canStage = uploaded.length > 0 && !pending && !starting;

  const fileLabel = (f) => {
    if (f.failed) return "failed";
    if (f.signedId) return "uploaded";
    return `${f.progress}%`;
  };

  return (
    <div className="admin-import">
      {error && <p className="admin-error">{error}</p>}

      {step === "pick" && (
        <section className="admin-card">
          <header className="admin-card-header">
            <h2>Import Show</h2>
          </header>
          <div className="admin-card-body admin-import-step">
            <label htmlFor="admin-import-archive-url">Archive.org URL</label>
            <input
              id="admin-import-archive-url"
              type="text"
              placeholder="https://archive.org/details/..."
              value={archiveUrl}
              onChange={(e) => setArchiveUrl(e.target.value)}
              onKeyDown={(e) => {
                if (e.key === "Enter" && archiveUrl.trim() !== "" && !starting) {
                  importFromArchive();
                }
              }}
            />
            <button
              type="button"
              onClick={importFromArchive}
              disabled={archiveUrl.trim() === "" || starting}
            >
              <FontAwesomeIcon icon={faCloudArrowUp} /> Import
            </button>

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
              <p>Drop a zip, a show folder, or audio files (flac, shn, wav, mp3) and taper notes here, or</p>
              <input
                ref={fileInputRef}
                type="file"
                accept=".zip,.rar,.7z,.tar,.tgz,.flac,.shn,.wav,.aiff,.mp3,.txt"
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

            <button type="button" onClick={importFromUpload} disabled={!canStage}>
              <FontAwesomeIcon icon={faCloudArrowUp} /> Import Show
            </button>
          </div>
        </section>
      )}

      {step === "ingesting" && (
        <IngestProgress
          jobId={jobId}
          title={source}
          onDone={() => navigate(`/admin/shows/${date}`)}
          onCancelled={() => {
            setJobId(null);
            setStep("pick");
          }}
          onError={(message) => {
            setError(message);
            setJobId(null);
            setStep("pick");
          }}
        />
      )}
    </div>
  );
};

export default AdminImport;
