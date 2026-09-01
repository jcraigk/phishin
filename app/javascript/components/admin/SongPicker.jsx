import React, { useEffect, useRef, useState } from "react";

import { adminGet, adminPost } from "./adminApi";

const DEBOUNCE_MS = 300;

const SongPicker = ({ value, onChange }) => {
  const [query, setQuery] = useState("");
  const [results, setResults] = useState([]);
  const [open, setOpen] = useState(false);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState(null);
  const containerRef = useRef(null);
  const inputRef = useRef(null);

  useEffect(() => {
    const term = query.trim();
    if (term === "") {
      setResults([]);
      return undefined;
    }
    let cancelled = false;
    const timer = setTimeout(async () => {
      try {
        const data = await adminGet(`/songs?q=${encodeURIComponent(term)}`);
        if (!cancelled) setResults(data.songs);
      } catch (e) {
        if (!cancelled) setError(e.message);
      }
    }, DEBOUNCE_MS);

    return () => {
      cancelled = true;
      clearTimeout(timer);
    };
  }, [query]);

  useEffect(() => {
    const onDocumentClick = (e) => {
      if (containerRef.current && !containerRef.current.contains(e.target)) {
        setOpen(false);
      }
    };
    document.addEventListener("mousedown", onDocumentClick);
    return () => document.removeEventListener("mousedown", onDocumentClick);
  }, []);

  const reset = () => {
    setQuery("");
    setResults([]);
    setOpen(false);
  };

  const addSong = (song) => {
    setError(null);
    if (!value.some((s) => s.id === song.id)) {
      onChange([...value, { id: song.id, title: song.title }]);
    }
    reset();
  };

  const removeSong = (song) => {
    setError(null);
    onChange(value.filter((s) => s.id !== song.id));
  };

  const createSong = async () => {
    const title = query.trim();
    if (title === "") return;
    setError(null);
    setBusy(true);
    try {
      const song = await adminPost("/songs", { title });
      addSong(song);
    } catch (e) {
      setError(e.message);
    } finally {
      setBusy(false);
    }
  };

  const term = query.trim();
  const hasExactMatch = results.some(
    (s) => s.title.toLowerCase() === term.toLowerCase()
  );

  const onKeyDown = (e) => {
    if (e.key === "Backspace" && query === "" && value.length > 0) {
      removeSong(value[value.length - 1]);
    }
  };

  return (
    <div className="admin-song-picker" ref={containerRef}>
      <div
        className="admin-song-box"
        onClick={() => inputRef.current && inputRef.current.focus()}
      >
        {value.map((song) => (
          <span key={song.id} className="admin-song-pill">
            {song.title}
            <button
              type="button"
              aria-label={`Remove ${song.title}`}
              onClick={(e) => {
                e.stopPropagation();
                removeSong(song);
              }}
            >
              &times;
            </button>
          </span>
        ))}
        <input
          ref={inputRef}
          type="text"
          placeholder={value.length === 0 ? "Add song" : ""}
          value={query}
          onFocus={() => setOpen(true)}
          onKeyDown={onKeyDown}
          onChange={(e) => {
            setQuery(e.target.value);
            setOpen(true);
          }}
        />
      </div>
      {open && term !== "" && (
        <ul className="admin-song-results">
          {results.map((song) => (
            <li key={song.id}>
              <button type="button" onClick={() => addSong(song)}>
                {song.title}
              </button>
            </li>
          ))}
          {!hasExactMatch && (
            <li className="admin-song-create">
              <button type="button" onClick={createSong} disabled={busy}>
                Create &quot;{term}&quot;
              </button>
            </li>
          )}
        </ul>
      )}
      {error && <p className="admin-error">{error}</p>}
    </div>
  );
};

export default SongPicker;
