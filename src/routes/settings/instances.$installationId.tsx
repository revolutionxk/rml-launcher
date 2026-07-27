import { useQueryClient } from "@tanstack/react-query";
import { createFileRoute, useNavigate, useParams } from "@tanstack/react-router";
import { confirm } from "@tauri-apps/plugin-dialog";
import {
  ArrowLeft,
  Cpu,
  FolderOpen,
  MoreHorizontal,
  Package,
  Play,
  Puzzle,
  Star,
  Trash2,
} from "lucide-react";
import { motion } from "motion/react";
import { useState } from "react";

import { ModLoaderPanel } from "@/components/instance/mod-loader-panel";
import { ModsPanel } from "@/components/instance/mods-panel";
import { Button } from "@/components/ui/button";
import { Callout } from "@/components/ui/callout";
import { Menu } from "@/components/ui/menu";
import { LoadingState, Spinner } from "@/components/ui/spinner";
import { Tabs } from "@/components/ui/tabs";
import { useI18n } from "@/i18n";
import { getErrorMessage } from "@/lib/format";
import { queryKeys, useInstances } from "@/lib/queries";
import {
  can,
  Capability,
  launchStudio,
  openStudioInstallDir,
  setDefaultStudioVersion,
  uninstallStudio,
} from "@/lib/studio";
import { cn } from "@/lib/utils";
import { EngineFlags } from "@/routes/settings/engine";

export const Route = createFileRoute("/settings/instances/$installationId")({
  component: InstanceDetailPage,
});

type InstanceTab = "mods" | "flags";

const MORPH_TRANSITION = {
  duration: 0.42,
  ease: [0.32, 0.72, 0, 1] as [number, number, number, number],
};

function BackLink({ label, onClick }: { label: string; onClick: () => void }) {
  return (
    <button
      className="flex w-fit shrink-0 items-center gap-1.5 rounded-sm text-[12.5px] text-text-muted outline-none transition-colors hover:text-text focus-visible:ring-2 focus-visible:ring-accent/40"
      onClick={onClick}
    >
      <ArrowLeft size={13} />
      {label}
    </button>
  );
}

