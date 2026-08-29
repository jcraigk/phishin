import React, { useEffect, useRef, useState } from "react";
import { useNavigate, useSearchParams, Link } from "react-router";
import { FontAwesomeIcon } from "@fortawesome/react-fontawesome";
import { faCloudArrowUp, faPenToSquare } from "@fortawesome/free-solid-svg-icons";
import { adminGet, adminPost, adminPatch, pollJob, isPollAbort } from "./adminApi";
import { uploadFile, collectFiles, isStagingSource } from "./DirectUploader";

let nextFileId = 0;

const FIRST_YEAR = 1983;

const formatDuration = (ms) => {
  const total = Math.round(ms / 1000);
  const hours = Math.floor(total / 3600);
  const minutes = Math.floor((total % 3600) / 60);
  return hours > 0 ? `${hours}h ${minutes}m` : `${minutes}m`;
};
const YEARS = [];
for (let y = new Date().getFullYear(); y >= FIRST_YEAR; y -= 1) YEARS.push(y);

// One page for every show, existing or not. A date that already has tracks
// opens the editor; a date with none (new, or a draft that never got audio)
// goes through staging first, and lands in the same editor when that finishes.
// Import is not a separate mode, just the step a show without audio starts on.
const AdminImport = () => {
  const navigate = useNavigate();
  const [params, setParams] = useSearchParams();
  const [date, setDate] = useState(params.get("date") || "");
  const [lookup, setLookup] = useState(null);
  const [year, setYear] = useState(String(params.get("year") || YEARS[0]));
  const [shows, setShows] = useState(null);
  const [step, setStep] = useState("pick");
  const [archiveItem, setArchiveItem] = useState("");
  const [files, setFiles] = useState([]);
  const [dragging, setDragging] = useState(false);
  const [taperNotes, setTaperNotes] = useState("");
  const [jobId, setJobId] = useState(null);
  const [jobStatus, setJobStatus] = useState(null);
  const [starting, setStarting] = useState(false);
  const [error, setError] = useState(null);
  const fileInputRef = useRef(null);

  // Whether the typed date already exists, and whether it has audio yet.
  useEffect(() => {
    if (!/^\d{4}-\d{2}-\d{2}$/.test(date)) {
      setLookup(null);
      return undefined;
    }
    let cancelled = false;
    adminGet(`/shows/${date}`)
      .then((show) => {
        if (!cancelled) setLookup({ exists: true, show });
      })
      .catch((e) => {
        if (cancelled) return;
        if (e.status === 404) setLookup({ exists: false });
        else setError(e.message);
      });
    return () => {
      cancelled = true;
    };
  }, [date]);

  useEffect(() => {
    let cancelled = false;
    setShows(null);
    adminGet(`/shows?year=${year}`)
      .then((data) => {
        if (!cancelled) setShows(data.shows);
      })
      .catch((e) => {
        if (!cancelled) setError(e.message);
      });
    return () => {
      cancelled = true;
    };
  }, [year]);

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

  const chooseYear = (value) => {
    setYear(value);
    setParams((prev) => {
      const next = new URLSearchParams(prev);
      next.set("year", value);
      return next;
    });
  };

  const hasAudio = lookup?.exists && lookup.show.tracks_count > 0;
  const needsStaging = lookup && (!lookup.exists || lookup.show.tracks_count === 0);

  const proceedToShow = async () => {
    setError(null);
    if (hasAudio) {
      navigate(`/admin/shows/${date}`);
      return;
    }
    try {
      if (!lookup.exists) await adminPost("/shows", { date });
      setStep("upload");
    } catch (e) {
      setError(e.message);
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
  const canStage = (uploaded.length > 0 || item !== "") && !pending && !starting;

  const stage = async () => {
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

  const lookupNote = () => {
    if (!lookup) return null;
    if (!lookup.exists) return "New date. Audio is staged before the show exists.";
    if (lookup.show.tracks_count === 0) return "Exists without audio. Stage audio to continue.";
    return `${lookup.show.venue_name || "Venue not set"}, ${lookup.show.tracks_count} tracks${lookup.show.published ? "" : ", draft"}.`;
  };

  return (
    <div className="admin-import">
      {error && <p className="admin-error">{error}</p>}

      {step === "pick" && (
        <>
          <section className="admin-card">
            <header className="admin-card-header">
              <h2>Open or Import a Show</h2>
            </header>
            <div className="admin-card-body">
              <div className="admin-pick-row">
                <label htmlFor="admin-import-date">Show date</label>
                <input
                  id="admin-import-date"
                  type="date"
                  value={date}
                  onChange={(e) => setDate(e.target.value)}
                />
                <button type="button" onClick={proceedToShow} disabled={!lookup}>
                  <FontAwesomeIcon icon={hasAudio ? faPenToSquare : faCloudArrowUp} />{" "}
                  {hasAudio ? "Edit Show" : "Import Audio"}
                </button>
                <span className="admin-pick-note">{lookupNote()}</span>
              </div>
            </div>
          </section>

          <section className="admin-card">
            <header className="admin-card-header">
              <h2>Browse</h2>
              <select value={year} onChange={(e) => chooseYear(e.target.value)}>
                {YEARS.map((y) => <option key={y} value={y}>{y}</option>)}
              </select>
            </header>
            <div className="admin-card-body">
              {shows === null ? (
                <p className="admin-empty">Loading</p>
              ) : shows.length === 0 ? (
                <p className="admin-empty">No shows in {year}.</p>
              ) : (
                <ul className="admin-draft-list">
                  {shows.map((show) => (
                    <li
                      key={show.id}
                      className="admin-show-row"
                      onClick={() => navigate(`/admin/shows/${show.date}`)}
                    >
                      <img className="admin-show-art" src={show.cover_art_url} alt="" loading="lazy" />
                      <Link className="admin-draft-date" to={`/admin/shows/${show.date}`}>{show.date}</Link>
                      <span className="admin-draft-venue">{show.venue_name || "Venue not set"}</span>
                      <span className="admin-show-tags">
                        {show.tags.map((tag) => <span key={tag} className="admin-tag-chip">{tag}</span>)}
                      </span>
                      <span className="admin-show-status">
                        {!show.published && <span className="admin-pill">draft</span>}
                        <span className={`admin-pill is-${show.audio_status}`}>{show.audio_status}</span>
                      </span>
                      <span className="admin-show-meta">
                        {show.tracks_count} {show.tracks_count === 1 ? "track" : "tracks"}
                      </span>
                      <span className="admin-show-meta">
                        {show.duration > 0 ? formatDuration(show.duration) : ""}
                      </span>
                    </li>
                  ))}
                </ul>
              )}
            </div>
          </section>
        </>
      )}

      {step === "upload" && needsStaging && (
        <section className="admin-card">
          <header className="admin-card-header">
            <h2>Stage audio for {date}</h2>
            <button type="button" onClick={() => setStep("pick")}>Back</button>
          </header>
          <div className="admin-card-body admin-import-step">
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

            <label htmlFor="admin-import-notes">Taper notes</label>
            <textarea
              id="admin-import-notes"
              rows={6}
              placeholder="Left blank, notes come from the upload's text file or the archive.org description."
              value={taperNotes}
              onChange={(e) => setTaperNotes(e.target.value)}
            />

            <button type="button" onClick={stage} disabled={!canStage}>
              <FontAwesomeIcon icon={faCloudArrowUp} /> Stage Audio
            </button>
          </div>
        </section>
      )}

      {step === "ingesting" && (
        <section className="admin-card">
          <header className="admin-card-header">
            <h2>Staging {date}</h2>
          </header>
          <div className="admin-card-body admin-import-step">
            <progress max="100" value={jobStatus?.progress ?? 0} />
            <p>{jobStatus?.message}</p>
          </div>
        </section>
      )}
    </div>
  );
};

export default AdminImport;
