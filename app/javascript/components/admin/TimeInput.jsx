import React, { useEffect, useState } from "react";

export const secondsToClock = (seconds) => {
  if (seconds === null || seconds === undefined) return "";
  const total = Math.max(0, Math.round(Number(seconds)));
  const h = Math.floor(total / 3600);
  const m = Math.floor((total % 3600) / 60);
  const s = total % 60;
  return h > 0
    ? `${h}:${String(m).padStart(2, "0")}:${String(s).padStart(2, "0")}`
    : `${m}:${String(s).padStart(2, "0")}`;
};

export const clockToSeconds = (text) => {
  const trimmed = text.trim();
  if (trimmed === "") return null;
  return trimmed
    .split(":")
    .reduce((acc, part) => acc * 60 + Number(part || 0), 0);
};

const constrain = (text) => {
  const clean = text.replace(/[^\d:]/g, "");
  const parts = clean.split(":").slice(0, 3);
  return parts
    .map((part, i) => part.slice(0, i === 0 ? 3 : 2))
    .join(":");
};

const TimeInput = ({ value, placeholder, disabled, onCommit }) => {
  const [text, setText] = useState(secondsToClock(value));

  useEffect(() => setText(secondsToClock(value)), [value]);

  const commit = () => {
    const seconds = clockToSeconds(text);
    setText(secondsToClock(seconds));
    if (seconds !== (value ?? null)) onCommit(seconds);
  };

  return (
    <input
      type="text"
      inputMode="numeric"
      className="admin-time-input"
      placeholder={placeholder}
      value={text}
      disabled={disabled}
      onChange={(e) => setText(constrain(e.target.value))}
      onBlur={commit}
      onKeyDown={(e) => {
        if (e.key === "Enter") e.target.blur();
      }}
    />
  );
};

export default TimeInput;
