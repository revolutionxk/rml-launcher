import { useQueryClient } from "@tanstack/react-query";
import { createFileRoute, useNavigate, useParams } from "@tanstack/react-router";
import { confirm } from "@tauri-apps/plugin-dialog";
import { ArrowLeft, Cpu, FolderOpen, Play, RefreshCw, Star, Trash2 } from "lucide-react";
import { useState } from "react";

import { ModLoaderPanel } from "@/components/instance/mod-loader-panel";
import { ModsPanel } from "@/components/instance/mods-panel";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { useI18n } from "@/i18n";
import { getErrorMessage } from "@/lib/format";
import { queryKeys, useInstances } from "@/lib/queries";
import {
  launchStudio,
  openStudioInstallDir,
  setDefaultStudioVersion,
  uninstallStudio,
} from "@/lib/studio";

export const Route = createFileRoute("/settings/instances/$versionGuid")({
  component: InstanceDetailPage,
});

function InstanceDetailPage() {
  const { formatDate, t } = useI18n();
  const navigate = useNavigate();
  const queryClient = useQueryClient();
  const { versionGuid } = useParams({ from: "/settings/instances/$versionGuid" });
  const { data: instances = [], isLoading } = useInstances();

  const instance = instances.find((candidate) => candidate.versionGuid === versionGuid) ?? null;

  const [launching, setLaunching] = useState(false);
  const [defaulting, setDefaulting] = useState(false);
  const [deleting, setDeleting] = useState(false);
  const [errorMessage, setErrorMessage] = useState<string | null>(null);

  const goBack = () => navigate({ to: "/settings/instances" });

  const handleLaunch = async () => {
    setLaunching(true);
    setErrorMessage(null);
    try {
      await launchStudio(versionGuid);
    } catch (error) {
      setErrorMessage(t("instances-error-launch", { message: getErrorMessage(error, t("instances-error-generic")) }));
    } finally {
      setLaunching(false);
    }
  };

  const handleToggleDefault = async () => {
    if (!instance) {
      return;
    }
    setDefaulting(true);
    setErrorMessage(null);
    try {
      await setDefaultStudioVersion(instance.isDefault ? null : versionGuid);
      await queryClient.invalidateQueries({ queryKey: queryKeys.instances });
    } catch (error) {
      setErrorMessage(getErrorMessage(error, t("instances-error-generic")));
    } finally {
      setDefaulting(false);
    }
  };

  const handleDelete = async () => {
    const confirmed = await confirm(t("instances-delete-confirm", { version: instance?.version ?? "" }), {
      title: t("instances-delete"),
      kind: "warning",
    });
    if (!confirmed) {
      return;
    }

    setDeleting(true);
    setErrorMessage(null);
    try {
      await uninstallStudio(versionGuid);
      await queryClient.invalidateQueries({ queryKey: queryKeys.instances });
      goBack();
    } catch (error) {
      setErrorMessage(t("instances-error-delete", { message: getErrorMessage(error, t("instances-error-generic")) }));
      setDeleting(false);
    }
  };

  if (isLoading) {
    return (
      <div className="rounded-sm border border-border bg-card px-4 py-4 text-[12.5px] text-text-muted">
        {t("instances-loading")}
      </div>
    );
  }

  if (!instance) {
    return (
      <div className="flex flex-col items-start gap-3">
        <button
          className="flex items-center gap-1.5 text-[12.5px] text-text-muted transition-colors hover:text-text"
          onClick={goBack}
        >
          <ArrowLeft size={13} />
          {t("instances-back")}
        </button>
        <div className="rounded-sm border border-border bg-card px-4 py-4 text-[12.5px] text-text-muted">
          {t("instances-not-found")}
        </div>
      </div>
    );
  }

  const isBusy = launching || defaulting || deleting;

  return (
    <div className="flex flex-col gap-4">
      <button
        className="flex w-fit items-center gap-1.5 text-[12.5px] text-text-muted transition-colors hover:text-text"
        onClick={goBack}
      >
        <ArrowLeft size={13} />
        {t("instances-back")}
      </button>

      <div className="rounded-sm border border-border bg-card p-4">
        <div className="flex flex-wrap items-start justify-between gap-3">
          <div className="min-w-0">
            <div className="flex flex-wrap items-center gap-1.5">
              <h1 className="text-[16px] font-semibold tracking-[-0.018em] text-text">
                {t("versions-studio-label", { version: instance.version })}
              </h1>
              {instance.isDefault && (
                <Badge.Root variant="yellow">
                  <Badge.Icon>
                    <Star size={9} />
                  </Badge.Icon>
                  <Badge.Label>{t("versions-badge-default")}</Badge.Label>
                </Badge.Root>
              )}
            </div>
            <div className="mt-1 truncate text-[11px] text-text-dim">
              {instance.installedAt
                ? t("instances-installed-at", { date: formatDate(instance.installedAt) })
                : instance.versionGuid}
            </div>
          </div>

          <div className="flex flex-wrap items-center gap-2">
            <Button.Root
              variant="primary"
              disabled={isBusy || !instance.executablePath}
              onClick={() => void handleLaunch()}
            >
              <Button.Icon>
                {launching ? <RefreshCw size={13} className="animate-spin" /> : <Play size={13} />}
              </Button.Icon>
              <Button.Label>{t("instances-launch")}</Button.Label>
            </Button.Root>
            <Button.Root variant="ghost" disabled={isBusy} onClick={() => void handleToggleDefault()}>
              <Button.Icon>
                <Star size={13} className={instance.isDefault ? "text-yellow" : undefined} />
              </Button.Icon>
              <Button.Label>
                {instance.isDefault ? t("versions-clear-default") : t("versions-set-default")}
              </Button.Label>
            </Button.Root>
            <Button.Root
              variant="ghost"
              onClick={() => openStudioInstallDir(versionGuid).catch(console.error)}
            >
              <Button.Icon>
                <FolderOpen size={13} />
              </Button.Icon>
              <Button.Label>{t("versions-open-folder")}</Button.Label>
            </Button.Root>
            <Button.Root variant="ghost" onClick={() => navigate({ to: "/settings/engine" })}>
              <Button.Icon>
                <Cpu size={13} />
              </Button.Icon>
              <Button.Label>{t("instances-engine-flags")}</Button.Label>
            </Button.Root>
            <Button.Root variant="danger" disabled={isBusy} onClick={() => void handleDelete()}>
              <Button.Icon>
                {deleting ? <RefreshCw size={13} className="animate-spin" /> : <Trash2 size={13} />}
              </Button.Icon>
              <Button.Label>{t("instances-delete")}</Button.Label>
            </Button.Root>
          </div>
        </div>
      </div>

      {errorMessage && (
        <div className="rounded-sm border border-red/25 bg-red-muted px-4 py-3 text-[12px] text-text">
          {errorMessage}
        </div>
      )}

      <ModLoaderPanel versionGuid={versionGuid} installed={instance.modloader} />
      <ModsPanel versionGuid={versionGuid} />
    </div>
  );
}
