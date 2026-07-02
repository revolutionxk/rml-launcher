import { createFileRoute, useNavigate } from "@tanstack/react-router";
import {
  ChevronRight,
  Package,
  Play,
  Plus,
  Puzzle,
  RefreshCw,
  Search,
  Settings2,
  ShieldCheck,
  Star,
} from "lucide-react";
import { motion } from "motion/react";
import { useDeferredValue, useState } from "react";

import { PlatformNotice } from "@/components/platform-notice";
import { VinegarStudio } from "@/components/instance/vinegar-studio";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { useI18n } from "@/i18n";
import { getErrorMessage } from "@/lib/format";
import type { InstanceSummary } from "@/lib/instances";
import { type ModLoaderChannel } from "@/lib/modloader";
import { useHostInfo, useInstances, useModLoaderReleases } from "@/lib/queries";
import { launchStudio } from "@/lib/studio";

export const Route = createFileRoute("/settings/instances/")({
  component: InstancesPage,
});

const CHANNEL_VARIANTS: Record<ModLoaderChannel, "blue" | "green" | "yellow" | "purple" | "gray"> =
  {
    stable: "green",
    beta: "yellow",
    nightly: "purple",
    experimental: "blue",
    prerelease: "gray",
  };

const CHANNEL_ICON_BOX: Record<ModLoaderChannel, string> = {
  stable: "icon-box--green",
  beta: "icon-box--orange",
  nightly: "icon-box--purple",
  experimental: "icon-box--blue",
  prerelease: "icon-box--gray",
};

function matchesQuery(instance: InstanceSummary, query: string) {
  return [instance.version, instance.versionGuid, instance.modloader?.name ?? "", instance.modloader?.channel ?? ""]
    .join(" ")
    .toLowerCase()
    .includes(query);
}

function InstancesPage() {
  const { formatDate, t } = useI18n();
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
        t("instances-error-launch", { message: getErrorMessage(error, t("instances-error-generic")) }),
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
        <div className="flex flex-wrap items-start justify-between gap-3">
          <div className="min-w-0">
            <div className="flex items-center gap-2">
              <h1 className="text-[18px] font-semibold leading-tight tracking-[-0.018em] text-text">
                {t("instances-title")}
              </h1>
              {instances.length > 0 && (
                <span className="rounded-full bg-surface-2 px-2 py-0.5 text-[10.5px] font-medium text-text-muted tabular-nums">
                  {t("instances-count", { count: instances.length })}
                </span>
              )}
            </div>
            <p className="mt-1 text-[12.5px] leading-normal text-text-muted">
              {t("instances-description")}
            </p>
          </div>

          <div className="flex shrink-0 items-center gap-2">
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
          </div>
        </div>

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
        <div className="rounded-sm border border-border bg-card px-4 py-4 text-[12.5px] text-text-muted">
          {t("instances-loading")}
        </div>
      ) : instances.length === 0 ? (
        <EmptyState onAdd={() => navigate({ to: "/settings/versions" })} t={t} />
      ) : filtered.length === 0 ? (
        <div className="rounded-sm border border-border bg-card px-4 py-4 text-[12.5px] text-text-muted">
          {t("instances-empty-search")}
        </div>
      ) : (
        <div
          className="min-h-0 flex-1 overflow-y-auto -mx-2 px-2 -mt-2 pt-2"
          style={{ scrollbarGutter: "stable" }}
        >
          <div className="grid grid-cols-1 gap-3 pb-4 min-[860px]:grid-cols-2">
            {filtered.map((instance, index) => (
              <InstanceCard
                key={instance.versionGuid}
                instance={instance}
                index={index}
                isLaunching={launchingId === instance.versionGuid}
                hasUpdate={updateAvailableFor(instance)}
                onLaunch={() => void handleLaunch(instance)}
                onOpen={() => openInstance(instance.versionGuid)}
                formatDate={formatDate}
                t={t}
              />
            ))}
          </div>
        </div>
      )}
    </div>
  );
}

interface InstanceCardProps {
  instance: InstanceSummary;
  index: number;
  isLaunching: boolean;
  hasUpdate: boolean;
  onLaunch: () => void;
  onOpen: () => void;
  formatDate: ReturnType<typeof useI18n>["formatDate"];
  t: ReturnType<typeof useI18n>["t"];
}

