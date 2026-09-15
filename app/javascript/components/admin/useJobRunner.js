import { useCallback, useEffect, useRef, useState } from "react";
import { pollJob, isPollAbort } from "./adminApi";

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

  const follow = useCallback(async (getJobId, onDone) => {
    setError(null);
    setStatus(null);
    setProgress(null);
    setBusy(true);
    const controller = new AbortController();
    controllerRef.current = controller;
    try {
      const jobId = await getJobId();
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
      if (mountedRef.current) {
        setStatus(null);
        setProgress(null);
      }
      return null;
    } finally {
      if (controllerRef.current === controller) controllerRef.current = null;
      if (mountedRef.current) setBusy(false);
    }
  }, []);

  const run = useCallback((start, onDone) => follow(async () => (await start()).job_id, onDone), [follow]);

  const resume = useCallback((jobId, onDone) => follow(() => jobId, onDone), [follow]);

  const cancel = useCallback(() => {
    if (controllerRef.current) controllerRef.current.abort();
  }, []);

  return { run, resume, cancel, busy, status, progress, error, setError };
};

export default useJobRunner;
