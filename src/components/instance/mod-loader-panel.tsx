import { useQueryClient } from "@tanstack/react-query";
import { listen } from "@tauri-apps/api/event";
import { openUrl } from "@tauri-apps/plugin-opener";
import { ExternalLink, Plus, RefreshCw, ShieldCheck, Trash2 } from "lucide-react";
import { useEffect, useMemo, useState } from "react";

import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Card } from "@/components/ui/card";
import { Progress } from "@/components/ui/progress";
import { Select } from "@/components/ui/select";
import { useI18n } from "@/i18n";
import { formatBytes, getErrorMessage } from "@/lib/format";
import {
  installModLoader,
  isModLoaderUpdateAvailable,
  MODLOADER_INSTALL_EVENT,
  type ModLoaderChannel,
  type ModLoaderInstallProgress,
  type ModLoaderInstalled,
  uninstallModLoader,
} from "@/lib/modloader";
import { queryKeys, useModLoaderReleases } from "@/lib/queries";

const CHANNEL_VARIANTS: Record<ModLoaderChannel, "blue" | "green" | "yellow" | "purple" | "gray"> =
  {
    stable: "green",
    beta: "yellow",
    nightly: "purple",
    experimental: "blue",
    prerelease: "gray",
  };

interface ModLoaderPanelProps {
  versionGuid: string;
  installed: ModLoaderInstalled | null;
}

