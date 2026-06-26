import { useQueryClient } from "@tanstack/react-query";
import { Info, Play, RefreshCw, Wine } from "lucide-react";
import { useState } from "react";

import { ModLoaderPanel } from "@/components/instance/mod-loader-panel";
import { ModsPanel } from "@/components/instance/mods-panel";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Card } from "@/components/ui/card";
import { useI18n } from "@/i18n";
import { getErrorMessage } from "@/lib/format";
import { installVinegar, launchVinegar, VINEGAR_INSTANCE_ID } from "@/lib/platform";
import { queryKeys, useModLoaderStatus, useVinegarStatus } from "@/lib/queries";

export function VinegarStudio() {
  const { t } = useI18n();
  const queryClient = useQueryClient();
  const { data: vinegar, isLoading } = useVinegarStatus(true);

  const installed = vinegar?.installed ?? false;
  const studioFound = vinegar?.studioFound ?? false;
  const { data: modloader } = useModLoaderStatus(VINEGAR_INSTANCE_ID, studioFound);

  const [busy, setBusy] = useState<"install" | "launch" | null>(null);
  const [errorMessage, setErrorMessage] = useState<string | null>(null);

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
      await queryClient.invalidateQueries({ queryKey: queryKeys.vinegarStatus });
    } catch (error) {
      setErrorMessage(t("vinegar-error-launch", { message: getErrorMessage(error, t("instances-error-generic")) }));
    } finally {
      setBusy(null);
    }
  };

  return (
    <div className="flex h-full min-h-0 flex-col">
      <div className="mb-4 shrink-0">
        <div className="flex items-center gap-2">
          <span className="flex h-7 w-7 items-center justify-center rounded-lg icon-box--purple">
            <Wine size={15} />
          </span>
          <h1 className="text-[18px] font-semibold leading-tight tracking-[-0.018em] text-text">
            {t("vinegar-studio-title")}
          </h1>
          {installed && (
            <Badge.Root variant="green">
              <Badge.Label>{t("vinegar-badge-installed")}</Badge.Label>
            </Badge.Root>
          )}
        </div>
        <p className="mt-1 text-[12.5px] leading-normal text-text-muted">
          {t("vinegar-studio-description")}
        </p>
      </div>

      {errorMessage && (
        <div className="mb-4 shrink-0 rounded-lg border border-red/25 bg-red-muted px-4 py-3 text-[12px] text-text">
          {errorMessage}
        </div>
      )}

      <div className="min-h-0 flex-1 overflow-y-auto pr-0.5" style={{ scrollbarGutter: "stable" }}>
        <div className="flex flex-col gap-4 pb-2">
          {isLoading ? (
            <div className="rounded-lg border border-border bg-card px-4 py-4 text-[12.5px] text-text-muted">
              {t("vinegar-loading")}
            </div>
          ) : !installed ? (
            <SetupCard
              title={t("vinegar-setup-install-title")}
              description={t("platform-notice-linux-no-vinegar")}
            >
              {vinegar?.flatpakAvailable ? (
                <Button.Root variant="primary" disabled={busy !== null} onClick={() => void handleInstall()}>
                  <Button.Icon>
                    {busy === "install" ? (
                      <RefreshCw size={13} className="animate-spin" />
                    ) : (
                      <Wine size={13} />
                    )}
                  </Button.Icon>
                  <Button.Label>{t("vinegar-install")}</Button.Label>
                </Button.Root>
              ) : (
                <span className="inline-flex items-center gap-1.5 text-[11.5px] text-text-muted">
                  <Info size={13} />
                  {t("vinegar-flatpak-required")}
                </span>
              )}
            </SetupCard>
          ) : !studioFound ? (
            <SetupCard
              title={t("vinegar-setup-studio-title")}
              description={t("vinegar-setup-studio-description")}
            >
              <Button.Root variant="primary" disabled={busy !== null} onClick={() => void handleLaunch()}>
                <Button.Icon>
                  {busy === "launch" ? (
                    <RefreshCw size={13} className="animate-spin" />
                  ) : (
                    <Play size={13} />
                  )}
                </Button.Icon>
                <Button.Label>{t("vinegar-launch")}</Button.Label>
              </Button.Root>
            </SetupCard>
          ) : (
            <>
              <Card.Root>
                <div className="flex flex-wrap items-center justify-between gap-3 px-4 py-3">
                  <div className="min-w-0">
                    <div className="text-[12.5px] font-medium text-text">
                      {t("vinegar-ready-title")}
                    </div>
                    <div className="mt-0.5 text-[11px] text-text-muted">
                      {t("vinegar-ready-description")}
                    </div>
                  </div>
                  <Button.Root variant="primary" disabled={busy !== null} onClick={() => void handleLaunch()}>
                    <Button.Icon>
                      {busy === "launch" ? (
                        <RefreshCw size={13} className="animate-spin" />
                      ) : (
                        <Play size={13} />
                      )}
                    </Button.Icon>
                    <Button.Label>{t("vinegar-launch")}</Button.Label>
                  </Button.Root>
                </div>
              </Card.Root>

              <ModLoaderPanel versionGuid={VINEGAR_INSTANCE_ID} installed={modloader ?? null} />
              <ModsPanel versionGuid={VINEGAR_INSTANCE_ID} />
            </>
          )}
        </div>
      </div>
    </div>
  );
}

function SetupCard({
  title,
  description,
  children,
}: {
  title: string;
  description: string;
  children: React.ReactNode;
}) {
  return (
    <div className="flex flex-col items-center gap-3 rounded-2xl border border-border bg-card px-6 py-12 text-center shadow-(--card-shadow)">
      <div className="flex h-14 w-14 items-center justify-center rounded-2xl icon-box--purple">
        <Wine size={26} />
      </div>
      <div className="text-[14px] font-semibold text-text">{title}</div>
      <div className="max-w-sm text-[12px] leading-relaxed text-text-muted">{description}</div>
      <div className="mt-1">{children}</div>
    </div>
  );
}
