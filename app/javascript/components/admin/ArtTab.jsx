import React, { useContext, useEffect, useState } from "react";
import MoonLoader from "react-spinners/MoonLoader";
import { FontAwesomeIcon } from "@fortawesome/react-fontawesome";
import {
  faArrowsRotate,
  faCheck,
  faCloudArrowUp,
  faTrashCan,
} from "@fortawesome/free-solid-svg-icons";
import { faSparkles } from "./sparklesIcon";
import { EditorContext } from "./AdminShowEditor";
import useJobRunner from "./useJobRunner";
import { adminDelete, adminGet, adminPatch, adminPost } from "./adminApi";
import { uploadFile } from "./DirectUploader";

const SELECT_CONFIRM =
  "Sets cover art, composites the album cover, and re-embeds ID3 tags on all tracks. Continue?";

const GENERATE_CONFIRM =
  "Generating an image calls the paid image API and bills your account. Continue?";

const EDIT_CONFIRM =
  "An AI edit calls the paid image API and bills your account. Continue?";

// Candidate and cover art images come from the public /blob/:key and cover art
// variant routes, so a plain img tag works: no auth header, no object URLs.
const ImageCard = ({ url, alt, children }) => (
  <figure className="admin-art-card">
    {url ? (
      <a href={url} target="_blank" rel="noreferrer" title="Open full size">
        <img src={url} alt={alt} />
      </a>
    ) : (
      <div className="admin-art-empty">None</div>
    )}
    <figcaption>{children}</figcaption>
  </figure>
);

const EditControl = ({ blobKey, label }) => {
  const { show, reload } = useContext(EditorContext);
  const [open, setOpen] = useState(false);
  const [prompt, setPrompt] = useState("");
  const { run, busy, status, error } = useJobRunner();

  const submit = () => {
    if (prompt.trim() === "") return;
    if (!window.confirm(EDIT_CONFIRM)) return;
    run(
      () =>
        adminPost(`/shows/${show.date}/cover_art/ai_edit`, {
          source_blob_key: blobKey,
          edit_prompt: prompt.trim(),
        }),
      async () => {
        setPrompt("");
        setOpen(false);
        await reload();
      }
    );
  };

  return (
    <div className="admin-art-edit">
      <button
        type="button"
        className={open ? "active" : ""}
        disabled={busy}
        onClick={() => setOpen(!open)}
      >
        <FontAwesomeIcon icon={faSparkles} /> {label}
      </button>
      {open && (
        <div className="admin-art-edit-form">
          <input
            type="text"
            placeholder="Describe the edit"
            value={prompt}
            disabled={busy}
            onChange={(e) => setPrompt(e.target.value)}
          />
          <button
            type="button"
            title="Run paid AI edit"
            disabled={busy || prompt.trim() === ""}
            onClick={submit}
          >
            <FontAwesomeIcon icon={faCheck} />
          </button>
        </div>
      )}
      {busy ? (
        <span className="admin-art-busy">
          <MoonLoader color="#c7c8ca" size={18} /> {status || "Generating"}
        </span>
      ) : (
        status && <span className="admin-audio-status">{status}</span>
      )}
      {error && <p className="admin-error">{error}</p>}
    </div>
  );
};

