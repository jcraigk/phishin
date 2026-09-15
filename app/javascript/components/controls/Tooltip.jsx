import React, { useEffect, useLayoutEffect, useRef, useState } from "react";

const EDGE_MARGIN = 8;
const FLIP_THRESHOLD = 80;

const Tooltip = () => {
  const [tip, setTip] = useState(null);
  const [left, setLeft] = useState(0);
  const boxRef = useRef(null);

  useLayoutEffect(() => {
    if (!tip || !boxRef.current) return;
    const width = boxRef.current.offsetWidth;
    const centered = tip.x - width / 2;
    setLeft(Math.min(Math.max(centered, EDGE_MARGIN), window.innerWidth - width - EDGE_MARGIN));
  }, [tip]);

  useEffect(() => {
    let current = null;

    const hide = () => {
      current = null;
      setTip(null);
    };

    const show = (el) => {
      const text = el.dataset.tip;
      if (!text) return;
      current = el;
      const rect = el.getBoundingClientRect();
      const below = rect.top < FLIP_THRESHOLD;
      setTip({
        text,
        below,
        x: rect.left + rect.width / 2,
        y: below ? rect.bottom : rect.top,
      });
    };

    const onOver = (e) => {
      const target = e.target.closest?.("[data-tip]");
      const el = target && !target.closest(".admin-layout") ? target : null;
      if (el === current) return;
      if (!el) {
        if (current) hide();
        return;
      }
      show(el);
    };

    const onOut = (e) => {
      if (!current) return;
      if (e.relatedTarget && current.contains(e.relatedTarget)) return;
      hide();
    };

    document.addEventListener("mouseover", onOver);
    document.addEventListener("mouseout", onOut);
    document.addEventListener("mousedown", hide, true);
    document.addEventListener("scroll", hide, true);
    return () => {
      document.removeEventListener("mouseover", onOver);
      document.removeEventListener("mouseout", onOut);
      document.removeEventListener("mousedown", hide, true);
      document.removeEventListener("scroll", hide, true);
    };
  }, []);

  if (!tip) return null;

  return (
    <div
      ref={boxRef}
      className={`custom-tooltip${tip.below ? " is-below" : ""}`}
      style={{ left, top: tip.y }}
      role="tooltip"
    >
      {tip.text}
    </div>
  );
};

export default Tooltip;
