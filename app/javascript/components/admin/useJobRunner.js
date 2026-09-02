import { useCallback, useEffect, useRef, useState } from "react";
import { pollJob, isPollAbort } from "./adminApi";

// Every audio tool follows the same shape: kick off a job, poll it with a
// status line, then act on the finished job. The AbortController lives here so
// no call site can forget to hand pollJob a signal or to abort on unmount.
const useJobRunner = () => {
  const controllerRef = useRef(null);
  const mountedRef = useRef(true);
  const [busy, setBusy] = useState(false);
  const [status, setStatus] = useState(null);
  const [progress, setProgress] = useState(null);
  const [error, setError] = useState(null);

  useEffect(() => {
    // Hot reload re-runs this effect; without the reset a single edit would
    // permanently mark the runner unmounted and drop every poll completion.
    mountedRef.current = true;
    return () => {
      mountedRef.current = false;
      if (controllerRef.current) controllerRef.current.abort();
    };
  }, []);

  const run = useCallback(async (start, onDone) => {
    setError(null);
    setStatus(null);
    setProgress(null);
    setBusy(true);
    const controller = new AbortController();
    controllerRef.current = controller;
    try {
      const { job_id: jobId } = await start();
      const job = await pollJob(jobId, {
        onUpdate: (j) => {
          const raw = j.status || "";
          const fallback = raw ? `${raw.charAt(0).toUpperCase()}${raw.slice(1)}...` : null;
          setStatus(j.message || fallback);
          setProgress(j.progress ?? null);
        },
        signal: controller.signal,
      });
      if (!mountedRef.current) return null;
      if (onDone) await onDone(job);
      if (mountedRef.current) {
        setStatus(null);
        setProgress(null);
      }
      return job;
    } catch (e) {
      if (!isPollAbort(e) && mountedRef.current) setError(e.message);
      return null;
    } finally {
      if (controllerRef.current === controller) controllerRef.current = null;
      if (mountedRef.current) setBusy(false);
    }
  }, []);

  const cancel = useCallback(() => {
    if (controllerRef.current) controllerRef.current.abort();
  }, []);

  return { run, cancel, busy, status, progress, error, setError };
};

export default useJobRunner;