const CandidateCard = ({ candidate }) => {
  const { show, reload, setError } = useContext(EditorContext);
  const [zoom, setZoom] = useState("0");
  const [removing, setRemoving] = useState(false);
  const { run, busy, status, error } = useJobRunner();

  const remove = async () => {
    if (!window.confirm("Remove this candidate?")) return;
    setRemoving(true);
    try {
      await adminDelete(
        `/shows/${show.date}/cover_art/candidates?blob_key=${encodeURIComponent(candidate.blob_key)}`
      );
      await reload();
    } catch (e) {
      setError(e.message);
      setRemoving(false);
    }
  };

  const select = () => {
    if (!window.confirm(SELECT_CONFIRM)) return;
    run(
      () =>
        adminPost(`/shows/${show.date}/cover_art/select`, {
          blob_key: candidate.blob_key,
          zoom: Number(zoom) || 0,
        }),
      () => reload()
    );
  };

  return (
    <ImageCard url={candidate.url} alt="Cover art candidate">
      <div className="admin-art-actions">
        <label>
          Zoom %
          <input
            type="number"
            min="0"
            max="50"
            step="1"
            value={zoom}
            disabled={busy}
            onChange={(e) => {
              const digits = e.target.value.replace(/\D/g, "");
              setZoom(digits === "" ? "" : String(Math.min(50, parseInt(digits, 10))));
            }}
          />
        </label>
      </div>
      <div className="admin-art-actions">
        <button type="button" disabled={busy || removing} onClick={select}>
          <FontAwesomeIcon icon={faCheck} /> {busy ? "Applying..." : "Select"}
        </button>
        <EditControl blobKey={candidate.blob_key} label="Edit" />
        <button
          type="button"
          className="admin-trash-button"
          aria-label="Remove candidate"
          title="Remove candidate"
          disabled={busy || removing}
          onClick={remove}
        >
          <FontAwesomeIcon icon={faTrashCan} />
        </button>
      </div>
      {status && <span className="admin-audio-status">{status}</span>}
      {error && <p className="admin-error">{error}</p>}
    </ImageCard>
  );
};

const PromptPanel = ({ draft, setDraft }) => {
  const { show } = useContext(EditorContext);
  const [suggestions, setSuggestions] = useState(null);
  const { run, busy, status, error } = useJobRunner();

  const suggest = () =>
    run(
      () => adminPost(`/shows/${show.date}/cover_art/regenerate_prompt`),
      (job) => {
        if (job?.payload?.prompt) setDraft(job.payload.prompt);
        setSuggestions(job?.payload?.suggestions || null);
      }
    );

  const append = (text) =>
    setDraft((prev) => (prev.trim() === "" ? text : `${prev.trim()} ${text}`));

  return (
    <section className="admin-art-prompt">
      <div className="admin-field">
        <textarea
          id="admin-art-prompt"
          aria-label="Prompt for a new image"
          placeholder="Prompt for a new image"
          rows={3}
          value={draft}
          disabled={busy}
          onChange={(e) => setDraft(e.target.value)}
        />
      </div>
      <button type="button" disabled={busy} onClick={suggest}>
        <FontAwesomeIcon icon={faArrowsRotate} /> {busy ? "Suggesting..." : "Suggest prompt"}
      </button>
      {suggestions && (
        <dl className="admin-art-suggestions">
          {Object.entries(suggestions).map(([category, items]) => (
            <div key={category}>
              <dt>{category.replace(/_/g, " ")}</dt>
              <dd>
                {items.map((item) => (
                  <button key={item} type="button" onClick={() => append(item)}>
                    {item}
                  </button>
                ))}
              </dd>
            </div>
          ))}
        </dl>
      )}
      {status && <span className="admin-audio-status">{status}</span>}
      {error && <p className="admin-error">{error}</p>}
    </section>
  );
};

