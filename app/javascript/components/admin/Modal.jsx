import React from "react";
import { createPortal } from "react-dom";

const Modal = ({ title, wide = false, className = "", onClose, children }) =>
  createPortal(
    <div className="admin-modal-overlay" onClick={onClose}>
      <div
        className={`admin-modal${wide ? " admin-modal-wide" : ""}${className ? ` ${className}` : ""}`}
        onClick={(e) => e.stopPropagation()}
      >
        {title != null && <h3>{title}</h3>}
        {children}
      </div>
    </div>,
    document.querySelector(".admin-layout") || document.body
  );

export default Modal;
