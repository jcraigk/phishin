import { useEffect, useRef } from "react";

export default function useClickOutside(ref, active, onOutside) {
  const handlerRef = useRef(onOutside);
  handlerRef.current = onOutside;

  useEffect(() => {
    if (!active) return undefined;
    const onDocumentClick = (e) => {
      if (ref.current && !ref.current.contains(e.target)) handlerRef.current(e);
    };
    document.addEventListener("mousedown", onDocumentClick);
    return () => document.removeEventListener("mousedown", onDocumentClick);
  }, [ref, active]);
}
