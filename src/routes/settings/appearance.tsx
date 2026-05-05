import { createFileRoute } from "@tanstack/react-router";
import { Check, MonitorIcon, MoonIcon, SunIcon } from "lucide-react";
import { motion } from "motion/react";
import { JSX } from "react";

import SettingRow from "@/components/setting-row";
import Toggle from "@/components/toggle";
import { Card } from "@/components/ui/card";
import { SegmentGroup } from "@/components/ui/segment-group";
import { LOCALE_OPTIONS, useI18n } from "@/i18n";
import { useThemeStore } from "@/stores/theme";
import { ACCENT_COLORS, type ThemeMode } from "@/theme/colors";

export const Route = createFileRoute("/settings/appearance")({
  component: AppearancePage,
});

const THEME_OPTIONS: { value: ThemeMode; icon: JSX.Element; labelId: string }[] = [
  { value: "dark", icon: <MoonIcon size={15} />, labelId: "appearance-theme-dark" },
  { value: "light", icon: <SunIcon size={15} />, labelId: "appearance-theme-light" },
  { value: "system", icon: <MonitorIcon size={15} />, labelId: "appearance-theme-system" },
];

function AppearancePage() {
  const { preference, setPreference, t } = useI18n();
  const theme = useThemeStore((s) => s.theme);
  const accent = useThemeStore((s) => s.accent);
  const compactMode = useThemeStore((s) => s.compactMode);
  const showVersionBadge = useThemeStore((s) => s.showVersionBadge);
  const setTheme = useThemeStore((s) => s.setTheme);
  const setAccent = useThemeStore((s) => s.setAccent);
  const setCompactMode = useThemeStore((s) => s.setCompactMode);
  const setShowVersionBadge = useThemeStore((s) => s.setShowVersionBadge);

  return (
    <div>
      <div className="mb-5">
        <h1 className="text-[18px] font-semibold text-text tracking-[-0.018em] leading-[1.25]">
          {t("appearance-title")}
        </h1>
        <p className="text-[12.5px] text-text-muted mt-1 leading-normal">
          {t("appearance-description")}
        </p>
      </div>

      <Card.Root className="mb-3">
        <Card.Header>
          <Card.Label>{t("appearance-section-theme")}</Card.Label>
        </Card.Header>
        <Card.Body>
          <SegmentGroup.Root
            value={theme}
            onValueChange={(v) => setTheme(v as ThemeMode)}
            className="grid grid-cols-3"
          >
            {THEME_OPTIONS.map((option) => (
              <SegmentGroup.Item key={option.value} value={option.value}>
                {option.icon}
                {t(option.labelId)}
              </SegmentGroup.Item>
            ))}
          </SegmentGroup.Root>
        </Card.Body>
      </Card.Root>

      <Card.Root className="mb-3">
        <Card.Header>
          <Card.Label>{t("appearance-section-accent")}</Card.Label>
        </Card.Header>
        <Card.Body className="flex items-center gap-2.5">
          {ACCENT_COLORS.map((c) => {
            const colorLabel = t(c.labelId);
            const selected = accent === c.value;

            return (
              <motion.button
                type="button"
                key={c.value}
                className={`color-swatch w-7 h-7 rounded-full cursor-pointer border-2 shrink-0 flex items-center justify-center ${
                  selected ? "selected" : "border-transparent"
                }`}
                style={{ background: c.value }}
                onClick={() => setAccent(c.value)}
                title={colorLabel}
                aria-label={t("appearance-accent-swatch", { color: colorLabel })}
                whileTap={{ scale: 0.88 }}
                transition={{ type: "spring", stiffness: 500, damping: 24 }}
              >
                {selected && (
                  <motion.span
                    initial={{ scale: 0, opacity: 0 }}
                    animate={{ scale: 1, opacity: 1 }}
                    transition={{ type: "spring", stiffness: 500, damping: 28 }}
                  >
                    <Check size={12} color="white" />
                  </motion.span>
                )}
              </motion.button>
            );
          })}
        </Card.Body>
      </Card.Root>

      <Card.Root className="mb-3">
        <Card.Header>
          <Card.Label>{t("appearance-section-language")}</Card.Label>
          <Card.Description>{t("appearance-language-description")}</Card.Description>
        </Card.Header>
        <Card.Body>
          <SegmentGroup.Root
            value={preference}
            onValueChange={(v) => setPreference(v as typeof preference)}
            className="grid grid-cols-3"
          >
            {LOCALE_OPTIONS.map((option) => (
              <SegmentGroup.Item key={option.value} value={option.value}>
                {t(option.labelId)}
              </SegmentGroup.Item>
            ))}
          </SegmentGroup.Root>
        </Card.Body>
      </Card.Root>

      <Card.Root>
        <Card.Header>
          <Card.Label>{t("appearance-section-interface")}</Card.Label>
        </Card.Header>
        <SettingRow
          label={t("appearance-compact-label")}
          description={t("appearance-compact-description")}
        >
          <Toggle checked={compactMode} onChange={setCompactMode} />
        </SettingRow>
        <SettingRow
          label={t("appearance-version-badge-label")}
          description={t("appearance-version-badge-description")}
        >
          <Toggle checked={showVersionBadge} onChange={setShowVersionBadge} />
        </SettingRow>
      </Card.Root>
    </div>
  );
}
