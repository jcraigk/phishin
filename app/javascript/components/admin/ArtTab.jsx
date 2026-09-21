import React, { useContext, useEffect, useRef, useState } from "react";
import Spinner from "./Spinner";
import { FontAwesomeIcon } from "@fortawesome/react-fontawesome";
import {
  faCheck,
  faCloudArrowUp,
  faPencil,
  faPlus,
  faTrashCan,
  faXmark,
} from "@fortawesome/free-solid-svg-icons";
import { faSparkles } from "./sparklesIcon";
import { EditorContext } from "./AdminShowEditor";
import useJobRunner from "./useJobRunner";
import { adminDelete, adminGet, adminPost, pollJob } from "./adminApi";
import { uploadFile } from "./DirectUploader";
import { formatDate } from "../helpers/utils";
import Modal from "./Modal";

const SELECT_CONFIRM =
  "Sets cover art, composites the album cover, and re-embeds ID3 tags on all tracks. Continue?";

const modelLabel = (id) => (id ? id.split("/").pop() : "");

const ModelSelect = ({ value, onChange, disabled }) => {
  const { show } = useContext(EditorContext);
  const models = show.cover_art.image_models || [];
  return (
    <select
      className="admin-art-model-select"
      aria-label="Image model"
      title="Image model"
      value={value}
      disabled={disabled}
      onChange={(e) => onChange(e.target.value)}
    >
      {models.map((id) => (
        <option key={id} value={id}>
          {modelLabel(id)}
        </option>
      ))}
    </select>
  );
};

const ModelBadge = ({ model }) =>
  model ? (
    <span className="admin-art-model" title={model}>
      {modelLabel(model)}
    </span>
  ) : null;

const ImageCard = ({ url, alt, imgStyle, children }) => (
  <figure className="admin-art-card">
    {url ? (
      <a
        href={url}
        target="_blank"
        rel="noreferrer"
        title="Open full size"
        className="admin-art-frame"
      >
        <img src={url} alt={alt} style={imgStyle} />
      </a>
    ) : (
      <div className="admin-art-empty">None</div>
    )}
    <figcaption>{children}</figcaption>
  </figure>
);

const EditControl = ({
  blobKey,
  label,
  provenance,
  onPendingStart,
  onPendingEnd,
}) => {
  const { show, reload, setError } = useContext(EditorContext);
  const [open, setOpen] = useState(false);
  const [prompt, setPrompt] = useState("");
  const [model, setModel] = useState(show.cover_art.default_image_model);

  const submit = async () => {
    if (prompt.trim() === "") return;
    const text = prompt.trim();
    setPrompt("");
    setOpen(false);
    const pendingId = `${blobKey}-${Date.now()}`;
    onPendingStart({
      id: pendingId,
      basePrompt: provenance?.basePrompt || null,
      edits: [...(provenance?.edits || []), text],
    });
    try {
      const { job_id: jobId } = await adminPost(
        `/shows/${show.date}/cover_art/ai_edit`,
        { source_blob_key: blobKey, edit_prompt: text, model }
      );
      await pollJob(jobId);
      await reload();
    } catch (e) {
      setError(e.message);
    } finally {
      onPendingEnd(pendingId);
    }
  };

  return (
    <div className="admin-art-edit">
      <button
        type="button"
        className={open ? "active" : ""}
        title="AI edit"
        onClick={() => setOpen(!open)}
      >
        <FontAwesomeIcon icon={faPencil} />
        {label ? <> {label}</> : null}
      </button>
      {open && (
        <div className="admin-art-edit-form">
          <input
            type="text"
            placeholder="Describe the edit"
            autoFocus
            value={prompt}
            onChange={(e) => setPrompt(e.target.value)}
            onKeyDown={(e) => {
              if (e.key === "Enter") submit();
            }}
          />
          <ModelSelect value={model} onChange={setModel} />
          <button
            type="button"
            title="Run paid AI edit"
            disabled={prompt.trim() === ""}
            onClick={submit}
          >
            <FontAwesomeIcon icon={faCheck} />
          </button>
        </div>
      )}
    </div>
  );
};

