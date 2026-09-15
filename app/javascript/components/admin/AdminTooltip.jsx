import React, { useEffect, useLayoutEffect, useRef, useState } from "react";

// Native title tooltips take about a second to appear. Inside the admin this
// swaps them for an instant one: on hover the element's title is moved to a
// data attribute (so the browser's own tooltip stays quiet) and shown in a
// single floating box above the element.
const AdminTooltip = () => {
  const [tip, setTip] = useState(null);
  const [left, setLeft] = useState(0);
  const boxRef = useRef(null);

  // Centre on the element, then slide back inside the viewport if the box
  // would otherwise run off either edge.
  useLayoutEffect(() => {
    if (!tip || !boxRef.current) return;
    const width = boxRef.current.offsetWidth;
    const margin = 8;
    const centred = tip.x - width / 2;
    setLeft(Math.min(Math.max(centred, margin), window.innerWidth - width - margin));
  }, [tip]);

  useEffect(() => {
    let current = null;

    const show = (el) => {
      if (el.title) {
        el.dataset.tip = el.title;
        el.removeAttribute("title");
      }
      const text = el.dataset.tip;
      if (!text) return;
      current = el;
      const rect = el.getBoundingClientRect();
      setTip({ text, x: rect.left + rect.width / 2, y: rect.top });
    };

    const hide = () => {
      current = null;
      setTip(null);
    };

    const onOver = (e) => {
      const el = e.target.closest?.("[title], [data-tip]");
      if (!el || el === current) return;
      if (el.classList.contains("tag-badge")) return;
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
    <div ref={boxRef} className="admin-tooltip" style={{ left, top: tip.y }} role="tooltip">
      {tip.text}
    </div>
  );
};

export default AdminTooltip;
