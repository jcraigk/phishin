import React, { useEffect, useMemo, useRef, useState } from "react";
import { FontAwesomeIcon } from "@fortawesome/react-fontawesome";
import { faChevronDown } from "@fortawesome/free-solid-svg-icons";

// A select that opens prepopulated and filters as you type. The input shows
// the current selection while closed; focusing it opens the full list, and
// typing narrows it. Options are matched case-insensitively on their label.
// `footer` renders one extra row at the bottom (used for "Create venue"),
// handed the current query.
const FilterSelect = ({
  id,
  value,
  placeholder,
  options,
  onSelect,
  footer,
  disabled,
}) => {
  const [query, setQuery] = useState("");
  const [open, setOpen] = useState(false);
  const [highlight, setHighlight] = useState(0);
  const containerRef = useRef(null);
  const listRef = useRef(null);

  const filtered = useMemo(() => {
    const term = query.trim().toLowerCase();
    if (term === "") return options;
    return options.filter((option) => option.label.toLowerCase().includes(term));
  }, [options, query]);

  useEffect(() => setHighlight(0), [query, open]);

  useEffect(() => {
    const onDocumentClick = (e) => {
      if (containerRef.current && !containerRef.current.contains(e.target)) {
        setOpen(false);
        setQuery("");
      }
    };
    document.addEventListener("mousedown", onDocumentClick);
    return () => document.removeEventListener("mousedown", onDocumentClick);
  }, []);

  useEffect(() => {
    if (!open || !listRef.current) return;
    const item = listRef.current.children[highlight];
    if (item) item.scrollIntoView({ block: "nearest" });
  }, [highlight, open]);

  const choose = (option) => {
    setOpen(false);
    setQuery("");
    onSelect(option);
  };

  const onKeyDown = (e) => {
    if (!open && (e.key === "ArrowDown" || e.key === "Enter")) {
      setOpen(true);
      return;
    }
    if (e.key === "ArrowDown") {
      e.preventDefault();
      setHighlight((h) => Math.min(h + 1, filtered.length - 1));
    } else if (e.key === "ArrowUp") {
      e.preventDefault();
      setHighlight((h) => Math.max(h - 1, 0));
    } else if (e.key === "Enter") {
      e.preventDefault();
      if (filtered[highlight]) choose(filtered[highlight]);
    } else if (e.key === "Escape") {
      setOpen(false);
      setQuery("");
    }
  };

  return (
    <div className="admin-filter-select" ref={containerRef}>
      <div className="admin-filter-control">
        <input
          id={id}
          type="text"
          placeholder={open ? placeholder : ""}
          value={open ? query : value || ""}
          disabled={disabled}
          onFocus={() => setOpen(true)}
          onChange={(e) => {
            setQuery(e.target.value);
            setOpen(true);
          }}
          onKeyDown={onKeyDown}
        />
        <FontAwesomeIcon icon={faChevronDown} className="admin-filter-chevron" />
      </div>
      {open && (
        <ul className="admin-filter-options" ref={listRef}>
          {filtered.map((option, index) => (
            <li key={option.id ?? "none"}>
              <button
                type="button"
                className={index === highlight ? "active" : ""}
                onMouseEnter={() => setHighlight(index)}
                onClick={() => choose(option)}
              >
                {option.label}
              </button>
            </li>
          ))}
          {filtered.length === 0 && <li className="admin-filter-none">No matches</li>}
          {footer && footer(query.trim())}
        </ul>
      )}
    </div>
  );
};

export default FilterSelect;