function InstanceDetailPage() {
  const { formatDate, t } = useI18n();
  const navigate = useNavigate();
  const queryClient = useQueryClient();
  const { installationId } = useParams({ from: "/settings/instances/$installationId" });
  const { data: instances = [], isLoading } = useInstances();

  const instance = instances.find((candidate) => candidate.id === installationId) ?? null;

  const [tab, setTab] = useState<InstanceTab>("mods");
  const [launching, setLaunching] = useState(false);
  const [defaulting, setDefaulting] = useState(false);
  const [deleting, setDeleting] = useState(false);
  const [errorMessage, setErrorMessage] = useState<string | null>(null);

  const goBack = () => navigate({ to: "/settings/instances" });

  const handleLaunch = async () => {
    setLaunching(true);
    setErrorMessage(null);
    try {
      await launchStudio(installationId);
    } catch (error) {
      setErrorMessage(
        t("instances-error-launch", {
          message: getErrorMessage(error, t("instances-error-generic")),
        }),
      );
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
      await setDefaultStudioVersion(instance.isDefault ? null : installationId);
      await queryClient.invalidateQueries({ queryKey: queryKeys.instances });
    } catch (error) {
      setErrorMessage(getErrorMessage(error, t("instances-error-generic")));
    } finally {
      setDefaulting(false);
    }
  };

  const handleDelete = async () => {
    const confirmed = await confirm(
      t("instances-delete-confirm", { version: instance?.version ?? "" }),
      { title: t("instances-delete"), kind: "warning" },
    );
    if (!confirmed) {
      return;
    }

    setDeleting(true);
    setErrorMessage(null);
    try {
      await uninstallStudio(installationId);
      await queryClient.invalidateQueries({ queryKey: queryKeys.instances });
      goBack();
    } catch (error) {
      setErrorMessage(
        t("instances-error-delete", {
          message: getErrorMessage(error, t("instances-error-generic")),
        }),
      );
      setDeleting(false);
    }
  };

  if (isLoading) {
    return <LoadingState label={t("instances-loading")} />;
  }

  if (!instance) {
    return (
      <div className="flex flex-col items-start gap-3">
        <BackLink label={t("instances-back")} onClick={goBack} />
        <Callout variant="warning" className="w-full">
          {t("instances-not-found")}
        </Callout>
      </div>
    );
  }

  const isReady = Boolean(instance.executablePath);
  const isBusy = launching || defaulting || deleting;

  return (
    <div className="flex h-full min-h-0 flex-col gap-3 lg:gap-4">
      <BackLink label={t("instances-back")} onClick={goBack} />
      <motion.div
        layoutId={`studio-card-${installationId}`}
        transition={MORPH_TRANSITION}
        className={cn(
          "shrink-0 overflow-hidden rounded-lg border p-3.5 shadow-(--card-shadow) lg:p-4",
          instance.isDefault ? "border-accent/35" : "border-border bg-card",
        )}
        style={
          instance.isDefault
            ? { backgroundColor: "color-mix(in srgb, var(--color-accent) 5%, transparent)" }
            : undefined
        }
      >
        <div className="flex flex-wrap items-center gap-3">
          <motion.div
            layoutId={`studio-avatar-${installationId}`}
            transition={MORPH_TRANSITION}
            className={cn(
              "flex h-10 w-10 shrink-0 items-center justify-center rounded-sm",
              instance.isDefault ? "bg-accent-muted text-accent" : "bg-surface-2 text-text-muted",
            )}
          >
            <Package size={18} />
          </motion.div>

          <div className="min-w-0 flex-1">
            <div className="flex flex-wrap items-center gap-1.5">
              <motion.h1
                layoutId={`studio-title-${installationId}`}
                transition={MORPH_TRANSITION}
                className="text-[16px] font-semibold tracking-[-0.015em] text-text"
              >
                {t("versions-studio-label", { version: instance.version })}
              </motion.h1>
              {instance.isDefault && (
                <motion.span
                  initial={{ opacity: 0 }}
                  animate={{ opacity: 1 }}
                  transition={{ duration: 0.25, delay: 0.1, ease: "easeOut" }}
                  className="rounded-full bg-accent-muted px-1.5 py-0.5 text-[10px] font-semibold text-accent"
                >
                  {t("versions-badge-default")}
                </motion.span>
              )}
            </div>
            <motion.div
              initial={{ opacity: 0 }}
              animate={{ opacity: 1 }}
              transition={{ duration: 0.25, delay: 0.1, ease: "easeOut" }}
              className="mt-0.5 truncate text-[11px] text-text-muted"
            >
              {isReady ? t("instances-ready") : t("instances-not-installed")}
              {instance.installedAt
                ? ` · ${t("instances-installed-at", { date: formatDate(instance.installedAt) })}`
                : ""}
            </motion.div>
          </div>

          <motion.div
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            transition={{ duration: 0.25, delay: 0.06, ease: "easeOut" }}
            className="flex shrink-0 items-center gap-2"
          >
            <Button.Root
              variant="primary"
              disabled={isBusy || !isReady}
              onClick={() => void handleLaunch()}
            >
              <Button.Icon>{launching ? <Spinner size={13} /> : <Play size={13} />}</Button.Icon>
              <Button.Label>{t("instances-launch")}</Button.Label>
            </Button.Root>

            <Menu.Root>
              <Menu.Trigger
                render={
                  <Button.Root
                    variant="ghost"
                    size="icon"
                    aria-label={t("versions-actions")}
                    disabled={isBusy}
                  >
                    <Button.Icon>
                      <MoreHorizontal size={15} />
                    </Button.Icon>
                  </Button.Root>
                }
              />
              <Menu.Portal>
                <Menu.Positioner>
                  <Menu.Popup>
                    <Menu.Item disabled={isBusy} onClick={() => void handleToggleDefault()}>
                      <span
                        className={`flex h-[14px] w-[14px] items-center justify-center ${
                          instance.isDefault ? "text-yellow" : "text-text-dim"
                        }`}
                      >
                        <Star size={13} />
                      </span>
                      <span>
                        {instance.isDefault
                          ? t("versions-clear-default")
                          : t("versions-set-default")}
                      </span>
                    </Menu.Item>
                    <Menu.Item
                      onClick={() => openStudioInstallDir(installationId).catch(console.error)}
                    >
                      <span className="flex h-[14px] w-[14px] items-center justify-center text-text-dim">
                        <FolderOpen size={13} />
                      </span>
                      <span>{t("versions-open-folder")}</span>
                    </Menu.Item>
                    {can(instance, Capability.Uninstall) && (
                      <Menu.Item
                        disabled={isBusy}
                        className="text-red data-[highlighted]:text-red"
                        onClick={() => void handleDelete()}
                      >
                        <span className="flex h-[14px] w-[14px] items-center justify-center text-red/85">
                          <Trash2 size={13} />
                        </span>
                        <span>{t("instances-delete")}</span>
                      </Menu.Item>
                    )}
                  </Menu.Popup>
                </Menu.Positioner>
              </Menu.Portal>
            </Menu.Root>
          </motion.div>
        </div>
      </motion.div>

      {errorMessage && (
        <Callout variant="danger" className="shrink-0">
          {errorMessage}
        </Callout>
      )}

      <Tabs<InstanceTab>
        className="shrink-0"
        value={tab}
        onValueChange={setTab}
        tabs={[
          { value: "mods", label: t("instances-tab-mods"), icon: <Puzzle /> },
          { value: "flags", label: t("instances-tab-flags"), icon: <Cpu /> },
        ]}
      />

      <div className="min-h-0 flex-1">
        {tab === "mods" ? (
          <div className="h-full overflow-y-auto" style={{ scrollbarGutter: "stable" }}>
            <div className="flex flex-col gap-4 pb-1">
              <ModLoaderPanel installationId={installationId} installed={instance.modloader} />
              <ModsPanel installationId={installationId} />
            </div>
          </div>
        ) : (
          <EngineFlags embeddedTargetInstallationId={installationId} />
        )}
      </div>
    </div>
  );
}
