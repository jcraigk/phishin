import React, { useEffect } from "react";

// Owns the object URL for a rendered preview: revoking it on unmount and on
// every replacement is what keeps a session of repeated previews from pinning
// each rendered mp3 in memory.
const PreviewPlayer = ({ label, url }) => {
  useEffect(() => {
    if (!url) return undefined;
    return () => URL.revokeObjectURL(url);
  }, [url]);

  if (!url) return null;

  return (
    <div className="admin-preview-player">
      <span className="admin-preview-label">{label}</span>
      <audio controls src={url} />
    </div>
  );
};

export default PreviewPlayer;
