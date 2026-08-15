import { DirectUpload } from "@rails/activestorage";

const DIRECT_UPLOAD_URL = "/admin/direct_uploads";

const isMp3 = (file) =>
  file.name.toLowerCase().endsWith(".mp3") || file.type === "audio/mpeg";

// Dotfiles cover .DS_Store; __MACOSX is the resource-fork folder a zip made on a
// Mac unpacks alongside the real one, and it mirrors every filename inside it.
const isJunk = (name) => name.startsWith(".") || name === "__MACOSX";

const fileFromEntry = (entry) =>
  new Promise((resolve) => {
    entry.file(resolve, () => resolve(null));
  });

// readEntries returns at most 100 entries per call and signals the end of the
// directory with an empty array, so a single call silently truncates any folder
// with more than 100 files. Keep calling the same reader until it comes back
// empty. A fresh reader would restart from the beginning and never terminate.
const readAllEntries = (reader) =>
  new Promise((resolve, reject) => {
    const entries = [];
    const readBatch = () => {
      reader.readEntries((batch) => {
        if (batch.length === 0) {
          resolve(entries);
          return;
        }
        entries.push(...batch);
        readBatch();
      }, reject);
    };
    readBatch();
  });

const collectFromEntry = async (entry, out) => {
  if (!entry || isJunk(entry.name)) return;

  if (entry.isFile) {
    const file = await fileFromEntry(entry);
    if (file && isMp3(file)) out.push(file);
    return;
  }

  if (entry.isDirectory) {
    const children = await readAllEntries(entry.createReader());
    // Sequential rather than parallel: recursing every subdirectory at once can
    // exhaust the browser's file handles on a deep archive, and the ordering
    // keeps the upload list in the order the admin sees in Finder.
    for (const child of children) {
      await collectFromEntry(child, out);
    }
  }
};

// Returns a flat File[] from a drop that may contain directories. A dropped
// folder arrives as a DataTransferItem entry, not a File, so dataTransfer.files
// is empty for it and only webkitGetAsEntry can see inside.
export const collectFiles = async (dataTransfer) => {
  const items = Array.from(dataTransfer.items || []);
  const entries = items
    .filter((item) => item.kind === "file")
    .map((item) => (item.webkitGetAsEntry ? item.webkitGetAsEntry() : null));

  if (entries.some(Boolean)) {
    const files = [];
    for (const entry of entries) {
      await collectFromEntry(entry, files);
    }
    return files;
  }

  return Array.from(dataTransfer.files || []).filter(
    (file) => !isJunk(file.name) && isMp3(file)
  );
};

export const uploadFile = (file, onProgress) =>
  new Promise((resolve, reject) => {
    const delegate = {
      // DirectUpload does not forward our auth header, so set it on each XHR
      directUploadWillCreateBlobWithXHR: (xhr) => {
        xhr.setRequestHeader("X-Auth-Token", localStorage.getItem("jwt") || "");
      },
      directUploadWillStoreFileWithXHR: (xhr) => {
        if (!onProgress) return;
        xhr.upload.addEventListener("progress", (event) => {
          if (event.lengthComputable) {
            onProgress(Math.round((event.loaded / event.total) * 100));
          }
        });
      },
    };

    const upload = new DirectUpload(file, DIRECT_UPLOAD_URL, delegate);
    upload.create((error, blob) => {
      // DirectUpload reports failures as strings, not Error instances
      if (error) reject(error instanceof Error ? error : new Error(error));
      else resolve(blob.signed_id);
    });
  });
