import { DirectUpload } from "@rails/activestorage";

const DIRECT_UPLOAD_URL = "/admin/direct_uploads";

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