function InstanceCard({
  instance,
  index,
  isLaunching,
  hasUpdate,
  onLaunch,
  onOpen,
  formatDate,
  t,
}: InstanceCardProps) {
  const isReady = Boolean(instance.executablePath);
  const avatarClass = instance.modloader
    ? CHANNEL_ICON_BOX[instance.modloader.channel]
    : "icon-box--blue";

  return (
    <motion.div
      layout="position"
      initial={{ opacity: 0, y: 8 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ duration: 0.2, delay: Math.min(index * 0.03, 0.18) }}
      onClick={onOpen}
      className="group relative flex cursor-pointer flex-col gap-3.5 overflow-hidden rounded-sm border border-border bg-card p-4 shadow-(--card-shadow) transition-[transform,border-color,background,box-shadow] duration-200 hover:-translate-y-0.5 hover:border-[#2e2e2e] hover:bg-card-hover hover:shadow-[0_10px_28px_rgba(0,0,0,0.28)]"
      style={
        instance.isDefault
          ? {
              borderColor: "color-mix(in srgb, var(--color-accent) 32%, transparent)",
              backgroundColor: "color-mix(in srgb, var(--color-accent) 5%, transparent)",
            }
          : undefined
      }
    >
      <div className="flex items-center gap-3">
        <div
          className={`relative flex h-11 w-11 shrink-0 items-center justify-center rounded-sm ${avatarClass}`}
        >
          <Package size={19} />
          <span
            className={`absolute -bottom-0.5 -right-0.5 h-3 w-3 rounded-full border-2 border-(--color-card) ${
              isReady ? "bg-green shadow-[0_0_6px_rgba(61,204,122,0.4)]" : "bg-text-dim"
            }`}
          />
        </div>

        <div className="min-w-0 flex-1">
          <div className="flex flex-wrap items-center gap-1.5">
            <span className="truncate text-[14px] font-semibold tracking-[-0.01em] text-text">
              {t("versions-studio-label", { version: instance.version })}
            </span>
            {instance.isDefault && (
              <Badge.Root variant="yellow">
                <Badge.Icon>
                  <Star size={9} />
                </Badge.Icon>
                <Badge.Label>{t("versions-badge-default")}</Badge.Label>
              </Badge.Root>
            )}
          </div>
          <div className="mt-0.5 truncate text-[11px] text-text-muted">
            {isReady ? t("instances-ready") : t("instances-not-installed")}
            {instance.installedAt ? ` · ${t("instances-installed-at", { date: formatDate(instance.installedAt) })}` : ""}
          </div>
        </div>

        <ChevronRight
          size={16}
          className="shrink-0 text-text-dim transition-transform duration-200 group-hover:translate-x-0.5 group-hover:text-text-muted"
        />
      </div>

      <div className="flex flex-wrap items-center gap-1.5">
        {instance.modloader ? (
          <Badge.Root variant={CHANNEL_VARIANTS[instance.modloader.channel]}>
            <Badge.Icon>
              <ShieldCheck size={9} />
            </Badge.Icon>
            <Badge.Label>{instance.modloader.name}</Badge.Label>
          </Badge.Root>
        ) : (
          <Badge.Root variant="gray">
            <Badge.Label>{t("instances-no-loader")}</Badge.Label>
          </Badge.Root>
        )}
        <Badge.Root variant="gray">
          <Badge.Icon>
            <Puzzle size={9} />
          </Badge.Icon>
          <Badge.Label>
            {t("instances-mods-count", { enabled: instance.modsEnabled, total: instance.modsTotal })}
          </Badge.Label>
        </Badge.Root>
        {hasUpdate && (
          <Badge.Root variant="yellow">
            <Badge.Label>{t("modloader-badge-update")}</Badge.Label>
          </Badge.Root>
        )}
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
            <Settings2 size={12} />
          </Button.Icon>
          <Button.Label>{t("instances-configure")}</Button.Label>
        </Button.Root>
      </div>
    </motion.div>
  );
}

function EmptyState({ onAdd, t }: { onAdd: () => void; t: ReturnType<typeof useI18n>["t"] }) {
  return (
    <div className="flex min-h-0 flex-1 items-center justify-center">
      <motion.div
        initial={{ opacity: 0, y: 8 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ duration: 0.25 }}
        className="flex w-full max-w-sm flex-col items-center gap-3 rounded-sm border border-border bg-card px-6 py-12 text-center shadow-(--card-shadow)"
      >
        <div className="flex h-14 w-14 items-center justify-center rounded-sm icon-box--blue">
          <Package size={26} />
        </div>
        <div className="text-[14px] font-semibold text-text">{t("instances-empty-title")}</div>
        <div className="max-w-64 text-[12px] leading-relaxed text-text-muted">
          {t("instances-empty-description")}
        </div>
        <Button.Root variant="primary" className="mt-1" onClick={onAdd}>
          <Button.Icon>
            <Plus size={13} />
          </Button.Icon>
          <Button.Label>{t("instances-add")}</Button.Label>
        </Button.Root>
      </motion.div>
    </div>
  );
}
