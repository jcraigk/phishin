import React, { useContext, useEffect, useState } from "react";
import { createPortal } from "react-dom";
import { FontAwesomeIcon } from "@fortawesome/react-fontawesome";
import { faCircleCheck, faGlobe, faXmark } from "@fortawesome/free-solid-svg-icons";
import Spinner from "./Spinner";
import { EditorContext } from "./AdminShowEditor";
import useJobRunner from "./useJobRunner";
import { adminPost } from "./adminApi";
import Modal from "./Modal";

const PnetCheckPanel = () => {
  const { show } = useContext(EditorContext);
  const [open, setOpen] = useState(false);
  const [report, setReport] = useState(null);
  const [checked, setChecked] = useState([]);
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
      (job) => {
        setReport(job?.payload?.report || "No report produced.");
        setChecked(job?.payload?.checked || []);
      }
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
      {open && (
        <Modal title="Phish.net Check" wide>
          {busy && (
            <div className="admin-pnet-progress">
              <span className="admin-art-busy">
                <Spinner size={18} /> {status || "Checking..."}
              </span>
              <progress max="100" value={progress ?? 0} />
            </div>
          )}
          {error && <p className="admin-error">{error}</p>}
          {report && (
            report === "No conflicts." ? (
              <p className="admin-pnet-report admin-pnet-clear">
                <FontAwesomeIcon icon={faCircleCheck} /> No conflicts
              </p>
            ) : (
              <div className="admin-pnet-report">{report}</div>
            )
          )}
          {report && checked.length > 0 && (
            <p className="admin-pnet-checked">Checked: {checked.join(" · ")}</p>
          )}
          <div className="admin-modal-actions">
            <button type="button" onClick={close}>
              <FontAwesomeIcon icon={faXmark} /> {busy ? "Cancel" : "Close"}
            </button>
          </div>
        </Modal>
      )}
    </>
  );
};

export default PnetCheckPanel;
