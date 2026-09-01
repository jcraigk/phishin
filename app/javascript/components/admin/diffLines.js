const diffLines = (oldText, newText) => {
  const a = (oldText || "").split("\n");
  const b = (newText || "").split("\n");
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

export default diffLines;
