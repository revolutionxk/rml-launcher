import { create } from "zustand";
import { persist } from "zustand/middleware";

import { ACCENT_COLORS, AccentColor, ResolvedTheme, ThemeMode } from "@/theme/colors";

interface ThemeStore {
  theme: ThemeMode;
  accent: string;
  compactMode: boolean;
  showVersionBadge: boolean;

  setTheme: (theme: ThemeMode) => void;
  setAccent: (accent: string) => void;
  setCompactMode: (v: boolean) => void;
  setShowVersionBadge: (v: boolean) => void;

  resolvedTheme: () => ResolvedTheme;
  apply: () => void;
}

function getSystemTheme(): ResolvedTheme {
  return window.matchMedia("(prefers-color-scheme: dark)").matches ? "dark" : "light";
}

function applyToDOM(resolved: ResolvedTheme, accent: AccentColor) {
  const root = document.documentElement;

  root.setAttribute("data-theme-transitioning", "");
  root.setAttribute("data-theme", resolved);

  root.style.setProperty("--accent", accent.value);
  root.style.setProperty("--accent-hover", accent.hover);
  root.style.setProperty("--accent-muted", accent.muted);
  root.style.setProperty("--border-focus", accent.value);
  
  root.style.setProperty("--color-accent", accent.value);
  root.style.setProperty("--color-accent-hover", accent.hover);
  root.style.setProperty("--color-accent-muted", accent.muted);
  root.style.setProperty("--color-border-focus", accent.value);

  setTimeout(() => root.removeAttribute("data-theme-transitioning"), 280);
}

export const useThemeStore = create<ThemeStore>()(
  persist(
    (set, get) => ({
      theme: "system",
      accent: "#4f86f7",
      compactMode: false,
      showVersionBadge: true,

      resolvedTheme: () => {
        const { theme } = get();
        return theme === "system" ? getSystemTheme() : theme;
      },

      apply: () => {
        const { resolvedTheme, accent } = get();
        const color = ACCENT_COLORS.find((c) => c.value === accent) ?? ACCENT_COLORS[0];
        applyToDOM(resolvedTheme(), color);
      },

      setTheme: (theme) => {
        set({ theme });
        const { resolvedTheme, accent } = get();
        const color = ACCENT_COLORS.find((c) => c.value === accent) ?? ACCENT_COLORS[0];
        applyToDOM(resolvedTheme(), color);
      },

      setAccent: (accent) => {
        set({ accent });
        const { resolvedTheme } = get();
        const color = ACCENT_COLORS.find((c) => c.value === accent) ?? ACCENT_COLORS[0];
        applyToDOM(resolvedTheme(), color);
      },

      setCompactMode: (compactMode) => set({ compactMode }),
      setShowVersionBadge: (showVersionBadge) => set({ showVersionBadge }),
    }),
    {
      name: "rml-theme",
      partialize: ({ theme, accent, compactMode, showVersionBadge }) => ({
        theme,
        accent,
        compactMode,
        showVersionBadge,
      }),
    },
  ),
);