export function ModLoaderPanel({ versionGuid, installed }: ModLoaderPanelProps) {
  const { formatDate, t } = useI18n();
  const queryClient = useQueryClient();
  const { data: releases = [], isLoading, isFetching, refetch } = useModLoaderReleases();

  const [selectedTag, setSelectedTag] = useState<string | null>(null);
  const [isUninstalling, setIsUninstalling] = useState(false);
  const [activeInstall, setActiveInstall] = useState<ModLoaderInstallProgress | null>(null);
  const [errorMessage, setErrorMessage] = useState<string | null>(null);

  const isInstalling =
    activeInstall !== null &&
    activeInstall.phase !== "completed" &&
    activeInstall.phase !== "failed";
  const isBusy = isInstalling || isUninstalling;

  const selectedRelease = useMemo(
    () => releases.find((release) => release.tag === selectedTag) ?? null,
    [releases, selectedTag],
  );

  useEffect(() => {
    setSelectedTag((current) => {
      if (current && releases.some((release) => release.tag === current)) {
        return current;
      }
      if (installed && releases.some((release) => release.tag === installed.tag)) {
        return installed.tag;
      }
      return releases[0]?.tag ?? null;
    });
  }, [releases, installed]);

  useEffect(() => {
    let disposed = false;
    const unlistenPromise = listen<ModLoaderInstallProgress>(
      MODLOADER_INSTALL_EVENT,
      ({ payload }) => {
        if (disposed || payload.versionGuid !== versionGuid) {
          return;
        }

        if (payload.phase === "failed") {
          setErrorMessage(
            t("modloader-error-install", { message: payload.error ?? t("modloader-error-load") }),
          );
          setActiveInstall(null);
          return;
        }
        if (payload.phase === "completed") {
          setActiveInstall(null);
          return;
        }
        setActiveInstall(payload);
      },
    );

    return () => {
      disposed = true;
      void unlistenPromise.then((unlisten) => unlisten());
    };
  }, [versionGuid, t]);

  const invalidate = async () => {
    await Promise.all([
      queryClient.invalidateQueries({ queryKey: queryKeys.instances }),
      queryClient.invalidateQueries({ queryKey: queryKeys.mods(versionGuid) }),
    ]);
  };

  const handleInstall = async () => {
    if (!selectedRelease) {
      return;
    }
    setErrorMessage(null);
    try {
      await installModLoader(versionGuid, selectedRelease.tag);
      await invalidate();
    } catch (error) {
      setErrorMessage(
        t("modloader-error-install", {
          message: getErrorMessage(error, t("modloader-error-load")),
        }),
      );
    } finally {
      setActiveInstall(null);
    }
  };

  const handleUninstall = async () => {
    setIsUninstalling(true);
    setErrorMessage(null);
    try {
      await uninstallModLoader(versionGuid);
      await invalidate();
    } catch (error) {
      setErrorMessage(
        t("modloader-error-uninstall", {
          message: getErrorMessage(error, t("modloader-error-load")),
        }),
      );
    } finally {
      setIsUninstalling(false);
    }
  };

  const updateAvailable = isModLoaderUpdateAvailable(installed, selectedRelease);
  const isSelectedInstalled = installed !== null && selectedRelease?.tag === installed?.tag;
  const installLabel = !isSelectedInstalled
    ? t("modloader-install")
    : updateAvailable
      ? t("modloader-update")
      : t("modloader-reinstall");
  const progressValue =
    activeInstall && activeInstall.phase !== "resolving"
      ? Math.round(activeInstall.progress)
      : null;
  const phaseLabel = activeInstall ? t(`modloader-phase-${activeInstall.phase}`) : "";

  return (
    <Card.Root highlighted={installed !== null}>
      <Card.Header>
        <div className="flex items-center justify-between gap-2">
          <div className="flex items-center gap-2">
            <Card.Label>{t("modloader-title")}</Card.Label>
            {installed && (
              <Badge.Root variant="green">
                <Badge.Icon>
                  <ShieldCheck size={9} />
                </Badge.Icon>
                <Badge.Label>{t("modloader-badge-installed")}</Badge.Label>
              </Badge.Root>
            )}
            {updateAvailable && (
              <Badge.Root variant="yellow">
                <Badge.Label>{t("modloader-badge-update")}</Badge.Label>
              </Badge.Root>
            )}
          </div>
          <Button.Root
            variant="ghost"
            size="icon"
            disabled={isBusy || isFetching}
            onClick={() => void refetch()}
          >
            <Button.Icon>
              <RefreshCw size={13} className={isFetching ? "animate-spin" : undefined} />
            </Button.Icon>
          </Button.Root>
        </div>
        <Card.Description>{t("modloader-description")}</Card.Description>
      </Card.Header>

      <Card.Body className="flex flex-col gap-3">
        {errorMessage && (
          <div className="rounded-md border border-red/25 bg-red-muted px-3 py-2 text-[11.5px] text-text">
            {errorMessage}
          </div>
        )}

        {isLoading ? (
          <div className="text-[12px] text-text-muted">{t("modloader-loading")}</div>
        ) : releases.length === 0 ? (
          <div className="text-[12px] text-text-muted">{t("modloader-empty")}</div>
        ) : (
          <>
            <div className="flex flex-col gap-1.5">
              <span className="text-[11.5px] font-medium text-text-muted">
                {t("modloader-channel-label")}
              </span>
              <Select.Root
                value={selectedTag ?? ""}
                onValueChange={(value) => setSelectedTag(value)}
                disabled={isBusy}
              >
                <Select.Trigger className="w-full">
                  {selectedRelease ? (
                    <span className="flex min-w-0 items-center gap-2">
                      <span className="truncate">{selectedRelease.name}</span>
                      <Badge.Root variant={CHANNEL_VARIANTS[selectedRelease.channel]}>
                        <Badge.Label>
                          {t(`modloader-channel-${selectedRelease.channel}`)}
                        </Badge.Label>
                      </Badge.Root>
                    </span>
                  ) : (
                    <span className="text-text-dim">{t("modloader-channel-placeholder")}</span>
                  )}
                </Select.Trigger>
                <Select.Portal>
                  <Select.Positioner>
                    <Select.Popup>
                      <Select.List>
                        {releases.map((release) => (
                          <Select.Item key={release.tag} value={release.tag}>
                            <span className="flex min-w-0 flex-1 items-center gap-2">
                              <span className="truncate">{release.name}</span>
                              <Badge.Root variant={CHANNEL_VARIANTS[release.channel]}>
                                <Badge.Label>
                                  {t(`modloader-channel-${release.channel}`)}
                                </Badge.Label>
                              </Badge.Root>
                              <span className="ml-auto text-[10.5px] text-text-dim tabular-nums">
                                {formatBytes(release.asset.size)}
                              </span>
                            </span>
                          </Select.Item>
                        ))}
                      </Select.List>
                    </Select.Popup>
                  </Select.Positioner>
                </Select.Portal>
              </Select.Root>
            </div>

            <div className="text-[11px] text-text-muted">
              {installed
                ? t("modloader-status-installed", {
                    name: installed.name,
                    date: formatDate(installed.installedAt),
                  })
                : t("modloader-status-none")}
            </div>

            {activeInstall && (
              <div className="flex flex-col gap-1.5">
                <div className="flex items-center justify-between text-[11px] text-text-muted">
                  <span>{phaseLabel}</span>
                  {activeInstall.phase === "downloading" && activeInstall.totalBytes > 0 && (
                    <span className="tabular-nums">
                      {formatBytes(activeInstall.downloadedBytes)} /{" "}
                      {formatBytes(activeInstall.totalBytes)}
                    </span>
                  )}
                </div>
                <Progress.Root value={progressValue} aria-label={phaseLabel}>
                  <Progress.Track>
                    <Progress.Indicator />
                  </Progress.Track>
                </Progress.Root>
              </div>
            )}

            <div className="flex flex-wrap items-center gap-2">
              <Button.Root
                variant="primary"
                disabled={!selectedRelease || isBusy}
                onClick={() => void handleInstall()}
              >
                <Button.Icon>
                  {isInstalling ? (
                    <RefreshCw size={13} className="animate-spin" />
                  ) : isSelectedInstalled && !updateAvailable ? (
                    <RefreshCw size={13} />
                  ) : (
                    <Plus size={13} />
                  )}
                </Button.Icon>
                <Button.Label>{installLabel}</Button.Label>
              </Button.Root>

              {selectedRelease && (
                <Button.Root
                  variant="ghost"
                  disabled={isInstalling}
                  onClick={() => openUrl(selectedRelease.htmlUrl).catch(console.error)}
                >
                  <Button.Icon>
                    <ExternalLink size={13} />
                  </Button.Icon>
                  <Button.Label>{t("modloader-view-release")}</Button.Label>
                </Button.Root>
              )}

              {installed && (
                <Button.Root
                  variant="danger"
                  className="ml-auto"
                  disabled={isBusy}
                  onClick={() => void handleUninstall()}
                >
                  <Button.Icon>
                    {isUninstalling ? (
                      <RefreshCw size={13} className="animate-spin" />
                    ) : (
                      <Trash2 size={13} />
                    )}
                  </Button.Icon>
                  <Button.Label>{t("modloader-uninstall")}</Button.Label>
                </Button.Root>
              )}
            </div>
          </>
        )}
      </Card.Body>
    </Card.Root>
  );
}
