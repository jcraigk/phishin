import React, { useContext, useEffect, useState } from "react";
import { EditorContext } from "./AdminShowEditor";
import useJobRunner from "./useJobRunner";
import { adminGet, adminPatch, adminPost } from "./adminApi";
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
    {url ? <img src={url} alt={alt} /> : <div className="admin-art-empty">None</div>}
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
        {label}
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
          <button type="button" disabled={busy || prompt.trim() === ""} onClick={submit}>
            {busy ? "Editing..." : "Run paid AI edit"}
          </button>
        </div>
      )}
      {status && <span className="admin-audio-status">{status}</span>}
      {error && <p className="admin-error">{error}</p>}
    </div>
  );
};

const CandidateCard = ({ candidate }) => {
  const { show, reload } = useContext(EditorContext);
  const [zoom, setZoom] = useState("0");
  const { run, busy, status, error } = useJobRunner();

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
            value={zoom}
            disabled={busy}
            onChange={(e) => setZoom(e.target.value)}
          />
        </label>
        <button type="button" disabled={busy} onClick={select}>
          {busy ? "Applying..." : "Select"}
        </button>
      </div>
      <EditControl blobKey={candidate.blob_key} label="AI edit" />
      {status && <span className="admin-audio-status">{status}</span>}
      {error && <p className="admin-error">{error}</p>}
    </ImageCard>
  );
};

const PromptPanel = ({ options }) => {
  const { show, setShow, reload } = useContext(EditorContext);
  const art = show.cover_art;
  const [prompt, setPrompt] = useState(art.prompt || "");
  const [parentId, setParentId] = useState(String(art.parent_show_id ?? ""));
  const [saveError, setSaveError] = useState(null);
  const [saving, setSaving] = useState(false);
  const { run, busy, status, error } = useJobRunner();

  useEffect(() => setPrompt(art.prompt || ""), [art.prompt]);
  useEffect(() => setParentId(String(art.parent_show_id ?? "")), [art.parent_show_id]);

  const patchArt = async (body) => {
    setSaveError(null);
    setSaving(true);
    try {
      setShow(await adminPatch(`/shows/${show.date}`, body));
    } catch (e) {
      setSaveError(e.message);
    } finally {
      setSaving(false);
    }
  };

  const savePrompt = () => {
    if (prompt === (art.prompt || "")) return;
    patchArt({ cover_art_prompt: prompt });
  };

  const saveParent = () => {
    const stored = String(art.parent_show_id ?? "");
    if (parentId === stored) return;
    patchArt({ cover_art_parent_show_id: parentId === "" ? null : Number(parentId) });
  };

  return (
    <section className="admin-art-prompt">
      <div className="admin-field">
        <label htmlFor="admin-art-prompt">Prompt</label>
        <textarea
          id="admin-art-prompt"
          rows={4}
          value={prompt}
          disabled={saving || busy}
          onChange={(e) => setPrompt(e.target.value)}
          onBlur={savePrompt}
        />
      </div>

      <div className="admin-field">
        <label htmlFor="admin-art-hue">Hue</label>
        <select
          id="admin-art-hue"
          value={art.hue ?? ""}
          disabled={saving || busy}
          onChange={(e) => patchArt({ cover_art_hue: e.target.value })}
        >
          <option value="">No hue set</option>
          {options.hues.map((hue) => (
            <option key={hue} value={hue}>
              {hue}
            </option>
          ))}
        </select>
      </div>

      <div className="admin-field">
        <label htmlFor="admin-art-style">Style</label>
        <select
          id="admin-art-style"
          value={art.style ?? ""}
          disabled={saving || busy}
          onChange={(e) => patchArt({ cover_art_style: e.target.value })}
        >
          <option value="">No style set</option>
          {options.styles.map((style) => (
            <option key={style} value={style}>
              {style}
            </option>
          ))}
        </select>
      </div>

      <div className="admin-field">
        <label htmlFor="admin-art-parent">Reuse art from show ID</label>
        <input
          id="admin-art-parent"
          type="number"
          min="1"
          value={parentId}
          disabled={saving || busy}
          onChange={(e) => setParentId(e.target.value)}
          onBlur={saveParent}
        />
      </div>

      <button
        type="button"
        disabled={saving || busy}
        onClick={() => run(() => adminPost(`/shows/${show.date}/cover_art/regenerate_prompt`), () => reload())}
      >
        {busy ? "Regenerating..." : "Regenerate prompt"}
      </button>
      {status && <span className="admin-audio-status">{status}</span>}
      {(error || saveError) && <p className="admin-error">{error || saveError}</p>}
    </section>
  );
};

const GenerateControls = () => {
  const { show, reload } = useContext(EditorContext);
  const [progress, setProgress] = useState(null);
  const [uploadError, setUploadError] = useState(null);
  const { run, busy, status, error } = useJobRunner();

  const generate = () => {
    if (!window.confirm(GENERATE_CONFIRM)) return;
    run(() => adminPost(`/shows/${show.date}/cover_art/generate`), () => reload());
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
        {busy ? "Generating..." : "Generate candidate (paid)"}
      </button>
      <label className="admin-art-upload">
        Upload image
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
      {status && <span className="admin-audio-status">{status}</span>}
      {(error || uploadError) && <p className="admin-error">{error || uploadError}</p>}
    </div>
  );
};

const ArtTab = () => {
  const { show, setError } = useContext(EditorContext);
  const [options, setOptions] = useState(null);
  const art = show.cover_art;

  useEffect(() => {
    adminGet("/cover_art_options")
      .then(setOptions)
      .catch((e) => setError(e.message));
  }, [setError]);

  return (
    <div className="admin-art-tab">
      <section className="admin-art-current">
        <ImageCard url={art.current_url} alt="Current cover art">
          <span>Cover art</span>
          {art.current_blob_key && (
            <EditControl blobKey={art.current_blob_key} label="AI edit current art" />
          )}
        </ImageCard>
        <ImageCard url={art.album_cover_url} alt="Album cover composite">
          <span>Album cover</span>
        </ImageCard>
      </section>

      {options && <PromptPanel options={options} />}

      <GenerateControls />

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

export default ArtTab;
