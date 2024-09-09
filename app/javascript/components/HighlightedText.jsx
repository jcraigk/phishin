import React from "react";

const HighlightedText = ({ text, highlight }) => {
  if (!highlight) return <span>{text}</span>;

  // Escape special characters in the highlight string for use in regex
  const escapedHighlight = highlight.replace(/[-/\\^$*+?.()|[\]{}]/g, '\\$&');

  // Split the text into an array of strings and the matched highlights
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
