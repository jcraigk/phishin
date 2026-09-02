import React, { useContext, useEffect, useState } from "react";
import { createPortal } from "react-dom";
import { FontAwesomeIcon } from "@fortawesome/react-fontawesome";
import { faGlobe } from "@fortawesome/free-solid-svg-icons";
import MoonLoader from "react-spinners/MoonLoader";
import { EditorContext } from "./AdminShowEditor";
import useJobRunner from "./useJobRunner";
import { adminPost } from "./adminApi";

const PnetCheckPanel = () => {
  const { show } = useContext(EditorContext);
  const [report, setReport] = useState(null);
  const [actionsSlot, setActionsSlot] = useState(null);
  const { run, busy, status, error } = useJobRunner();

  useEffect(() => {
    setActionsSlot(document.getElementById("admin-tab-actions"));
  }, []);

  const check = () => {
    setReport(null);
    run(
      () => adminPost(`/shows/${show.date}/pnet_tag_check`),
      (job) => setReport(job?.payload?.report || "No report produced.")
    );
  };

  const button = (
    <button type="button" disabled={busy} onClick={check} title="Check Phish.net for tag suggestions">
      <FontAwesomeIcon icon={faGlobe} /> PNet
    </button>
  );

  return (
    <section className="admin-pnet-check">
      {actionsSlot && createPortal(button, actionsSlot)}
      {busy && (
        <span className="admin-art-busy">
          <MoonLoader color="#c7c8ca" size={18} /> {status || "Checking..."}
        </span>
      )}
      {error && <p className="admin-error">{error}</p>}
      {report && <pre className="admin-pnet-report">{report}</pre>}
    </section>
  );
};

export default PnetCheckPanel;
