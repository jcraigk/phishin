export const normalizeText = (text) => (text || "").replace(/\r\n?/g, "\n");

const rawDiff = (oldText, newText) => {
  const a = normalizeText(oldText).split("\n");
  const b = normalizeText(newText).split("\n");
  const lcs = Array.from({ length: a.length + 1 }, () =>
    new Array(b.length + 1).fill(0)
  );
  for (let i = a.length - 1; i >= 0; i--) {
    for (let j = b.length - 1; j >= 0; j--) {
      lcs[i][j] =
        a[i] === b[j]
          ? lcs[i + 1][j + 1] + 1
          : Math.max(lcs[i + 1][j], lcs[i][j + 1]);
    }
  }
  const lines = [];
  let i = 0;
  let j = 0;
  while (i < a.length && j < b.length) {
    if (a[i] === b[j]) {
      lines.push({ type: "same", text: a[i] });
      i += 1;
      j += 1;
    } else if (lcs[i + 1][j] >= lcs[i][j + 1]) {
      lines.push({ type: "del", text: a[i] });
      i += 1;
    } else {
      lines.push({ type: "add", text: b[j] });
      j += 1;
    }
  }
  while (i < a.length) {
    lines.push({ type: "del", text: a[i] });
    i += 1;
  }
  while (j < b.length) {
    lines.push({ type: "add", text: b[j] });
    j += 1;
  }
  return lines;
};

const CONTEXT = 3;

const collapseContext = (lines) => {
  const keep = new Array(lines.length).fill(false);
  lines.forEach((line, index) => {
    if (line.type === "same") return;
    const from = Math.max(0, index - CONTEXT);
    const to = Math.min(lines.length - 1, index + CONTEXT);
    for (let k = from; k <= to; k++) keep[k] = true;
  });
  const collapsed = [];
  let skipped = 0;
  const flush = () => {
    if (skipped > 0) collapsed.push({ type: "skip", count: skipped });
    skipped = 0;
  };
  lines.forEach((line, index) => {
    if (keep[index]) {
      flush();
      collapsed.push(line);
    } else {
      skipped += 1;
    }
  });
  flush();
  return collapsed;
};

const diffLines = (oldText, newText) => collapseContext(rawDiff(oldText, newText));

export default diffLines;
