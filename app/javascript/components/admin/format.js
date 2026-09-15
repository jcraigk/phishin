export const plural = (count, word, pluralWord = `${word}s`) => `${count} ${count === 1 ? word : pluralWord}`;
