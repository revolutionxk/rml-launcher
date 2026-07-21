import { useQueryClient } from "@tanstack/react-query";
import { createFileRoute, useNavigate } from "@tanstack/react-router";
import { listen } from "@tauri-apps/api/event";
import {
  ArrowLeft,
  FolderOpen,
  MoreHorizontal,
  Play,
  Plus,
  RefreshCw,
  Search,
  ShieldCheck,
  Star,
  Trash2,
} from "lucide-react";
import { type CSSProperties, useDeferredValue, useEffect, useState } from "react";
import { AutoSizer, List, type ListRowProps } from "react-virtualized";

import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Callout } from "@/components/ui/callout";
import { Input } from "@/components/ui/input";
import { Menu } from "@/components/ui/menu";
import { PageHeader } from "@/components/ui/page-header";
import { LoadingState } from "@/components/ui/spinner";
import { Progress } from "@/components/ui/progress";
import { useI18n } from "@/i18n";
import { queryKeys, useStudioVersions } from "@/lib/queries";
import {
  can,
  Capability,
  installStudioVersion,
  launchStudio,
  openStudioInstallDir,
  revalidateStudioVersion,
  setDefaultStudioVersion,
  type StudioInstallProgress,
  type StudioVersionRecord,
  uninstallStudio,
} from "@/lib/studio";

const VERSION_ROW_HEIGHT = 84;
const VERSION_LIST_OVERSCAN = 6;

export const Route = createFileRoute("/settings/versions")({
  component: VersionsPage,
});

function getErrorMessage(error: unknown, fallback: string) {
  if (typeof error === "string" && error.length > 0) {
    return error;
  }

  if (error instanceof Error && error.message.length > 0) {
    return error.message;
  }

  return fallback;
}

function matchesVersionQuery(version: StudioVersionRecord, query: string) {
  const haystack = [version.version, version.versionGuid, version.channel].join(" ").toLowerCase();

  return haystack.includes(query);
}

interface VersionActionsMenuProps {
  version: StudioVersionRecord;
  isBusy: boolean;
  onToggleDefault: (version: StudioVersionRecord) => Promise<void>;
  onOpenInstallDir: (installationId: string) => Promise<void>;
  onRevalidate: (installationId: string) => Promise<void>;
  onDelete: (installationId: string) => Promise<void>;
  t: ReturnType<typeof useI18n>["t"];
}

function VersionActionsMenu({
  version,
  isBusy,
  onToggleDefault,
  onOpenInstallDir,
  onRevalidate,
  onDelete,
  t,
}: VersionActionsMenuProps) {
  return (
    <Menu.Root>
      <Menu.Trigger
        render={
          <Button.Root
            variant="ghost"
            size="icon-sm"
            aria-label={t("versions-actions")}
            disabled={isBusy}
          >
            <Button.Icon>
              <MoreHorizontal size={14} />
            </Button.Icon>
          </Button.Root>
        }
      />
      <Menu.Portal>
        <Menu.Positioner>
          <Menu.Popup>
            <Menu.Item
              disabled={isBusy}
              onClick={() => {
                void onToggleDefault(version);
              }}
            >
              <span
                className={`flex h-[14px] w-[14px] items-center justify-center ${
                  version.isDefault ? "text-yellow" : "text-text-dim"
                }`}
              >
                <Star size={13} />
              </span>
              <span>
                {version.isDefault ? t("versions-clear-default") : t("versions-set-default")}
              </span>
            </Menu.Item>
            {can(version, Capability.Revalidate) && (
              <Menu.Item
                disabled={isBusy}
                onClick={() => {
                  void onRevalidate(version.id);
                }}
              >
                <span className="flex h-[14px] w-[14px] items-center justify-center text-text-dim">
                  <ShieldCheck size={13} />
                </span>
                <span>{t("versions-revalidate")}</span>
              </Menu.Item>
            )}
            <Menu.Item
              disabled={isBusy}
              onClick={() => {
                void onOpenInstallDir(version.id);
              }}
            >
              <span className="flex h-[14px] w-[14px] items-center justify-center text-text-dim">
                <FolderOpen size={13} />
              </span>
              <span>{t("versions-open-folder")}</span>
            </Menu.Item>
            {can(version, Capability.Uninstall) && (
              <Menu.Item
                disabled={isBusy}
                className="text-red data-[highlighted]:text-red"
                onClick={() => {
                  void onDelete(version.id);
                }}
              >
                <span className="flex h-[14px] w-[14px] items-center justify-center text-red/85">
                  <Trash2 size={13} />
                </span>
                <span>{t("versions-uninstall")}</span>
              </Menu.Item>
            )}
          </Menu.Popup>
        </Menu.Positioner>
      </Menu.Portal>
    </Menu.Root>
  );
}

