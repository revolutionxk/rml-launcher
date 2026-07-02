import { useQueryClient } from "@tanstack/react-query";
import { open } from "@tauri-apps/plugin-dialog";
import { FolderOpen, FolderPlus, Package, Puzzle, RefreshCw, Trash2 } from "lucide-react";
import { AnimatePresence, motion } from "motion/react";
import { useState } from "react";

import Toggle from "@/components/toggle";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Card } from "@/components/ui/card";
import { Tooltip } from "@/components/ui/tooltip";
import { useI18n } from "@/i18n";
import { formatBytes, getErrorMessage } from "@/lib/format";
import { importMod, type ModKind, openModsDir, removeMod, setModEnabled } from "@/lib/mods";
import { queryKeys, useMods } from "@/lib/queries";

const KIND_VARIANTS: Record<ModKind, "blue" | "green" | "yellow" | "gray"> = {
  native: "blue",
  dotnet: "green",
  scripts: "yellow",
  other: "gray",
};

interface ModsPanelProps {
  versionGuid: string;
}

export function ModsPanel({ versionGuid }: ModsPanelProps) {
  const { t } = useI18n();
  const queryClient = useQueryClient();
  const { data, isLoading } = useMods(versionGuid);

  const [busyModId, setBusyModId] = useState<string | null>(null);
  const [isImporting, setIsImporting] = useState(false);
  const [errorMessage, setErrorMessage] = useState<string | null>(null);

  const loaderInstalled = data?.loaderInstalled ?? false;
  const mods = data?.mods ?? [];

  const refresh = async () => {
    await Promise.all([
      queryClient.invalidateQueries({ queryKey: queryKeys.mods(versionGuid) }),
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
      await importMod(versionGuid, selection);
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
      await setModEnabled(versionGuid, modId, enabled);
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
      await removeMod(versionGuid, modId);
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
          {errorMessage && (
            <div className="rounded-sm border border-red/25 bg-red-muted px-3 py-2 text-[11.5px] text-text">
              {errorMessage}
            </div>
          )}

          {!loaderInstalled && (
            <div className="rounded-sm border border-yellow/25 bg-yellow-muted px-3 py-2 text-[11.5px] text-text">
              {t("mods-loader-required")}
            </div>
          )}

          <div className="flex flex-wrap gap-2">
            <Button.Root
              variant="primary"
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
              disabled={!loaderInstalled}
              onClick={() => openModsDir(versionGuid).catch(console.error)}
            >
              <Button.Icon>
                <FolderOpen size={13} />
              </Button.Icon>
              <Button.Label>{t("mods-open-folder")}</Button.Label>
            </Button.Root>
          </div>

          {isLoading ? (
            <div className="text-[12px] text-text-muted">{t("mods-loading")}</div>
          ) : mods.length === 0 ? (
            <div className="flex flex-col items-center justify-center gap-2.5 rounded-sm border border-border bg-card px-5 py-10 text-center">
              <Puzzle size={30} className="text-text-dim opacity-50" />
              <div className="text-[13px] font-medium text-text-muted">{t("mods-empty-title")}</div>
              <div className="max-w-60 text-[12px] leading-relaxed text-text-dim">
                {t("mods-empty-description")}
              </div>
            </div>
          ) : (
            <div className="overflow-hidden rounded-sm border border-border">
              <AnimatePresence initial={false}>
                {mods.map((mod, index) => (
                  <motion.div
                    key={mod.id}
                    initial={{ opacity: 0 }}
                    animate={{ opacity: 1 }}
                    exit={{ opacity: 0, height: 0, overflow: "hidden" }}
                    transition={{ duration: 0.16 }}
                    layout="position"
                    className={
                      "flex items-center gap-3 bg-card px-4 py-3 transition-colors duration-120 hover:bg-card-hover" +
                      (index > 0 ? " border-t border-border-subtle" : "")
                    }
                  >
                    <div className="flex h-8 w-8 shrink-0 items-center justify-center rounded-sm icon-box--purple">
                      <Puzzle size={14} />
                    </div>

                    <div className="min-w-0 flex-1">
                      <div className="mb-0.5 flex min-w-0 items-center gap-1.5">
                        <span
                          className={
                            "truncate text-[13px] font-medium" +
                            (mod.enabled ? " text-text" : " text-text-muted")
                          }
                        >
                          {mod.name}
                        </span>
                        {mod.kinds.map((kind) => (
                          <Badge.Root key={kind} variant={KIND_VARIANTS[kind]}>
                            <Badge.Label>{t(`mods-kind-${kind}`)}</Badge.Label>
                          </Badge.Root>
                        ))}
                      </div>
                      <div className="text-[11.5px] text-text-muted tabular-nums">
                        {formatBytes(mod.sizeBytes)}
                      </div>
                    </div>

                    <div className="flex shrink-0 items-center gap-2">
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
                              size="icon"
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
