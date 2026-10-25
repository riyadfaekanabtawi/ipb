// Tiny toast bus (ToastCenter equivalent). UI subscribes in <Toaster/>.

export type ToastKind = "success" | "error" | "info";
export interface Toast { id: number; kind: ToastKind; message: string }

let seq = 0;
let toasts: Toast[] = [];
const listeners = new Set<() => void>();
const emit = () => listeners.forEach((fn) => fn());

export function toast(message: string, kind: ToastKind = "success", ms = kind === "error" ? 6000 : 2600) {
  const t = { id: ++seq, kind, message };
  toasts = [...toasts.slice(-2), t];
  emit();
  setTimeout(() => dismiss(t.id), ms);
}

export const toastError = (error: unknown) => toast(error instanceof Error ? error.message : String(error), "error");

export function dismiss(id: number) {
  toasts = toasts.filter((t) => t.id !== id);
  emit();
}

export const toastStore = {
  subscribe(fn: () => void) {
    listeners.add(fn);
    return () => listeners.delete(fn);
  },
  get: () => toasts,
};
