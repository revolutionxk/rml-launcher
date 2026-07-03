import { createFileRoute, useNavigate } from "@tanstack/react-router";
import { Package, Play, Plus, Puzzle, RefreshCw, Search } from "lucide-react";
import { motion } from "motion/react";
import { useDeferredValue, useState } from "react";

import { VinegarStudio } from "@/components/instance/vinegar-studio";
import { PlatformNotice } from "@/components/platform-notice";
import { Button } from "@/components/ui/button";
import { EmptyState } from "@/components/ui/empty-state";
import { Input } from "@/components/ui/input";
import { PageHeader } from "@/components/ui/page-header";
import { LoadingState } from "@/components/ui/spinner";
import { useI18n } from "@/i18n";
import { getErrorMessage } from "@/lib/format";
import type { InstanceSummary } from "@/lib/instances";
import { useHostInfo, useInstances, useModLoaderReleases } from "@/lib/queries";
import { launchStudio } from "@/lib/studio";
import { cn } from "@/lib/utils";

export const Route = createFileRoute("/settings/instances/")({
  component: InstancesPage,
});

const MORPH_TRANSITION = {
  duration: 0.42,
  ease: [0.32, 0.72, 0, 1] as [number, number, number, number],
};

function matchesQuery(instance: InstanceSummary, query: string) {
  return [
    instance.version,
    instance.versionGuid,
    instance.modloader?.name ?? "",
    instance.modloader?.channel ?? "",
  ]
    .join(" ")
    .toLowerCase()
    .includes(query);
}

function InstancesPage() {
  const { t } = useI18n();
  const navigate = useNavigate();
  const { data: host } = useHostInfo();
  const { data: instances = [], isLoading, isFetching, refetch } = useInstances();
  const { data: releases = [] } = useModLoaderReleases();

  const [launchingId, setLaunchingId] = useState<string | null>(null);
  const [errorMessage, setErrorMessage] = useState<string | null>(null);
  const [searchQuery, setSearchQuery] = useState("");

  const deferredQuery = useDeferredValue(searchQuery.trim().toLowerCase());
  const hasQuery = deferredQuery.length > 0;
  const filtered = hasQuery
    ? instances.filter((instance) => matchesQuery(instance, deferredQuery))
    : instances;

  const updateAvailableFor = (instance: InstanceSummary) => {
    if (!instance.modloader) {
      return false;
    }
    const release = releases.find((candidate) => candidate.tag === instance.modloader?.tag);
    if (!release) {
      return false;
    }
    if (instance.modloader.assetSha256 && release.asset.sha256) {
      return instance.modloader.assetSha256.toLowerCase() !== release.asset.sha256.toLowerCase();
    }
    return instance.modloader.assetUpdatedAt !== release.asset.updatedAt;
  };

  const handleLaunch = async (instance: InstanceSummary) => {
    setLaunchingId(instance.versionGuid);
    setErrorMessage(null);
    try {
      await launchStudio(instance.versionGuid);
    } catch (error) {
      setErrorMessage(
        t("instances-error-launch", {
          message: getErrorMessage(error, t("instances-error-generic")),
        }),
      );
    } finally {
      setLaunchingId(null);
    }
  };

  const openInstance = (versionGuid: string) => {
    void navigate({ to: "/settings/instances/$versionGuid", params: { versionGuid } });
  };

  if (host?.os === "linux") {
    return <VinegarStudio />;
  }

  return (
    <div className="flex h-full min-h-0 flex-col">
      <div className="mb-4 shrink-0">
        <PageHeader
          title={t("instances-title")}
          description={t("instances-description")}
          badge={
            instances.length > 0 && (
              <span className="rounded-full bg-surface-2 px-2 py-0.5 text-[10.5px] font-medium text-text-muted tabular-nums">
                {t("instances-count", { count: instances.length })}
              </span>
            )
          }
          actions={
            <>
              <Button.Root
                variant="ghost"
                size="icon"
                aria-label={t("instances-title")}
                disabled={isFetching}
                onClick={() => void refetch()}
              >
                <Button.Icon>
                  <RefreshCw size={13} className={isFetching ? "animate-spin" : undefined} />
                </Button.Icon>
              </Button.Root>
              <Button.Root variant="primary" onClick={() => navigate({ to: "/settings/versions" })}>
                <Button.Icon>
                  <Plus size={13} />
                </Button.Icon>
                <Button.Label>{t("instances-add")}</Button.Label>
              </Button.Root>
            </>
          }
        />

        {instances.length > 0 && (
          <Input.Root className="mt-3 w-full">
            <Input.Icon>
              <Search size={13} />
            </Input.Icon>
            <Input.Field
              hasLeadingIcon
              value={searchQuery}
              placeholder={t("instances-search-placeholder")}
              aria-label={t("instances-search-placeholder")}
              onChange={(event) => setSearchQuery(event.currentTarget.value)}
            />
          </Input.Root>
        )}
      </div>

      <PlatformNotice />

      {errorMessage && (
        <div className="mb-4 shrink-0 rounded-sm border border-red/25 bg-red-muted px-4 py-3 text-[12px] text-text">
          {errorMessage}
        </div>
      )}

      {isLoading ? (
        <LoadingState label={t("instances-loading")} />
      ) : instances.length === 0 ? (
        <div className="flex min-h-0 flex-1 items-center justify-center">
          <EmptyState
            className="w-full max-w-sm"
            icon={<Package size={26} />}
            title={t("instances-empty-title")}
            description={t("instances-empty-description")}
            action={
              <Button.Root variant="primary" onClick={() => navigate({ to: "/settings/versions" })}>
                <Button.Icon>
                  <Plus size={13} />
                </Button.Icon>
                <Button.Label>{t("instances-add")}</Button.Label>
              </Button.Root>
            }
          />
        </div>
      ) : filtered.length === 0 ? (
        <div className="rounded-sm border border-border bg-card px-4 py-4 text-[12.5px] text-text-muted">
          {t("instances-empty-search")}
        </div>
      ) : (
        <motion.div
          layoutScroll
          className="min-h-0 flex-1 overflow-y-auto -mx-2 px-2 -mt-2 pt-2"
          style={{ scrollbarGutter: "stable" }}
        >
          <div className="grid grid-cols-1 gap-3 pb-4 min-[860px]:grid-cols-2">
            {filtered.map((instance) => (
              <InstanceCard
                key={instance.versionGuid}
                instance={instance}
                isLaunching={launchingId === instance.versionGuid}
                hasUpdate={updateAvailableFor(instance)}
                onLaunch={() => void handleLaunch(instance)}
                onOpen={() => openInstance(instance.versionGuid)}
                t={t}
              />
            ))}
          </div>
        </motion.div>
      )}
    </div>
  );
}

