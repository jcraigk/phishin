import React, { useContext, useEffect, useState } from "react";
import { createPortal } from "react-dom";
import { FontAwesomeIcon } from "@fortawesome/react-fontawesome";
import { faGlobe, faXmark } from "@fortawesome/free-solid-svg-icons";
import MoonLoader from "react-spinners/MoonLoader";
import { EditorContext } from "./AdminShowEditor";
import useJobRunner from "./useJobRunner";
import { adminPost } from "./adminApi";

const PnetCheckPanel = () => {
  const { show } = useContext(EditorContext);
  const [open, setOpen] = useState(false);
  const [report, setReport] = useState(null);
  const [actionsSlot, setActionsSlot] = useState(null);
  const { run, cancel, busy, status, progress, error } = useJobRunner();

  useEffect(() => {
    setActionsSlot(document.getElementById("admin-tab-actions"));
  }, []);

  const check = () => {
    setReport(null);
    setOpen(true);
    run(
      () => adminPost(`/shows/${show.date}/pnet_tag_check`),
      (job) => setReport(job?.payload?.report || "No report produced.")
    );
  };

  const close = () => {
    cancel();
    setOpen(false);
  };

  const button = (
    <button type="button" disabled={busy} onClick={check} title="Check Phish.net for setlist and tag suggestions">
      <FontAwesomeIcon icon={faGlobe} /> PNet
    </button>
  );

  return (
    <>
      {actionsSlot && createPortal(button, actionsSlot)}
      {open &&
        createPortal(
          <div className="admin-modal-overlay">
            <div
              className="admin-modal admin-modal-wide"
              onClick={(e) => e.stopPropagation()}
            >
              <h3>Phish.net Check</h3>
              {busy && (
                <>
                  <span className="admin-art-busy">
                    <MoonLoader color="#c7c8ca" size={18} /> {status || "Checking..."}
                  </span>
                  {progress !== null && <progress max="100" value={progress} />}
                </>
              )}
              {error && <p className="admin-error">{error}</p>}
              {report && <pre className="admin-pnet-report">{report}</pre>}
              <div className="admin-modal-actions">
                <button type="button" onClick={close}>
                  <FontAwesomeIcon icon={faXmark} /> {busy ? "Cancel" : "Close"}
                </button>
              </div>
            </div>
          </div>,
          document.querySelector(".admin-layout") || document.body
        )}
    </>
  );
};

export default PnetCheckPanel;
