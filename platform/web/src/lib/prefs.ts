// Per-browser preferences (the apps keep these in UserDefaults per device).

import { useSyncExternalStore } from "react";
import type { CalculatorConstants } from "../domain/rules";

const listeners = new Set<() => void>();

function read<T>(key: string, fallback: T): T {
  try {
    const raw = localStorage.getItem(key);
    return raw == null ? fallback : (JSON.parse(raw) as T);
  } catch {
    return fallback;
  }
}

function write(key: string, value: unknown) {
  try {
    localStorage.setItem(key, JSON.stringify(value));
  } catch {
    /* storage unavailable: keep in memory for this session */
  }
  cache.delete(key);
  memory.set(key, value);
  listeners.forEach((fn) => fn());
}

const cache = new Map<string, unknown>();
const memory = new Map<string, unknown>();

function usePref<T>(key: string, fallback: T): [T, (v: T) => void] {
  const value = useSyncExternalStore(
    (fn) => {
      listeners.add(fn);
      return () => listeners.delete(fn);
    },
    () => {
      if (!cache.has(key)) cache.set(key, memory.has(key) ? memory.get(key) : read(key, fallback));
      return cache.get(key) as T;
    },
  );
  return [value, (v: T) => write(key, v)];
}

export const URGENCY_KEY = "settings.urgencyWindowDays";
export const useUrgencyWindow = () => usePref<number>(URGENCY_KEY, 7);

export type ThemePref = "auto" | "light" | "dark";
export const useThemePref = () => usePref<ThemePref>("settings.theme", "auto");

export function applyTheme(pref: ThemePref) {
  const root = document.documentElement;
  if (pref === "auto") root.removeAttribute("data-theme");
  else root.setAttribute("data-theme", pref);
}

export const EMPTY_CONSTANTS: CalculatorConstants = { minutesPerDay: 0, minutesPerWeek: 0, minutesPerMonth: 0, workDaysPerWeek: 0, workDaysPerMonth: 0 };
export const useCalculatorConstants = () => usePref<CalculatorConstants>("settings.calculatorConstants", EMPTY_CONSTANTS);

export const initialTheme = () => read<ThemePref>("settings.theme", "auto");