interface InstanceCardProps {
  instance: InstanceSummary;
  isLaunching: boolean;
  hasUpdate: boolean;
  onLaunch: () => void;
  onOpen: () => void;
  t: ReturnType<typeof useI18n>["t"];
}

function InstanceCard({
  instance,
  isLaunching,
  hasUpdate,
  onLaunch,
  onOpen,
  t,
}: InstanceCardProps) {
  const isReady = Boolean(instance.executablePath);
  const isDefault = instance.isDefault;

  return (
    <motion.div
      layoutId={`studio-card-${instance.versionGuid}`}
      transition={MORPH_TRANSITION}
      onClick={onOpen}
      className={cn(
        "group relative flex cursor-pointer flex-col gap-4 overflow-hidden rounded-sm border p-4",
        "shadow-(--card-shadow) transition-[transform,border-color,background,box-shadow] duration-200",
        "hover:shadow-[0_10px_28px_rgba(0,0,0,0.28)]",
        isDefault
          ? "border-accent/35 hover:border-accent/55"
          : "border-border bg-card hover:border-[#2e2e2e] hover:bg-card-hover",
      )}
      style={
        isDefault
          ? { backgroundColor: "color-mix(in srgb, var(--color-accent) 5%, transparent)" }
          : undefined
      }
    >
      <div className="flex items-center gap-3">
        <motion.div
          layoutId={`studio-avatar-${instance.versionGuid}`}
          transition={MORPH_TRANSITION}
          className={cn(
            "flex h-10 w-10 shrink-0 items-center justify-center rounded-sm transition-colors duration-200",
            isDefault ? "bg-accent-muted text-accent" : "bg-surface-2 text-text-muted",
          )}
        >
          <Package size={18} />
        </motion.div>

        <div className="min-w-0 flex-1">
          <div className="flex items-center gap-2">
            <motion.span
              layoutId={`studio-title-${instance.versionGuid}`}
              transition={MORPH_TRANSITION}
              className="truncate text-[14px] font-semibold tracking-[-0.01em] text-text"
            >
              {t("versions-studio-label", { version: instance.version })}
            </motion.span>
            {(isDefault || hasUpdate) && (
              <div className="ml-auto flex shrink-0 items-center gap-1.5">
                {isDefault && (
                  <span className="rounded-full bg-accent-muted px-1.5 py-0.5 text-[10px] font-semibold text-accent">
                    {t("versions-badge-default")}
                  </span>
                )}
                {hasUpdate && (
                  <span className="rounded-full bg-yellow-muted px-1.5 py-0.5 text-[10px] font-semibold text-yellow">
                    {t("instances-badge-update")}
                  </span>
                )}
              </div>
            )}
          </div>
          <div className="mt-0.5 flex items-center gap-1.5 text-[11.5px] text-text-muted">
            {!isReady ? (
              <span>{t("instances-not-installed")}</span>
            ) : instance.modloader ? (
              <>
                <span className="truncate">
                  {t(`modloader-channel-${instance.modloader.channel}`)}
                </span>
                <span className="text-text-dim">·</span>
                <span className="whitespace-nowrap tabular-nums">
                  {t("instances-mods-count", {
                    enabled: instance.modsEnabled,
                    total: instance.modsTotal,
                  })}
                </span>
              </>
            ) : (
              <span>{t("instances-no-loader")}</span>
            )}
          </div>
        </div>
      </div>

      <div className="flex items-center gap-2">
        <Button.Root
          variant="primary"
          size="sm"
          className="flex-1 justify-center"
          disabled={isLaunching || !isReady}
          onClick={(event) => {
            event.stopPropagation();
            onLaunch();
          }}
        >
          <Button.Icon>
            {isLaunching ? <RefreshCw size={12} className="animate-spin" /> : <Play size={12} />}
          </Button.Icon>
          <Button.Label>{t("instances-launch")}</Button.Label>
        </Button.Root>
        <Button.Root
          variant="ghost"
          size="sm"
          onClick={(event) => {
            event.stopPropagation();
            onOpen();
          }}
        >
          <Button.Icon>
            <Puzzle size={12} />
          </Button.Icon>
          <Button.Label>{t("instances-configure")}</Button.Label>
        </Button.Root>
      </div>
    </motion.div>
  );
}
