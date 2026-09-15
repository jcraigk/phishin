import React, { useRef, useState } from "react";
import { FontAwesomeIcon } from "@fortawesome/react-fontawesome";
import { faPlus } from "@fortawesome/free-solid-svg-icons";
import useClickOutside from "./useClickOutside";
import { setName } from "./sets";

const AddSetMenu = ({ options, onAdd, disabled, title }) => {
  const [open, setOpen] = useState(false);
  const menuRef = useRef(null);
  useClickOutside(menuRef, open, () => setOpen(false));

  return (
    <div className="admin-row-menu" ref={menuRef}>
      <button
        type="button"
        disabled={disabled || options.length === 0}
        title={title}
        onClick={() => setOpen(!open)}
      >
        <FontAwesomeIcon icon={faPlus} /> Set
      </button>
      {open && (
        <ul className="admin-row-menu-list">
          {options.map((set) => (
            <li key={set}>
              <button
                type="button"
                onClick={() => {
                  setOpen(false);
                  onAdd(set);
                }}
              >
                {setName(set)}
              </button>
            </li>
          ))}
        </ul>
      )}
    </div>
  );
};

export default AddSetMenu;
