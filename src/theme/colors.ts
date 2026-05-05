export type ThemeMode = "dark" | "light" | "system";
export type ResolvedTheme = "dark" | "light";

export interface AccentColor {
  labelId: string;
  value: string;
  hover: string;
  muted: string;
}

export const ACCENT_COLORS: AccentColor[] = [
  {
    labelId: "appearance-accent-blue",
    value: "#4f86f7",
    hover: "#3b74e8",
    muted: "rgba(79, 134, 247, 0.12)",
  },
  {
    labelId: "appearance-accent-purple",
    value: "#8b5cf6",
    hover: "#7c3aed",
    muted: "rgba(139, 92, 246, 0.12)",
  },
  {
    labelId: "appearance-accent-green",
    value: "#3dcc7a",
    hover: "#2db86b",
    muted: "rgba(61, 204, 122, 0.12)",
  },
  {
    labelId: "appearance-accent-orange",
    value: "#fb923c",
    hover: "#ea7c1e",
    muted: "rgba(251, 146, 60, 0.12)",
  },
  {
    labelId: "appearance-accent-red",
    value: "#f04d4d",
    hover: "#dc3333",
    muted: "rgba(240, 77, 77, 0.12)",
  },
  {
    labelId: "appearance-accent-pink",
    value: "#ec4899",
    hover: "#db2777",
    muted: "rgba(236, 72, 153, 0.12)",
  },
  {
    labelId: "appearance-accent-cyan",
    value: "#22d3ee",
    hover: "#06b6d4",
    muted: "rgba(34, 211, 238, 0.12)",
  },
];