const CandidateCard = ({ candidate, onPendingStart, onPendingEnd }) => {
  const { show, reload, setError } = useContext(EditorContext);
  const [zoom, setZoom] = useState("0");
  const [removing, setRemoving] = useState(false);
  const { run, busy, status, error } = useJobRunner();

  const zoomFactor = Math.min(50, Number(zoom) || 0) / 100;
  const imgStyle =
    zoomFactor > 0
      ? { transform: `scale(${(1 / (1 - zoomFactor)).toFixed(4)})` }
      : undefined;

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

  const trailParts = (candidate.prompt || "").split(/\s*\|\s*edit:\s*/);
  const basePrompt = trailParts[0] || null;
  const edits =
    (candidate.edits || []).length > 0 ? candidate.edits : trailParts.slice(1);

  return (
    <ImageCard url={candidate.url} alt="Cover art candidate" imgStyle={imgStyle}>
      <div className="admin-art-origin">
        {basePrompt ? (
          <>
            <p title={basePrompt}>{basePrompt}</p>
            {edits.map((edit, index) => (
              <p key={index} className="admin-art-origin-edit" title={edit}>
                Edit {index + 1}: {edit}
              </p>
            ))}
          </>
        ) : (
          <p>Uploaded</p>
        )}
      </div>
      <div className="admin-art-actions">
        <label className="admin-zoom-label">
          Zoom
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
        <ModelBadge model={candidate.model} />
        {candidate.cost != null && (
          <span className="admin-art-cost" title="Generation cost">
            ${Number(candidate.cost).toFixed(2)}
          </span>
        )}
      </div>
      <div className="admin-art-actions">
        <button
          type="button"
          title="Select as cover art"
          aria-label="Select as cover art"
          disabled={busy || removing}
          onClick={select}
        >
          <FontAwesomeIcon icon={faCheck} />
        </button>
        <EditControl
          blobKey={candidate.blob_key}
          label=""
          provenance={{ basePrompt, edits }}
          onPendingStart={onPendingStart}
          onPendingEnd={onPendingEnd}
        />
        <button
          type="button"
          aria-label="Remove candidate"
          title="Remove candidate"
          disabled={busy || removing}
          onClick={remove}
        >
          <FontAwesomeIcon icon={faTrashCan} />
        </button>
      </div>
      {busy && (
        <span className="admin-art-busy">
          <Spinner size={18} /> {status || "Applying..."}
        </span>
      )}
      {error && <p className="admin-error">{error}</p>}
    </ImageCard>
  );
};

const SUGGESTIONS_PER_CATEGORY = 5;

const NewPromptModal = ({ onClose, onSubmit }) => {
  const { show } = useContext(EditorContext);
  const [draft, setDraft] = useState(show.cover_art.prompt || "");
  const [model, setModel] = useState(show.cover_art.default_image_model);
  const [suggestions, setSuggestions] = useState(null);
  const { run, busy, error } = useJobRunner();

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
    <Modal title="New Prompt" wide>
      <textarea
        aria-label="Prompt for a new image"
        placeholder="Prompt for a new image"
        rows={2}
        value={draft}
        disabled={busy}
        onChange={(e) => setDraft(e.target.value)}
      />
      {error && <p className="admin-error">{error}</p>}
      <div className="admin-modal-actions">
        <ModelSelect value={model} onChange={setModel} disabled={busy} />
        <button
          type="button"
          disabled={busy || draft.trim() === ""}
          onClick={() => onSubmit(draft.trim(), model)}
        >
          <FontAwesomeIcon icon={faCheck} /> Submit
        </button>
        <button type="button" disabled={busy} onClick={suggest}>
          <FontAwesomeIcon icon={faSparkles} /> {draft.trim() ? "Regenerate prompt" : "Generate prompt"}
        </button>
        <button type="button" disabled={busy} onClick={onClose}>
          <FontAwesomeIcon icon={faXmark} /> Cancel
        </button>
        {busy && (
          <span className="admin-art-busy">
            <Spinner size={18} /> Generating...
          </span>
        )}
      </div>
      {suggestions && (
        <dl className="admin-art-suggestions">
          {Object.entries(suggestions).map(([category, items]) => (
            <div key={category}>
              <dt>{category.replace(/_/g, " ")}</dt>
              <dd>
                {items.slice(0, SUGGESTIONS_PER_CATEGORY).map((item) => (
                  <button key={item} type="button" onClick={() => append(item)}>
                    {item}
                  </button>
                ))}
              </dd>
            </div>
          ))}
        </dl>
      )}
    </Modal>
  );
};