function VersionsPage() {
  const { formatDate, t } = useI18n();
  const navigate = useNavigate();
  const queryClient = useQueryClient();
  const { data: versions = [], isLoading, isFetching, error } = useStudioVersions();
  const [activeInstall, setActiveInstall] = useState<StudioInstallProgress | null>(null);
  const [errorMessage, setErrorMessage] = useState<string | null>(null);
  const [launchingVersionId, setLaunchingVersionId] = useState<string | null>(null);
  const [openingVersionId, setOpeningVersionId] = useState<string | null>(null);
  const [revalidatingVersionId, setRevalidatingVersionId] = useState<string | null>(null);
  const [uninstallingVersionId, setUninstallingVersionId] = useState<string | null>(null);
  const [defaultingVersionId, setDefaultingVersionId] = useState<string | null>(null);
  const [searchQuery, setSearchQuery] = useState("");

  const isRefreshing = isFetching && !isLoading;
  const loadErrorMessage = error ? getErrorMessage(error, t("versions-error-generic")) : null;
  const deferredSearchQuery = useDeferredValue(searchQuery.trim().toLowerCase());
  const isInstalling =
    activeInstall !== null &&
    activeInstall.phase !== "completed" &&
    activeInstall.phase !== "failed";
  const latestAvailable =
    versions.find((version) => version.isLatest && !version.isInstalled) ?? null;
  const filteredVersions =
    deferredSearchQuery.length > 0
      ? versions.filter((version) => matchesVersionQuery(version, deferredSearchQuery))
      : versions;
  const hasSearchQuery = deferredSearchQuery.length > 0;
  const listKey = hasSearchQuery ? `search:${deferredSearchQuery}` : "all";
  
  const refreshVersions = async () => {
    await Promise.all([
      queryClient.invalidateQueries({ queryKey: queryKeys.studioVersions }),
      queryClient.invalidateQueries({ queryKey: queryKeys.instances }),
    ]);
  };

  useEffect(() => {
    let disposed = false;
    const unlistenPromise = listen<StudioInstallProgress>(
      "studio-install-progress",
      ({ payload }) => {
        if (disposed) {
          return;
        }

        if (payload.phase === "failed") {
          setErrorMessage(
            t("versions-error-install", {
              message: payload.error ?? t("versions-error-generic"),
            }),
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
  }, [t]);

  const handleInstall = async (version: StudioVersionRecord) => {
    setErrorMessage(null);

    try {
      await installStudioVersion(version);
      await refreshVersions();
    } catch (error) {
      setErrorMessage(
        t("versions-error-install", {
          message: getErrorMessage(error, t("versions-error-generic")),
        }),
      );
    } finally {
      setActiveInstall(null);
    }
  };

  const handleLaunch = async (installationId: string) => {
    setLaunchingVersionId(installationId);
    setErrorMessage(null);

    try {
      await launchStudio(installationId);
    } catch (error) {
      setErrorMessage(
        t("versions-error-launch", {
          message: getErrorMessage(error, t("versions-error-generic")),
        }),
      );
    } finally {
      setLaunchingVersionId(null);
    }
  };

  const handleDelete = async (installationId: string) => {
    setUninstallingVersionId(installationId);
    setErrorMessage(null);

    try {
      await uninstallStudio(installationId);
      await refreshVersions();
    } catch (error) {
      setErrorMessage(
        t("versions-error-uninstall", {
          message: getErrorMessage(error, t("versions-error-generic")),
        }),
      );
    } finally {
      setUninstallingVersionId(null);
    }
  };

  const handleToggleDefault = async (version: StudioVersionRecord) => {
    setDefaultingVersionId(version.id);
    setErrorMessage(null);

    try {
      await setDefaultStudioVersion(version.isDefault ? null : version.id);
      await refreshVersions();
    } catch (error) {
      setErrorMessage(getErrorMessage(error, t("versions-error-generic")));
    } finally {
      setDefaultingVersionId(null);
    }
  };

  const handleOpenInstallDir = async (installationId: string) => {
    setOpeningVersionId(installationId);
    setErrorMessage(null);

    try {
      await openStudioInstallDir(installationId);
    } catch (error) {
      setErrorMessage(
        t("versions-error-open-folder", {
          message: getErrorMessage(error, t("versions-error-generic")),
        }),
      );
    } finally {
      setOpeningVersionId(null);
    }
  };

  const handleRevalidate = async (installationId: string) => {
    setRevalidatingVersionId(installationId);
    setErrorMessage(null);

    try {
      await revalidateStudioVersion(installationId);
      await refreshVersions();
    } catch (error) {
      setErrorMessage(
        t("versions-error-revalidate", {
          message: getErrorMessage(error, t("versions-error-generic")),
        }),
      );
    } finally {
      setRevalidatingVersionId(null);
    }
  };

  const renderVersionRow = ({ index, key, style }: ListRowProps) => {
    const version = filteredVersions[index];
    const installState = activeInstall?.versionGuid === version.versionGuid ? activeInstall : null;
    const isDownloading = installState !== null;
    const isRevalidating = revalidatingVersionId === version.id;
    const progress = installState ? Math.round(installState.progress) : 0;
    const publishedDate = version.publishedAt ? formatDate(version.publishedAt) : null;
    const integrityDate = version.integrityVerifiedAt
      ? formatDate(version.integrityVerifiedAt)
      : null;
    const isBusy =
      isInstalling ||
      launchingVersionId === version.id ||
      openingVersionId === version.id ||
      defaultingVersionId === version.id ||
      isRevalidating ||
      uninstallingVersionId === version.id;

    let metadata = publishedDate
      ? t("versions-meta-history", {
          date: publishedDate,
          channel: version.channel,
        })
      : t("versions-meta-available", { channel: version.channel });

    if (version.isInstalled && !isDownloading) {
      metadata = t("versions-meta-installed", {
        date: version.installedAt ? formatDate(version.installedAt) : "",
        channel: version.channel,
      });
    }

    if (isDownloading) {
      metadata = t("versions-meta-downloading", {
        progress,
        channel: version.channel,
      });
    }

    if (installState?.phase === "resolving") {
      metadata = t("versions-meta-resolving", { channel: version.channel });
    }

    if (installState?.phase === "extracting") {
      metadata = t("versions-meta-extracting", {
        done: installState.extractedPackages,
        total: installState.totalPackages,
        channel: version.channel,
      });
    }

    if (installState?.phase === "finalizing") {
      metadata = t("versions-meta-finalizing", { channel: version.channel });
    }

    if (isRevalidating) {
      metadata = t("versions-meta-revalidating", { channel: version.channel });
    }

    const rowStyle: CSSProperties = {
      ...style,
      boxSizing: "border-box",
      padding: "4px 6px",
      width: "100%",
    };

    return (
      <div key={key} style={rowStyle}>
        <div
          className="flex h-full items-center gap-2.5 rounded-sm border border-border bg-card px-3.5 py-2.5 transition-[border-color,background] duration-200 hover:border-[#2e2e2e] hover:bg-card-hover"
          style={
            version.isLatest
              ? {
                  borderColor: "color-mix(in srgb, var(--color-accent) 30%, transparent)",
                  backgroundColor: "color-mix(in srgb, var(--color-accent) 4%, transparent)",
                }
              : undefined
          }
        >
          <div
            className={`h-2 w-2 shrink-0 rounded-full ${
              isDownloading || isRevalidating
                ? "animate-pulse-dot bg-yellow"
                : version.isInstalled
                  ? "bg-green shadow-[0_0_6px_rgba(61,204,122,0.3)]"
                  : "bg-text-dim"
            }`}
          />

          <div className="min-w-0 flex-1">
            <div className="flex flex-wrap items-center gap-1.5 text-[12.5px] font-semibold text-text">
              <span>{t("versions-studio-label", { version: version.version })}</span>
              {version.isLatest && !isDownloading && (
                <Badge.Root variant="blue">
                  <Badge.Icon>
                    <Star size={9} />
                  </Badge.Icon>
                  <Badge.Label>{t("versions-badge-latest")}</Badge.Label>
                </Badge.Root>
              )}
              {version.isDefault && !isDownloading && (
                <Badge.Root variant="yellow">
                  <Badge.Icon>
                    <Star size={9} />
                  </Badge.Icon>
                  <Badge.Label>{t("versions-badge-default")}</Badge.Label>
                </Badge.Root>
              )}
              {isDownloading && (
                <Badge.Root variant="yellow">
                  <Badge.Label>{t("versions-badge-downloading")}</Badge.Label>
                </Badge.Root>
              )}
              {isRevalidating && (
                <Badge.Root variant="yellow">
                  <Badge.Label>{t("versions-badge-revalidating")}</Badge.Label>
                </Badge.Root>
              )}
              {version.isInstalled && !version.isLatest && !isDownloading && (
                <Badge.Root variant="green">
                  <Badge.Label>{t("versions-badge-installed")}</Badge.Label>
                </Badge.Root>
              )}
              {version.isInstalled && !isDownloading && version.integrityVerifiedAt && (
                <Badge.Root variant="green">
                  <Badge.Label>{t("versions-badge-verified")}</Badge.Label>
                </Badge.Root>
              )}
            </div>

            <div className="mt-0.5 text-[10.75px] text-text-muted">{metadata}</div>

            {integrityDate && version.isInstalled && !isDownloading && !isRevalidating && (
              <div className="mt-0.5 text-[10.5px] text-text-dim">
                {t("versions-integrity-verified", { date: integrityDate })}
              </div>
            )}

            {installState?.currentPackage && (
              <div className="mt-0.5 truncate text-[10.5px] text-text-dim">
                {t("versions-current-package", {
                  name: installState.currentPackage.replace(/\.zip$/i, ""),
                })}
              </div>
            )}

            {isDownloading && (
              <div className="mt-1.5">
                <Progress.Root
                  value={installState.phase === "resolving" ? null : progress}
                  aria-label={t("versions-badge-downloading")}
                >
                  <Progress.Track>
                    <Progress.Indicator />
                  </Progress.Track>
                </Progress.Root>
              </div>
            )}
          </div>

          <div className="shrink-0">
            {!version.isInstalled && !isDownloading && (
              <Button.Root
                variant="ghost"
                size="sm"
                disabled={isInstalling}
                onClick={() => {
                  void handleInstall(version);
                }}
              >
                <Button.Label>{t("versions-install")}</Button.Label>
              </Button.Root>
            )}

            {version.isInstalled && !isDownloading && (
              <div className="flex items-center gap-1">
                <Button.Root
                  variant="primary"
                  size="icon-sm"
                  aria-label={t("versions-launch")}
                  disabled={isBusy}
                  onClick={() => {
                    void handleLaunch(version.id);
                  }}
                >
                  <Button.Icon>
                    {launchingVersionId === version.id ? (
                      <RefreshCw size={13} className="animate-spin" />
                    ) : (
                      <Play size={13} />
                    )}
                  </Button.Icon>
                </Button.Root>

                <VersionActionsMenu
                  version={version}
                  isBusy={isBusy}
                  onToggleDefault={handleToggleDefault}
                  onOpenInstallDir={handleOpenInstallDir}
                  onRevalidate={handleRevalidate}
                  onDelete={handleDelete}
                  t={t}
                />
              </div>
            )}
          </div>
        </div>
      </div>
    );
  };

  return (
    <div className="flex h-full min-h-0 flex-col">
      <button
        className="mb-3 flex w-fit shrink-0 items-center gap-1.5 rounded-sm text-[12.5px] text-text-muted outline-none transition-colors hover:text-text focus-visible:ring-2 focus-visible:ring-accent/40"
        onClick={() => navigate({ to: "/settings/instances" })}
      >
        <ArrowLeft size={13} />
        {t("versions-back")}
      </button>
      <PageHeader
        className="mb-5 shrink-0"
        title={t("versions-title")}
        description={t("versions-description")}
      />

      <div className="mb-4 shrink-0 flex flex-col gap-2 lg:flex-row lg:items-center lg:justify-between">
        <div className="flex flex-wrap gap-2">
          <Button.Root
            variant="primary"
            disabled={!latestAvailable || isInstalling || isLoading}
            onClick={() => {
              if (latestAvailable) {
                void handleInstall(latestAvailable);
              }
            }}
          >
            <Button.Icon>
              <Plus size={13} />
            </Button.Icon>
            <Button.Label>{t("versions-download")}</Button.Label>
          </Button.Root>
          <Button.Root
            variant="ghost"
            disabled={isInstalling || isRefreshing}
            onClick={() => {
              void refreshVersions();
            }}
          >
            <Button.Icon>
              <RefreshCw size={13} className={isRefreshing ? "animate-spin" : undefined} />
            </Button.Icon>
            <Button.Label>{t("versions-check-updates")}</Button.Label>
          </Button.Root>
        </div>

        <Input.Root className="w-full lg:max-w-[340px]">
          <Input.Icon>
            <Search size={13} />
          </Input.Icon>
          <Input.Field
            hasLeadingIcon
            value={searchQuery}
            aria-label={t("versions-search")}
            placeholder={t("versions-search-placeholder")}
            onChange={(event) => {
              setSearchQuery(event.currentTarget.value);
            }}
          />
        </Input.Root>
      </div>

      {(errorMessage ?? loadErrorMessage) && (
        <Callout variant="danger" className="mb-4 shrink-0">
          {errorMessage ?? loadErrorMessage}
        </Callout>
      )}

      {isLoading ? (
        <LoadingState label={t("versions-loading")} className="shrink-0" />
      ) : filteredVersions.length === 0 ? (
        <div className="rounded-sm border border-border bg-card px-4 py-4 text-[12.5px] text-text-muted">
          {hasSearchQuery ? t("versions-empty-search") : t("versions-empty")}
        </div>
      ) : null}

      {!isLoading && versions.length > 0 && (
        <div className="mb-3 text-[11.5px] text-text-muted">
          {hasSearchQuery
            ? t("versions-total-filtered", {
                count: filteredVersions.length,
                total: versions.length,
              })
            : t("versions-total", { count: versions.length })}
        </div>
      )}

      {!isLoading && filteredVersions.length > 0 && (
        <div className="min-h-0 flex-1">
          <div
            className="h-full overflow-hidden rounded-sm border border-border bg-card/40"
            style={{ scrollbarGutter: "stable" }}
          >
            <AutoSizer>
              {({ height, width }) => {
                if (height <= 0 || width <= 0) {
                  return null;
                }

                return (
                  <List
                    key={listKey}
                    width={width}
                    height={height}
                    rowCount={filteredVersions.length}
                    rowHeight={VERSION_ROW_HEIGHT}
                    rowRenderer={renderVersionRow}
                    overscanRowCount={VERSION_LIST_OVERSCAN}
                    style={{ outline: "none", overflowX: "hidden" }}
                  />
                );
              }}
            </AutoSizer>
          </div>
        </div>
      )}
    </div>
  );
}
