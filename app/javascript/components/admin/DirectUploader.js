import { DirectUpload } from "@rails/activestorage";

const DIRECT_UPLOAD_URL = "/admin/direct_uploads";

export const isMp3 = (file) =>
  file.name.toLowerCase().endsWith(".mp3") || file.type === "audio/mpeg";

const STAGING_EXTENSIONS = [
  "flac", "shn", "wav", "aiff", "mp3", "zip", "rar", "7z", "tar", "tgz", "txt",
];

export const isStagingSource = (file) => {
  const ext = file.name.toLowerCase().split(".").pop();
  return STAGING_EXTENSIONS.includes(ext);
};

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

const collectFromEntry = async (entry, out, accept) => {
  if (!entry || isJunk(entry.name)) return;

  if (entry.isFile) {
    const file = await fileFromEntry(entry);
    if (file && accept(file)) out.push(file);
    return;
  }

  if (entry.isDirectory) {
    const children = await readAllEntries(entry.createReader());
    for (const child of children) {
      await collectFromEntry(child, out, accept);
    }
  }
};

export const collectFiles = async (dataTransfer, accept = isMp3) => {
  const items = Array.from(dataTransfer.items || []);
  const entries = items
    .filter((item) => item.kind === "file")
    .map((item) => (item.webkitGetAsEntry ? item.webkitGetAsEntry() : null));

  if (entries.some(Boolean)) {
    const files = [];
    for (const entry of entries) {
      await collectFromEntry(entry, files, accept);
    }
    return files;
  }

  return Array.from(dataTransfer.files || []).filter(
    (file) => !isJunk(file.name) && accept(file)
  );
};

export const uploadFile = (file, onProgress, onCancelable) =>
  new Promise((resolve, reject) => {
    const delegate = {
      // DirectUpload does not forward our auth header, so set it on each XHR
      directUploadWillCreateBlobWithXHR: (xhr) => {
        xhr.setRequestHeader("X-Auth-Token", localStorage.getItem("jwt") || "");
        if (onCancelable) onCancelable(() => xhr.abort());
      },
      directUploadWillStoreFileWithXHR: (xhr) => {
        if (onCancelable) onCancelable(() => xhr.abort());
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
