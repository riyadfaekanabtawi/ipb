// Helpers shared by the screens.

import { useState } from "react";
import { useSession, useSyncState } from "../data/session";
import { toast, toastError } from "../lib/toast";

/** True when the licence allows writes (the banner explains why when it doesn't). */
export function useWritable() {
  return useSyncState().licence?.writable !== false;
}

/** Runs a service call with toasts: success message or the domain / server error. */
export function useAction() {
  const [busy, setBusy] = useState(false);
  const run = async (fn: () => Promise<unknown>, success?: string) => {
    setBusy(true);
    try {
      await fn();
      if (success) toast(success);
      return true;
    } catch (error) {
      toastError(error);
      return false;
    } finally {
      setBusy(false);
    }
  };
  return { busy, run };
}

export function useServices() {
  return useSession().services;
}

export const matches = (query: string, ...fields: (string | null | undefined)[]) => {
  const q = query.trim().toLocaleLowerCase("es");
  if (!q) return true;
  return fields.some((f) => (f ?? "").toLocaleLowerCase("es").includes(q));
};

/** Downloads a CSV with a UTF-8 BOM so Excel opens accents correctly. */
export function downloadCSV(filename: string, rows: (string | number)[][]) {
  const escape = (v: string | number) => {
    const s = String(v);
    return /[",\n;]/.test(s) ? `"${s.replace(/"/g, '""')}"` : s;
  };
  const csv = "﻿" + rows.map((r) => r.map(escape).join(",")).join("\n");
  const url = URL.createObjectURL(new Blob([csv], { type: "text/csv;charset=utf-8" }));
  const a = document.createElement("a");
  a.href = url;
  a.download = filename;
  a.click();
  setTimeout(() => URL.revokeObjectURL(url), 1000);
}
