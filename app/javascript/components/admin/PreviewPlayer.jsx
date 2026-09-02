import React, { useEffect } from "react";

// Owns the object URL for a rendered preview: revoking it on unmount and on
// every replacement is what keeps a session of repeated previews from pinning
// each rendered mp3 in memory.
const PreviewPlayer = ({ label, url, audioRef, onEnded }) => {
  useEffect(() => {
    if (!url) return undefined;
    return () => URL.revokeObjectURL(url);
  }, [url]);

  if (!url) return null;

  return (
    <div className="admin-preview-player">
      <audio controls src={url} ref={audioRef} onEnded={onEnded} />
      {label && <span className="admin-preview-tag">{label}</span>}
    </div>
  );
};

export default PreviewPlayer;
