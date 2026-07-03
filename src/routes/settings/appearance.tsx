import { useQueryClient } from "@tanstack/react-query";
import { createFileRoute } from "@tanstack/react-router";
import { Check, MonitorIcon, MoonIcon, SunIcon } from "lucide-react";
import { motion } from "motion/react";
import { JSX, useEffect, useState } from "react";

import { AboutSection } from "@/components/about-section";
import SettingRow from "@/components/setting-row";
import Toggle from "@/components/toggle";
import { Button } from "@/components/ui/button";
import { Card } from "@/components/ui/card";
import { PageHeader } from "@/components/ui/page-header";
import { SegmentGroup } from "@/components/ui/segment-group";
import { Select } from "@/components/ui/select";
import { LOCALE_OPTIONS, useI18n } from "@/i18n";
import { setEngineGeneralSettings } from "@/lib/engine";
import { setStudioProtocolHandler } from "@/lib/protocol";
import { queryKeys, useEngineGeneralSettings, useStudioProtocolStatus } from "@/lib/queries";
import { createQuickLaunchShortcut } from "@/lib/startup";
import { useSetupStore } from "@/stores/setup";
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

  const queryClient = useQueryClient();
  const { data: engineSettings } = useEngineGeneralSettings();
  const [enableTracking, setEnableTracking] = useState<boolean | null>(null);
  const [disableTelemetry, setDisableTelemetry] = useState<boolean | null>(null);
  const [savingEngine, setSavingEngine] = useState(false);

  useEffect(() => {
    if (engineSettings) {
      setEnableTracking(engineSettings.enableTracking);
      setDisableTelemetry(engineSettings.disableTelemetry);
    }
  }, [engineSettings]);

  const saveEngineSettings = async (nextTracking: boolean, nextTelemetry: boolean) => {
    const previousTracking = enableTracking;
    const previousTelemetry = disableTelemetry;
    setEnableTracking(nextTracking);
    setDisableTelemetry(nextTelemetry);
    setSavingEngine(true);
    try {
      await setEngineGeneralSettings(nextTracking, nextTelemetry);
      await queryClient.invalidateQueries({ queryKey: queryKeys.engineGeneralSettings });
    } catch (error) {
      console.error(error);
      setEnableTracking(previousTracking);
      setDisableTelemetry(previousTelemetry);
    } finally {
      setSavingEngine(false);
    }
  };

  const engineLoaded = enableTracking !== null && disableTelemetry !== null;

  const { data: protocolStatus } = useStudioProtocolStatus();
  const [protocolBusy, setProtocolBusy] = useState(false);

  const toggleProtocol = async (enabled: boolean) => {
    setProtocolBusy(true);
    try {
      const next = await setStudioProtocolHandler(enabled);
      queryClient.setQueryData(queryKeys.studioProtocol, next);
    } catch (error) {
      console.error(error);
    } finally {
      setProtocolBusy(false);
    }
  };

  const autoUpdateStudio = useSetupStore((s) => s.autoUpdateStudio);
  const setAutoUpdateStudio = useSetupStore((s) => s.setAutoUpdateStudio);
  const [shortcutState, setShortcutState] = useState<"idle" | "busy" | "done" | "error">("idle");

  const createShortcut = async () => {
    setShortcutState("busy");
    try {
      await createQuickLaunchShortcut();
      setShortcutState("done");
    } catch (error) {
      console.error(error);
      setShortcutState("error");
    }
  };

  return (
    <div>
      <PageHeader
        className="mb-5"
        title={t("appearance-title")}
        description={t("appearance-description")}
      />

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
          <Select.Root
            value={preference}
            onValueChange={(value) => setPreference(value as typeof preference)}
          >
            <Select.Trigger className="w-full sm:w-64" aria-label={t("appearance-section-language")}>
              <Select.Value>
                {(value) => {
                  const option = LOCALE_OPTIONS.find((entry) => entry.value === value);
                  return option ? t(option.labelId) : String(value ?? "");
                }}
              </Select.Value>
            </Select.Trigger>
            <Select.Portal>
              <Select.Positioner>
                <Select.Popup>
                  <Select.List>
                    {LOCALE_OPTIONS.map((option) => (
                      <Select.Item key={option.value} value={option.value}>
                        {t(option.labelId)}
                      </Select.Item>
                    ))}
                  </Select.List>
                </Select.Popup>
              </Select.Positioner>
            </Select.Portal>
          </Select.Root>
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

      <Card.Root className="mt-3">
        <Card.Header>
          <Card.Label>{t("appearance-section-studio")}</Card.Label>
          <Card.Description>{t("appearance-section-studio-description")}</Card.Description>
        </Card.Header>
        <SettingRow
          label={t("engine-tracking-label")}
          description={t("engine-tracking-description")}
        >
          <Toggle
            checked={enableTracking ?? true}
            disabled={!engineLoaded || savingEngine}
            onChange={(checked) => void saveEngineSettings(checked, disableTelemetry ?? false)}
          />
        </SettingRow>
        <SettingRow
          label={t("engine-telemetry-label")}
          description={t("engine-telemetry-description")}
        >
          <Toggle
            checked={disableTelemetry ?? false}
            disabled={!engineLoaded || savingEngine}
            onChange={(checked) => void saveEngineSettings(enableTracking ?? true, checked)}
          />
        </SettingRow>
        {protocolStatus?.supported && (
          <SettingRow
            label={t("studio-protocol-label")}
            description={t("studio-protocol-description")}
          >
            <Toggle
              checked={protocolStatus.enabled}
              disabled={protocolBusy}
              onChange={(checked) => void toggleProtocol(checked)}
            />
          </SettingRow>
        )}
        <SettingRow
          label={t("appearance-autoupdate-label")}
          description={t("appearance-autoupdate-description")}
        >
          <Toggle checked={autoUpdateStudio} onChange={setAutoUpdateStudio} />
        </SettingRow>
        {protocolStatus?.supported && (
          <SettingRow
            label={t("appearance-shortcut-label")}
            description={t("appearance-shortcut-description")}
          >
            <Button.Root
              variant="ghost"
              size="sm"
              disabled={shortcutState === "busy"}
              onClick={() => void createShortcut()}
            >
              <Button.Label>
                {shortcutState === "done"
                  ? t("appearance-shortcut-created")
                  : shortcutState === "error"
                    ? t("appearance-shortcut-error")
                    : t("appearance-shortcut-create")}
              </Button.Label>
            </Button.Root>
          </SettingRow>
        )}
      </Card.Root>

      <div className="mt-3">
        <AboutSection />
      </div>
    </div>
  );
}
