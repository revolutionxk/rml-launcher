import { useQueryClient } from "@tanstack/react-query";
import { Info, Play, RefreshCw, Wine } from "lucide-react";
import { useState } from "react";

import { Button } from "@/components/ui/button";
import { useI18n } from "@/i18n";
import { getErrorMessage } from "@/lib/format";
import { installVinegar, launchVinegar } from "@/lib/platform";
import { queryKeys, useHostInfo, useVinegarStatus } from "@/lib/queries";

export function PlatformNotice() {
  const { t } = useI18n();
  const queryClient = useQueryClient();
  const { data: host } = useHostInfo();
  const isLinux = host?.os === "linux";
  const { data: vinegar } = useVinegarStatus(isLinux);

  const [busy, setBusy] = useState<"install" | "launch" | null>(null);
  const [errorMessage, setErrorMessage] = useState<string | null>(null);

  if (!host || host.os === "windows") {
    return null;
  }

  const handleInstall = async () => {
    setBusy("install");
    setErrorMessage(null);
    try {
      await installVinegar();
      await Promise.all([
        queryClient.invalidateQueries({ queryKey: queryKeys.vinegarStatus }),
        queryClient.invalidateQueries({ queryKey: queryKeys.hostInfo }),
      ]);
    } catch (error) {
      setErrorMessage(t("vinegar-error-install", { message: getErrorMessage(error, t("instances-error-generic")) }));
    } finally {
      setBusy(null);
    }
  };

  const handleLaunch = async () => {
    setBusy("launch");
    setErrorMessage(null);
    try {
      await launchVinegar();
    } catch (error) {
      setErrorMessage(t("vinegar-error-launch", { message: getErrorMessage(error, t("instances-error-generic")) }));
    } finally {
      setBusy(null);
    }
  };

  const message =
    host.os === "macos"
      ? t("platform-notice-macos")
      : vinegar?.installed
        ? t("platform-notice-linux-vinegar")
        : t("platform-notice-linux-no-vinegar");

  return (
    <div className="mb-4 shrink-0 rounded-sm border border-yellow/25 bg-yellow-muted px-4 py-3">
      <div className="flex items-start gap-2.5">
        <Wine size={15} className="mt-0.5 shrink-0 text-yellow" />
        <div className="min-w-0 flex-1">
          <div className="text-[12px] text-text">{message}</div>

          {isLinux && (
            <div className="mt-2 flex flex-wrap items-center gap-2">
              {vinegar?.installed ? (
                <Button.Root
                  variant="primary"
                  size="sm"
                  disabled={busy !== null}
                  onClick={() => void handleLaunch()}
                >
                  <Button.Icon>
                    {busy === "launch" ? (
                      <RefreshCw size={12} className="animate-spin" />
                    ) : (
                      <Play size={12} />
                    )}
                  </Button.Icon>
                  <Button.Label>{t("vinegar-launch")}</Button.Label>
                </Button.Root>
              ) : vinegar?.flatpakAvailable ? (
                <Button.Root
                  variant="primary"
                  size="sm"
                  disabled={busy !== null}
                  onClick={() => void handleInstall()}
                >
                  <Button.Icon>
                    {busy === "install" ? (
                      <RefreshCw size={12} className="animate-spin" />
                    ) : (
                      <Wine size={12} />
                    )}
                  </Button.Icon>
                  <Button.Label>{t("vinegar-install")}</Button.Label>
                </Button.Root>
              ) : (
                <span className="inline-flex items-center gap-1.5 text-[11px] text-text-muted">
                  <Info size={12} />
                  {t("vinegar-flatpak-required")}
                </span>
              )}
            </div>
          )}

          {errorMessage && (
            <div className="mt-2 text-[11.5px] text-red">{errorMessage}</div>
          )}
        </div>
      </div>
    </div>
  );
}
