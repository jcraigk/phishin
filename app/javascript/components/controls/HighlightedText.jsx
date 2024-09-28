import React from "react";

const HighlightedText = ({ text, highlight }) => {
  if (!highlight) return <span>{text}</span>;

  const escapedHighlight = highlight.replace(/[-/\\^$*+?.()|[\]{}]/g, '\\$&');
  const parts = text.split(new RegExp(`(${escapedHighlight})`, 'gi'));

  return (
    <span>
      {parts.map((part, index) =>
        part.toLowerCase() === highlight.toLowerCase() ? (
          <span key={index} className="hilite">{part}</span>
        ) : (
          part
        )
      )}
    </span>
  );
};

export default HighlightedText;