const GenerateControls = ({ onGenerate }) => {
  const { show, reload } = useContext(EditorContext);
  const [modalOpen, setModalOpen] = useState(false);
  const [progress, setProgress] = useState(null);
  const [uploadError, setUploadError] = useState(null);

  const generate = (prompt, model) => {
    setModalOpen(false);
    onGenerate(prompt, model);
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
  const fileRef = useRef(null);

  return (
    <div className="admin-art-controls">
      <button type="button" disabled={uploading} title="New image from a prompt" aria-label="New image from a prompt" onClick={() => setModalOpen(true)}>
        <FontAwesomeIcon icon={faPlus} />
      </button>
      <button type="button" disabled={uploading} title="Upload an image" aria-label="Upload an image" onClick={() => fileRef.current?.click()}>
        <FontAwesomeIcon icon={faCloudArrowUp} />
      </button>
      <input
        ref={fileRef}
        type="file"
        accept="image/*"
        hidden
        onChange={(e) => {
          const file = e.target.files[0];
          e.target.value = "";
          upload(file);
        }}
      />
      {uploading && <progress max="100" value={progress} />}
      {uploadError && <p className="admin-error">{uploadError}</p>}
      {modalOpen && (
        <NewPromptModal onClose={() => setModalOpen(false)} onSubmit={generate} />
      )}
    </div>
  );
};

const ArtImage = ({ url, alt, emptyLabel }) =>
  url ? (
    <a href={url} target="_blank" rel="noreferrer" title="Open full size">
      <img src={url} alt={alt} />
    </a>
  ) : (
    <div className="admin-art-empty admin-art-empty-square">{emptyLabel}</div>
  );

const PendingCard = ({ basePrompt, edits, label }) => (
  <figure className="admin-art-card admin-art-pending">
    <div className="admin-art-empty">
      <Spinner size={28} />
      <span>{label}</span>
    </div>
    <figcaption>
      <div className="admin-art-origin">
        {basePrompt && <p title={basePrompt}>{basePrompt}</p>}
        {(edits || []).map((edit, index) => (
          <p key={index} className="admin-art-origin-edit" title={edit}>
            Edit {index + 1}: {edit}
          </p>
        ))}
      </div>
    </figcaption>
  </figure>
);

const ArtEditor = ({ runNote }) => {
  const { show, reload, setError } = useContext(EditorContext);
  const [pendingJobs, setPendingJobs] = useState([]);
  const art = show.cover_art;
  const note =
    runNote ||
    ((art.child_dates || []).length > 0
      ? `This art is shared with a run. Applying a candidate also updates ${art.child_dates.join(", ")}.`
      : null);

  const currentParts = (art.prompt || "").split(/\s*\|\s*edit:\s*/);

  const removePending = (id) =>
    setPendingJobs((prev) => prev.filter((p) => p.id !== id));
  const startPendingEdit = (entry) =>
    setPendingJobs((prev) => [...prev, { ...entry, label: "Generating..." }]);

  const generate = async (prompt, model) => {
    const id = `gen-${Date.now()}-${Math.random().toString(16).slice(2)}`;
    setPendingJobs((prev) => [
      ...prev,
      { id, basePrompt: prompt || art.prompt, edits: [], label: "Generating..." },
    ]);
    try {
      const { job_id: jobId } = await adminPost(
        `/shows/${show.date}/cover_art/generate`,
        { ...(prompt ? { prompt } : {}), ...(model ? { model } : {}) }
      );
      await pollJob(jobId);
      await reload();
    } catch (e) {
      setError(e.message);
    } finally {
      removePending(id);
    }
  };

  const showGrid = art.candidates.length > 0 || pendingJobs.length > 0;

  return (
    <div className="admin-art-tab">
      {note && <p className="admin-run-note">{note}</p>}

      <section className="admin-art-current">
        <div className="admin-art-pair">
          <ArtImage url={art.current_url} alt="Current cover art" emptyLabel="No cover art" />
          <ArtImage url={art.album_cover_url} alt="Album cover composite" emptyLabel="No album cover" />
        </div>
        {art.prompt && (
          <p className="admin-art-snapshot">
            {art.prompt} <ModelBadge model={art.model} />
          </p>
        )}
        <div className="admin-art-toolbar">
          {art.current_blob_key && (
            <EditControl
              blobKey={art.current_blob_key}
              label=""
              provenance={{
                basePrompt: currentParts[0] || null,
                edits: currentParts.slice(1),
              }}
              onPendingStart={startPendingEdit}
              onPendingEnd={removePending}
            />
          )}
          <GenerateControls onGenerate={generate} />
        </div>
      </section>

      {showGrid && (
        <div className="admin-art-grid">
          {art.candidates.map((candidate) => (
            <CandidateCard
              key={candidate.blob_key}
              candidate={candidate}
              onPendingStart={startPendingEdit}
                onPendingEnd={removePending}
            />
          ))}
          {pendingJobs.map((pending) => (
            <PendingCard
              key={pending.id}
              basePrompt={pending.basePrompt}
              edits={pending.edits}
              label={pending.label}
            />
          ))}
        </div>
      )}
    </div>
  );
};

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
        runNote={`This show is part of a run that shares cover art. You are editing the run's art (kept on ${formatDate(parentDate)}); applying a candidate updates every show in the run.`}
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
