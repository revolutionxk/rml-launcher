import { useQueryClient } from "@tanstack/react-query";
import { open } from "@tauri-apps/plugin-dialog";
import { FolderOpen, FolderPlus, Package, Puzzle, RefreshCw, Trash2 } from "lucide-react";
import { AnimatePresence, motion } from "motion/react";
import { useState } from "react";

import Toggle from "@/components/toggle";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Callout } from "@/components/ui/callout";
import { Card } from "@/components/ui/card";
import { EmptyState } from "@/components/ui/empty-state";
import { Spinner } from "@/components/ui/spinner";
import { Tooltip } from "@/components/ui/tooltip";
import { useI18n } from "@/i18n";
import { formatBytes, getErrorMessage } from "@/lib/format";
import { importMod, type ModKind, openModsDir, removeMod, setModEnabled } from "@/lib/mods";
import { queryKeys, useMods } from "@/lib/queries";
import { cn } from "@/lib/utils";

const KIND_VARIANTS: Record<ModKind, "blue" | "green" | "yellow" | "gray"> = {
  native: "blue",
  dotnet: "green",
  scripts: "yellow",
  other: "gray",
};

interface ModsPanelProps {
  installationId: string;
}

export function ModsPanel({ installationId }: ModsPanelProps) {
  const { t } = useI18n();
  const queryClient = useQueryClient();
  const { data, isLoading } = useMods(installationId);

  const [busyModId, setBusyModId] = useState<string | null>(null);
  const [isImporting, setIsImporting] = useState(false);
  const [errorMessage, setErrorMessage] = useState<string | null>(null);

  const loaderInstalled = data?.loaderInstalled ?? false;
  const mods = data?.mods ?? [];

  const refresh = async () => {
    await Promise.all([
      queryClient.invalidateQueries({ queryKey: queryKeys.mods(installationId) }),
      queryClient.invalidateQueries({ queryKey: queryKeys.instances }),
    ]);
  };

  const handleImport = async (directory: boolean) => {
    setErrorMessage(null);
    try {
      const selection = await open({
        multiple: false,
        directory,
        filters: directory ? undefined : [{ name: t("mods-filter-zip"), extensions: ["zip"] }],
      });

      if (typeof selection !== "string") {
        return;
      }

      setIsImporting(true);
      await importMod(installationId, selection);
      await refresh();
    } catch (error) {
      setErrorMessage(t("mods-error-import", { message: getErrorMessage(error, t("mods-error-generic")) }));
    } finally {
      setIsImporting(false);
    }
  };

  const handleToggle = async (modId: string, enabled: boolean) => {
    setBusyModId(modId);
    setErrorMessage(null);
    try {
      await setModEnabled(installationId, modId, enabled);
      await refresh();
    } catch (error) {
      setErrorMessage(getErrorMessage(error, t("mods-error-generic")));
    } finally {
      setBusyModId(null);
    }
  };

  const handleRemove = async (modId: string) => {
    setBusyModId(modId);
    setErrorMessage(null);
    try {
      await removeMod(installationId, modId);
      await refresh();
    } catch (error) {
      setErrorMessage(t("mods-error-remove", { message: getErrorMessage(error, t("mods-error-generic")) }));
    } finally {
      setBusyModId(null);
    }
  };

  return (
    <Tooltip.Provider>
      <Card.Root>
        <Card.Header>
          <div className="flex items-center justify-between gap-2">
            <Card.Label>{t("mods-title")}</Card.Label>
            {mods.length > 0 && (
              <span className="text-[11px] text-text-dim tabular-nums">
                {t("mods-count", { enabled: mods.filter((mod) => mod.enabled).length, total: mods.length })}
              </span>
            )}
          </div>
          <Card.Description>{t("mods-description")}</Card.Description>
        </Card.Header>

        <Card.Body className="flex flex-col gap-3">
          {errorMessage && <Callout variant="danger">{errorMessage}</Callout>}

          {!loaderInstalled && (
            <Callout variant="warning">{t("mods-loader-required")}</Callout>
          )}

          <div className="flex flex-wrap items-center gap-2">
            <Button.Root
              variant="primary"
              size="sm"
              disabled={!loaderInstalled || isImporting}
              onClick={() => void handleImport(false)}
            >
              <Button.Icon>
                {isImporting ? <RefreshCw size={13} className="animate-spin" /> : <Package size={13} />}
              </Button.Icon>
              <Button.Label>{t("mods-add-zip")}</Button.Label>
            </Button.Root>
            <Button.Root
              variant="ghost"
              size="sm"
              disabled={!loaderInstalled || isImporting}
              onClick={() => void handleImport(true)}
            >
              <Button.Icon>
                <FolderPlus size={13} />
              </Button.Icon>
              <Button.Label>{t("mods-add-folder")}</Button.Label>
            </Button.Root>
            <Button.Root
              variant="ghost"
              size="sm"
              className="ml-auto"
              disabled={!loaderInstalled}
              onClick={() => openModsDir(installationId).catch(console.error)}
            >
              <Button.Icon>
                <FolderOpen size={13} />
              </Button.Icon>
              <Button.Label>{t("mods-open-folder")}</Button.Label>
            </Button.Root>
          </div>

          {isLoading ? (
            <div className="flex items-center gap-2 text-[12px] text-text-muted">
              <Spinner size={12} />
              {t("mods-loading")}
            </div>
          ) : mods.length === 0 ? (
            <EmptyState
              compact
              iconClass="icon-box--purple"
              icon={<Puzzle size={20} />}
              title={t("mods-empty-title")}
              description={t("mods-empty-description")}
            />
          ) : (
            <div className="overflow-hidden rounded-sm border border-border">
              <div className="flex items-center gap-3 border-b border-border-subtle bg-surface/40 px-3.5 py-2 text-[10px] font-semibold uppercase tracking-[0.06em] text-text-dim">
                <span className="w-7 shrink-0" />
                <span className="min-w-0 flex-1">{t("mods-col-name")}</span>
                <span className="w-28 shrink-0">{t("mods-col-type")}</span>
                <span className="w-16 shrink-0 text-right">{t("mods-col-size")}</span>
                <span className="w-19 shrink-0" />
              </div>
              <AnimatePresence initial={false}>
                {mods.map((mod) => (
                  <motion.div
                    key={mod.id}
                    initial={{ opacity: 0 }}
                    animate={{ opacity: 1 }}
                    exit={{ opacity: 0, height: 0, overflow: "hidden" }}
                    transition={{ duration: 0.16 }}
                    layout="position"
                    className="flex items-center gap-3 border-t border-border-subtle bg-card px-3.5 py-2 transition-colors duration-120 hover:bg-card-hover"
                  >
                    <div
                      className={cn(
                        "flex h-7 w-7 shrink-0 items-center justify-center rounded-sm icon-box--purple transition-opacity",
                        !mod.enabled && "opacity-45",
                      )}
                    >
                      <Puzzle size={13} />
                    </div>

                    <span
                      className={cn(
                        "min-w-0 flex-1 truncate text-[12.5px] font-medium",
                        mod.enabled ? "text-text" : "text-text-muted",
                      )}
                    >
                      {mod.name}
                    </span>

                    <div className="flex w-28 shrink-0 flex-wrap gap-1">
                      {mod.kinds.map((kind) => (
                        <Badge.Root key={kind} variant={KIND_VARIANTS[kind]}>
                          <Badge.Label>{t(`mods-kind-${kind}`)}</Badge.Label>
                        </Badge.Root>
                      ))}
                    </div>

                    <span className="w-16 shrink-0 text-right text-[11px] text-text-muted tabular-nums">
                      {formatBytes(mod.sizeBytes)}
                    </span>

                    <div className="flex w-19 shrink-0 items-center justify-end gap-2">
                      <Toggle
                        checked={mod.enabled}
                        disabled={busyModId === mod.id}
                        onChange={() => void handleToggle(mod.id, !mod.enabled)}
                        label={t("mods-toggle", { name: mod.name })}
                      />
                      <Tooltip.Root>
                        <Tooltip.Trigger
                          render={
                            <Button.Root
                              variant="danger"
                              size="icon-sm"
                              aria-label={t("mods-remove")}
                              disabled={busyModId === mod.id}
                              onClick={() => void handleRemove(mod.id)}
                            >
                              <Button.Icon>
                                <Trash2 size={13} />
                              </Button.Icon>
                            </Button.Root>
                          }
                        />
                        <Tooltip.Portal>
                          <Tooltip.Positioner>
                            <Tooltip.Popup>{t("mods-remove")}</Tooltip.Popup>
                          </Tooltip.Positioner>
                        </Tooltip.Portal>
                      </Tooltip.Root>
                    </div>
                  </motion.div>
                ))}
              </AnimatePresence>
            </div>
          )}
        </Card.Body>
      </Card.Root>
    </Tooltip.Provider>
  );
}