const GenerateControls = ({ draft }) => {
  const { show, reload } = useContext(EditorContext);
  const [progress, setProgress] = useState(null);
  const [uploadError, setUploadError] = useState(null);
  const { run, busy, status, error } = useJobRunner();

  const generate = () => {
    if (!window.confirm(GENERATE_CONFIRM)) return;
    const body = draft.trim() === "" ? {} : { prompt: draft.trim() };
    run(() => adminPost(`/shows/${show.date}/cover_art/generate`, body), () => reload());
  };

  const upload = async (file) => {
    if (!file) return;
    setUploadError(null);
    setProgress(0);
    try {
      const signedId = await uploadFile(file, setProgress);
      await adminPost(`/shows/${show.date}/cover_art/upload`, { signed_id: signedId });
      await reload();
    } catch (e) {
      setUploadError(e.message);
    } finally {
      setProgress(null);
    }
  };

  const uploading = progress !== null;

  return (
    <div className="admin-art-controls">
      <button type="button" disabled={busy || uploading} onClick={generate}>
        <FontAwesomeIcon icon={faSparkles} /> {busy ? "Generating..." : "Generate"}
      </button>
      <label className="admin-art-upload">
        <FontAwesomeIcon icon={faCloudArrowUp} /> Upload image
        <input
          type="file"
          accept="image/*"
          disabled={busy || uploading}
          onChange={(e) => {
            const file = e.target.files[0];
            // Allow re-selecting the same filename after a failed upload
            e.target.value = "";
            upload(file);
          }}
        />
      </label>
      {uploading && <progress max="100" value={progress} />}
      {busy ? (
        <span className="admin-art-busy">
          <MoonLoader color="#c7c8ca" size={18} /> {status || "Generating"}
        </span>
      ) : (
        status && <span className="admin-audio-status">{status}</span>
      )}
      {(error || uploadError) && <p className="admin-error">{error || uploadError}</p>}
    </div>
  );
};

const ArtImage = ({ url, alt }) =>
  url ? (
    <a href={url} target="_blank" rel="noreferrer" title="Open full size">
      <img src={url} alt={alt} />
    </a>
  ) : (
    <div className="admin-art-empty">None</div>
  );

const ArtEditor = ({ runNote }) => {
  const { show } = useContext(EditorContext);
  const [draft, setDraft] = useState("");
  const art = show.cover_art;
  const note =
    runNote ||
    ((art.child_dates || []).length > 0
      ? `This art is shared with a run. Applying a candidate also updates ${art.child_dates.join(", ")}.`
      : null);

  return (
    <div className="admin-art-tab">
      {note && <p className="admin-run-note">{note}</p>}

      <section className="admin-art-current">
        <div className="admin-art-pair">
          <ArtImage url={art.current_url} alt="Current cover art" />
          <ArtImage url={art.album_cover_url} alt="Album cover composite" />
        </div>
        {art.prompt && <p className="admin-art-snapshot">{art.prompt}</p>}
        {art.current_blob_key && (
          <EditControl blobKey={art.current_blob_key} label="Edit" />
        )}
      </section>

      <PromptPanel draft={draft} setDraft={setDraft} />

      <GenerateControls draft={draft} />

      <h3>Candidates</h3>
      {art.candidates.length === 0 ? (
        <p>No candidates yet. Generate or upload one.</p>
      ) : (
        <div className="admin-art-grid">
          {art.candidates.map((candidate) => (
            <CandidateCard key={candidate.blob_key} candidate={candidate} />
          ))}
        </div>
      )}
    </div>
  );
};

// A show in a run defers its art to the run's first show, so the tab edits the
// parent's art in place; selecting a candidate there propagates to all children.
const ParentArtEditor = ({ parentDate }) => {
  const outer = useContext(EditorContext);
  const [parentShow, setParentShow] = useState(null);

  const load = async () => {
    try {
      setParentShow(await adminGet(`/shows/${parentDate}`));
    } catch (e) {
      outer.setError(e.message);
    }
  };

  useEffect(() => {
    load();
  }, [parentDate]);

  if (!parentShow) return null;

  return (
    <EditorContext.Provider
      value={{
        show: parentShow,
        setShow: setParentShow,
        setError: outer.setError,
        reload: async () => {
          await load();
          await outer.reload();
        },
      }}
    >
      <ArtEditor
        runNote={`This show is part of a run that shares cover art. You are editing the run's art (kept on ${parentDate}); applying a candidate updates every show in the run.`}
      />
    </EditorContext.Provider>
  );
};

const ArtTab = () => {
  const { show } = useContext(EditorContext);
  const parentDate = show.cover_art.parent_show_date;
  if (parentDate) return <ParentArtEditor parentDate={parentDate} />;
  return <ArtEditor />;
};

export default ArtTab;
