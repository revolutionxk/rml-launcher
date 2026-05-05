import { createFileRoute } from "@tanstack/react-router";
import { Download, Plus, RefreshCw, Search, Trash2, Upload, X } from "lucide-react";
import { AnimatePresence, motion } from "motion/react";
import {
  type ChangeEvent,
  type CSSProperties,
  startTransition,
  useDeferredValue,
  useEffect,
  useRef,
  useState,
} from "react";
import { createPortal } from "react-dom";
import { AutoSizer, List, type ListRowProps } from "react-virtualized";

import { AddFlagPanel } from "@/components/add-flag-panel";
import { FlagValueEditor } from "@/components/flag-value-editor";
import Toggle from "@/components/toggle";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Card } from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { Select } from "@/components/ui/select";
import { SegmentGroup } from "@/components/ui/segment-group";
import { TagEditor } from "@/components/ui/tag-editor";
import { useI18n } from "@/i18n";
import {
  applyEngineStatePatch,
  clearEngineFlagOverrides,
  createEngineSettingsSnapshot,
  downloadEngineSettingsSnapshot,
  getEngineState,
  parseEngineSettingsSnapshot,
  removeEngineFlagOverride,
  rescanEngineFlags,
  setEngineGeneralSettings,
  setEngineTargetVersion,
  type EngineFlagRecord,
  type EngineFlagSource,
  type EngineScanInfo,
  type EngineState,
  type EngineTargetVersionRecord,
  upsertEngineFlagOverride,
} from "@/lib/engine";
import {
  getErrorMessage,
  getScanVariant,
  getSourceVariant,
  isDiffFlag,
  matchesFlagQuery,
  shouldPersistFlagValue,
  sortFlags,
} from "@/lib/engine-utils";
import { FLAG_TYPE_COLORS, FLAG_TYPE_LABELS, detectFlagType } from "@/lib/fast-flags";
import { cn } from "@/lib/utils";

export const Route = createFileRoute("/settings/engine")({
  component: EnginePage,
});

const FLAG_ROW_HEIGHT = 76;
const FLAG_LIST_OVERSCAN = 8;

const EMPTY_SCAN_INFO: EngineScanInfo = {
  canPatternScan: false,
  source: "unavailable",
  targetVersionGuid: null,
  targetVersion: null,
  lastScannedVersionGuid: null,
  lastScannedAt: null,
  warning: null,
};

type EngineFilterMode = "all" | "overrides" | "diff";

function ListFlagPreview({ value, onEdit }: { value: string; onEdit: () => void }) {
  const tags = value ? value.split(";").filter(Boolean) : [];
  const preview = tags.slice(0, 2);
  const extra = tags.length - 2;

  return (
    <button
      type="button"
      onClick={onEdit}
      className="flex items-center gap-1 w-full min-h-8 bg-surface border border-border rounded-sm px-2 py-1.5 hover:border-border-focus transition-[border-color] duration-150 cursor-pointer overflow-hidden"
    >
      {tags.length === 0 ? (
        <span className="text-[11px] text-text-dim">Empty — click to edit</span>
      ) : (
        <>
          {preview.map((tag, i) => (
            <span
              key={i}
              className="shrink-0 inline-flex items-center px-1.5 py-0.5 bg-surface-2 border border-border rounded text-[10px] font-code text-text leading-none"
            >
              {tag.length > 14 ? `${tag.slice(0, 12)}\u2026` : tag}
            </span>
          ))}
          {extra > 0 && <span className="shrink-0 text-[10px] text-text-dim">+{extra}</span>}
        </>
      )}
    </button>
  );
}

interface ListFlagEditorModalProps {
  flag: EngineFlagRecord;
  sourceLabel: string;
  isSaving: boolean;
  onChange: (value: string) => void;
  onRemove: () => void;
  onClose: () => void;
}

function ListFlagEditorModal({
  flag,
  sourceLabel,
  isSaving,
  onChange,
  onRemove,
  onClose,
}: ListFlagEditorModalProps) {
  const tags = flag.value ? flag.value.split(";").filter(Boolean) : [];

  return createPortal(
    <AnimatePresence>
      <div className="fixed inset-0 z-50 flex items-center justify-center p-4">
        <motion.div
          key="list-modal-backdrop"
          className="absolute inset-0 bg-black/60"
          initial={{ opacity: 0 }}
          animate={{ opacity: 1 }}
          exit={{ opacity: 0 }}
          transition={{ duration: 0.15 }}
          onClick={onClose}
        />
        <motion.div
          key="list-modal-panel"
          className="relative z-10 w-full max-w-120 bg-card border border-border rounded-xl shadow-2xl p-5"
          initial={{ opacity: 0, scale: 0.96, y: 10 }}
          animate={{ opacity: 1, scale: 1, y: 0 }}
          exit={{ opacity: 0, scale: 0.96, y: 6 }}
          transition={{ duration: 0.18, ease: [0.25, 0.1, 0.25, 1] }}
        >
          <div className="flex items-start justify-between gap-3 mb-4">
            <div className="min-w-0 flex-1">
              <div className="font-code text-[12px] text-accent font-medium truncate">
                {flag.name}
              </div>
              <div className="mt-0.5 flex items-center gap-1.5">
                <span className="text-[11px] text-text-dim">
                  {tags.length} item{tags.length !== 1 ? "s" : ""}
                </span>
                <span className="text-[10px] text-text-dim">·</span>
                <span className="text-[11px] text-text-dim">{sourceLabel}</span>
              </div>
            </div>
            <div className="flex shrink-0 items-center gap-1.5">
              {flag.isOverridden && (
                <Button.Root
                  variant="danger"
                  size="sm"
                  disabled={isSaving}
                  onClick={() => {
                    onRemove();
                    onClose();
                  }}
                >
                  <Button.Icon>
                    <Trash2 size={11} />
                  </Button.Icon>
                  <Button.Label>Reset</Button.Label>
                </Button.Root>
              )}
              <Button.Root variant="ghost" size="icon" onClick={onClose}>
                <Button.Icon>
                  <X size={13} />
                </Button.Icon>
              </Button.Root>
            </div>
          </div>

          <TagEditor value={flag.value} onChange={onChange} />

          <div className="mt-4 flex items-center justify-between">
            <span className="text-[11px] text-text-dim">Press Enter or ; to add values</span>
            <Button.Root variant="primary" size="sm" onClick={onClose}>
              <Button.Label>Done</Button.Label>
            </Button.Root>
          </div>
        </motion.div>
      </div>
    </AnimatePresence>,
    document.body,
  );
}

function EnginePage() {
  const { t } = useI18n();
  const importInputRef = useRef<HTMLInputElement | null>(null);
  const listRef = useRef<List | null>(null);
  const [flags, setFlags] = useState<EngineFlagRecord[]>([]);
  const [search, setSearch] = useState("");
  const [filterMode, setFilterMode] = useState<EngineFilterMode>("all");
  const [enableTracking, setEnableTracking] = useState(true);
  const [disableTelemetry, setDisableTelemetry] = useState(false);
  const [scanInfo, setScanInfo] = useState<EngineScanInfo>(EMPTY_SCAN_INFO);
  const [selectedTargetVersionGuid, setSelectedTargetVersionGuid] = useState<string | null>(null);
  const [availableTargets, setAvailableTargets] = useState<EngineTargetVersionRecord[]>([]);
  const [showAddPanel, setShowAddPanel] = useState(false);
  const [isLoading, setIsLoading] = useState(true);
  const [isRescanning, setIsRescanning] = useState(false);
  const [isSwitchingTarget, setIsSwitchingTarget] = useState(false);
  const [isSavingGeneral, setIsSavingGeneral] = useState(false);
  const [isClearingOverrides, setIsClearingOverrides] = useState(false);
  const [isApplyingBatch, setIsApplyingBatch] = useState(false);
  const [pendingFlags, setPendingFlags] = useState<Set<string>>(() => new Set());
  const [errorMessage, setErrorMessage] = useState<string | null>(null);
  const [editingListFlagName, setEditingListFlagName] = useState<string | null>(null);

  const deferredSearch = useDeferredValue(search.trim().toLowerCase());
  const hasSearchQuery = deferredSearch.length > 0;
  const overrideCount = flags.filter((flag) => flag.isOverridden).length;
  const diffCount = flags.filter(isDiffFlag).length;
  const filteredFlags = flags.filter((flag) => {
    if (filterMode === "overrides" && !flag.isOverridden) {
      return false;
    }

    if (filterMode === "diff" && !isDiffFlag(flag)) {
      return false;
    }

    return !hasSearchQuery || matchesFlagQuery(flag, deferredSearch);
  });
  const existingNames = new Set(flags.map((flag) => flag.name));
  const listKey = `${filterMode}:${deferredSearch}:${filteredFlags.length}:${overrideCount}:${diffCount}`;
  const isBusy =
    isLoading ||
    isRescanning ||
    isSwitchingTarget ||
    isSavingGeneral ||
    isClearingOverrides ||
    isApplyingBatch;
  const editingListFlag = editingListFlagName
    ? (flags.find((f) => f.name === editingListFlagName) ?? null)
    : null;

  useEffect(() => {
    listRef.current?.recomputeRowHeights();
    listRef.current?.forceUpdateGrid();
  }, [flags, filterMode, deferredSearch]);

  const applyEngineState = (state: EngineState) => {
    startTransition(() => {
      setFlags(sortFlags(state.flags));
      setEnableTracking(state.enableTracking);
      setDisableTelemetry(state.disableTelemetry);
      setSelectedTargetVersionGuid(state.selectedTargetVersionGuid);
      setAvailableTargets(state.availableTargets);
      setScanInfo(state.scan);
    });
  };

  const loadState = async ({ showLoading = false, forceRescan = false } = {}) => {
    if (showLoading) {
      setIsLoading(true);
    }

    if (forceRescan) {
      setIsRescanning(true);
    }

    try {
      const nextState = forceRescan ? await rescanEngineFlags() : await getEngineState();
      applyEngineState(nextState);
      setErrorMessage(null);
    } catch (error) {
      setErrorMessage(getErrorMessage(error, t("engine-error-load")));
    } finally {
      setIsLoading(false);
      setIsRescanning(false);
    }
  };

  useEffect(() => {
    void loadState({ showLoading: true });
  }, []);

  const handleTargetChange = async (versionGuid: string | null) => {
    const nextTargetVersionGuid = versionGuid === "__auto__" ? null : versionGuid;

    if (nextTargetVersionGuid === selectedTargetVersionGuid) {
      return;
    }

    setIsSwitchingTarget(true);

    try {
      const nextState = await setEngineTargetVersion(nextTargetVersionGuid);
      applyEngineState(nextState);
      setErrorMessage(null);
    } catch (error) {
      setErrorMessage(getErrorMessage(error, t("engine-error-load")));
    } finally {
      setIsSwitchingTarget(false);
    }
  };

  const setFlagPending = (name: string, pending: boolean) => {
    setPendingFlags((current) => {
      const next = new Set(current);

      if (pending) {
        next.add(name);
      } else {
        next.delete(name);
      }

      return next;
    });
  };

  const updateFlags = (updater: (current: EngineFlagRecord[]) => EngineFlagRecord[]) => {
    setFlags((current) => sortFlags(updater(current)));
  };

  const persistGeneralSettings = async (
    nextEnableTracking: boolean,
    nextDisableTelemetry: boolean,
    rollback: () => void,
  ) => {
    setIsSavingGeneral(true);

    try {
      await setEngineGeneralSettings(nextEnableTracking, nextDisableTelemetry);
      setErrorMessage(null);
    } catch (error) {
      rollback();
      setErrorMessage(
        t("engine-error-save", {
          message: getErrorMessage(error, t("engine-error-load")),
        }),
      );
    } finally {
      setIsSavingGeneral(false);
    }
  };

  const exportSnapshot = () => {
    const snapshot = createEngineSettingsSnapshot({
      enableTracking,
      disableTelemetry,
      flags,
    });
    const timestamp = new Date().toISOString().replace(/[:.]/g, "-");
    const fileName = scanInfo.targetVersion
      ? `rml-engine-${scanInfo.targetVersion}-${timestamp}.json`
      : `rml-engine-${timestamp}.json`;

    downloadEngineSettingsSnapshot(snapshot, fileName);
  };

  const importSnapshot = async (event: ChangeEvent<HTMLInputElement>) => {
    const input = event.currentTarget;
    const file = input.files?.[0];

    if (!file) {
      return;
    }

    setIsApplyingBatch(true);

    try {
      const snapshot = parseEngineSettingsSnapshot(await file.text());
      const nextState = await applyEngineStatePatch({
        replaceAll: true,
        enableTracking: snapshot.enableTracking,
        disableTelemetry: snapshot.disableTelemetry,
        overrides: snapshot.overrides,
      });
      applyEngineState(nextState);
      setErrorMessage(null);
    } catch (error) {
      setErrorMessage(
        t("engine-error-import", {
          message: getErrorMessage(error, t("engine-error-load")),
        }),
      );
    } finally {
      input.value = "";
      setIsApplyingBatch(false);
    }
  };

  const updateValue = (flag: EngineFlagRecord, value: string) => {
    updateFlags((current) =>
      current.map((entry) =>
        entry.name === flag.name
          ? {
              ...entry,
              value,
              overrideValue: value,
              isOverridden: true,
            }
          : entry,
      ),
    );

    if (!shouldPersistFlagValue(flag.name, value)) {
      return;
    }

    setFlagPending(flag.name, true);
    void upsertEngineFlagOverride(flag.name, value, flag.isCustom).then(
      () => {
        setFlagPending(flag.name, false);
        setErrorMessage(null);
      },
      async (error) => {
        setFlagPending(flag.name, false);
        setErrorMessage(
          t("engine-error-save", {
            message: getErrorMessage(error, t("engine-error-load")),
          }),
        );
        await loadState();
      },
    );
  };

  const removeFlag = async (flag: EngineFlagRecord) => {
    const previousFlags = flags;
    setFlagPending(flag.name, true);
    updateFlags((current) =>
      current
        .filter((entry) => !(entry.name === flag.name && entry.isCustom))
        .map((entry) =>
          entry.name === flag.name
            ? {
                ...entry,
                value: entry.defaultValue,
                overrideValue: null,
                isOverridden: false,
              }
            : entry,
        ),
    );

    try {
      await removeEngineFlagOverride(flag.name);
      setErrorMessage(null);
    } catch (error) {
      setFlags(previousFlags);
      setErrorMessage(
        t("engine-error-save", {
          message: getErrorMessage(error, t("engine-error-load")),
        }),
      );
    } finally {
      setFlagPending(flag.name, false);
    }
  };

  const addFlag = (name: string, value: string) => {
    const nextFlag: EngineFlagRecord = {
      name,
      source: "custom",
      defaultValue: value,
      overrideValue: value,
      value,
      isOverridden: true,
      isCustom: true,
    };

    updateFlags((current) => [...current.filter((entry) => entry.name !== name), nextFlag]);
    setFlagPending(name, true);
    setErrorMessage(null);

    void upsertEngineFlagOverride(name, value, true).then(
      () => {
        setFlagPending(name, false);
      },
      async (error) => {
        setFlagPending(name, false);
        setErrorMessage(
          t("engine-error-save", {
            message: getErrorMessage(error, t("engine-error-load")),
          }),
        );
        await loadState();
      },
    );
  };

  const clearOverrides = async () => {
    const previousFlags = flags;
    setIsClearingOverrides(true);
    updateFlags((current) =>
      current
        .filter((entry) => !entry.isCustom)
        .map((entry) => ({
          ...entry,
          value: entry.defaultValue,
          overrideValue: null,
          isOverridden: false,
        })),
    );

    try {
      await clearEngineFlagOverrides();
      setErrorMessage(null);
    } catch (error) {
      setFlags(previousFlags);
      setErrorMessage(
        t("engine-error-save", {
          message: getErrorMessage(error, t("engine-error-load")),
        }),
      );
    } finally {
      setIsClearingOverrides(false);
    }
  };

  const scanStatusLabel =
    scanInfo.source === "fresh"
      ? t("engine-scan-status-fresh")
      : scanInfo.source === "cached"
        ? t("engine-scan-status-cached")
        : scanInfo.source === "remoteOnly"
          ? t("engine-scan-status-remote")
          : t("engine-scan-status-unavailable");

  const countLabel =
    filterMode === "all" && !hasSearchQuery
      ? t("engine-total", { count: flags.length })
      : t("engine-total-filtered", { count: filteredFlags.length, total: flags.length });

  const emptyStateMessage = hasSearchQuery
    ? t("engine-empty-search")
    : filterMode === "diff"
      ? t("engine-empty-diff")
      : filterMode === "overrides"
        ? t("engine-empty-overrides")
        : t("engine-empty-idle");

  const sourceLabel = (source: EngineFlagSource) => {
    if (source === "binary") return t("engine-source-binary");
    if (source === "lua") return t("engine-source-lua");
    if (source === "custom") return t("engine-source-custom");
    return t("engine-source-remote");
  };
  const selectedTargetValue = selectedTargetVersionGuid ?? "__auto__";

  const formatPreviewValue = (value: string) => {
    const normalized = value.trim();

    if (normalized.length === 0) {
      return t("engine-value-empty");
    }

    return normalized.length > 56 ? `${normalized.slice(0, 53)}...` : normalized;
  };

  const getFlagRowHeight = () => FLAG_ROW_HEIGHT;

  const renderFlagRow = ({ index, key, style }: ListRowProps) => {
    const flag = filteredFlags[index];

    if (!flag) {
      return null;
    }

    const type = detectFlagType(flag.name, flag.value);
    const isList = type === "list";
    const isBoolean = type === "boolean";
    const isSavingFlag = pendingFlags.has(flag.name);
    const rowStyle: CSSProperties = {
      ...style,
      boxSizing: "border-box",
      padding: "3px 6px",
      width: "100%",
    };
    const metadata = flag.isOverridden
      ? t("engine-default-override-value", {
          default: formatPreviewValue(flag.defaultValue),
          override: formatPreviewValue(flag.value),
        })
      : t("engine-default-value", {
          value: formatPreviewValue(flag.defaultValue),
        });

    return (
      <div key={key} style={rowStyle}>
        <div
          className={cn(
            "flex h-full items-center gap-3 rounded-lg border border-border bg-card px-3.5 py-2.5",
            "transition-[border-color,background] duration-150 hover:bg-card-hover",
            flag.isOverridden && "border-accent/25 bg-accent-muted/5",
          )}
        >
          <div className="min-w-0 flex-1 overflow-hidden">
            <div className="flex items-center gap-1.5">
              <span className="truncate font-code text-[12px] font-medium text-accent">
                {flag.name}
              </span>
              <span
                className={cn(
                  "shrink-0 rounded px-1.5 py-0.5 text-[10px] font-semibold leading-none",
                  FLAG_TYPE_COLORS[type],
                )}
              >
                {FLAG_TYPE_LABELS[type]}
              </span>
            </div>
            <div className="mt-1 flex items-center gap-1.5 overflow-hidden">
              <Badge.Root variant={getSourceVariant(flag.source)} className="shrink-0">
                <Badge.Label>{sourceLabel(flag.source)}</Badge.Label>
              </Badge.Root>
              {flag.isOverridden && (
                <Badge.Root variant="gray" className="shrink-0">
                  <Badge.Label>{t("engine-badge-overridden")}</Badge.Label>
                </Badge.Root>
              )}
              <span className="truncate text-[11px] text-text-dim">{metadata}</span>
            </div>
          </div>

          <div
            className={cn(
              "flex shrink-0 items-center",
              isList ? "w-44" : isBoolean ? "w-16 justify-end" : "w-36 justify-end",
            )}
          >
            {isList ? (
              <ListFlagPreview
                value={flag.value}
                onEdit={() => setEditingListFlagName(flag.name)}
              />
            ) : (
              <FlagValueEditor
                name={flag.name}
                value={flag.value}
                onChange={(value) => updateValue(flag, value)}
              />
            )}
          </div>

          <div className="shrink-0">
            <Button.Root
              variant="danger"
              size="icon"
              aria-label={t("engine-remove-flag")}
              disabled={!flag.isOverridden || isSavingFlag}
              onClick={() => {
                void removeFlag(flag);
              }}
            >
              <Button.Icon>
                {isSavingFlag ? (
                  <RefreshCw size={12} className="animate-spin" />
                ) : (
                  <Trash2 size={12} />
                )}
              </Button.Icon>
            </Button.Root>
          </div>
        </div>
      </div>
    );
  };

  return (
    <div className="flex h-full min-h-0 flex-col overflow-hidden gap-3">
      <input
        ref={importInputRef}
        type="file"
        accept="application/json,.json"
        className="hidden"
        onChange={(event) => {
          void importSnapshot(event);
        }}
      />

      <div className="shrink-0 flex items-start justify-between gap-3">
        <div className="min-w-0">
          <h1 className="text-[18px] font-semibold text-text tracking-[-0.018em] leading-tight">
            {t("engine-title")}
          </h1>
          <p className="mt-0.5 text-[12.5px] leading-normal text-text-muted">
            {scanInfo.targetVersion
              ? t("engine-scan-target", { version: scanInfo.targetVersion })
              : t("engine-description")}
          </p>
        </div>
        <div className="flex shrink-0 flex-wrap items-center justify-end gap-1.5 pt-0.5">
          <Badge.Root variant={getScanVariant(scanInfo)}>
            <Badge.Label>{scanStatusLabel}</Badge.Label>
          </Badge.Root>
          <Badge.Root variant="gray">
            <Badge.Label>{t("engine-overrides-total", { count: overrideCount })}</Badge.Label>
          </Badge.Root>
          <Badge.Root variant="gray">
            <Badge.Label>{t("engine-diff-total", { count: diffCount })}</Badge.Label>
          </Badge.Root>
        </div>
      </div>

      <AnimatePresence initial={false}>
        {errorMessage && (
          <motion.div
            key="error"
            initial={{ opacity: 0, height: 0 }}
            animate={{ opacity: 1, height: "auto" }}
            exit={{ opacity: 0, height: 0 }}
            transition={{ duration: 0.15 }}
            className="shrink-0 overflow-hidden"
          >
            <div className="rounded-lg border border-red/30 bg-red/10 px-4 py-2.5 text-[12px] text-red">
              {errorMessage}
            </div>
          </motion.div>
        )}
      </AnimatePresence>

      <Card.Root className="shrink-0">
        <div className="flex flex-col gap-3 px-4 py-3 lg:flex-row lg:items-center lg:justify-between">
          <div className="min-w-0">
            <div className="text-[12.5px] font-medium text-text leading-[1.3]">
              {t("engine-target-label")}
            </div>
            <div className="mt-0.5 text-[11px] text-text-muted leading-[1.4]">
              {availableTargets.length > 0
                ? t("engine-target-description")
                : t("engine-target-empty")}
            </div>
          </div>
          {availableTargets.length > 0 ? (
            <Select.Root value={selectedTargetValue} onValueChange={handleTargetChange}>
              <Select.Trigger className="w-full lg:w-[320px]" disabled={isBusy} />
              <Select.Portal>
                <Select.Positioner>
                  <Select.Popup>
                    <Select.ScrollUpArrow />
                    <Select.List>
                      <Select.Item value="__auto__">{t("engine-target-auto")}</Select.Item>
                      {availableTargets.map((target) => (
                        <Select.Item key={target.versionGuid} value={target.versionGuid}>
                          {target.isDefault
                            ? `${target.version} · ${t("engine-target-default")}`
                            : target.version}
                        </Select.Item>
                      ))}
                    </Select.List>
                    <Select.ScrollDownArrow />
                  </Select.Popup>
                </Select.Positioner>
              </Select.Portal>
            </Select.Root>
          ) : (
            <div className="rounded-sm border border-border bg-surface px-3 py-[7px] text-[13px] text-text-dim lg:min-w-[320px]">
              {t("engine-target-empty")}
            </div>
          )}
        </div>
      </Card.Root>

      <Card.Root className="shrink-0">
        <div className="grid grid-cols-2 divide-x divide-border">
          <div
            className={cn(
              "flex items-center justify-between gap-3 px-4 py-3 transition-[background] duration-150 hover:bg-white/2",
              isSavingGeneral && "opacity-50 pointer-events-none",
            )}
          >
            <div className="min-w-0">
              <div className="text-[12.5px] font-medium text-text leading-[1.3]">
                {t("engine-tracking-label")}
              </div>
              <div className="mt-0.5 text-[11px] text-text-muted leading-[1.4] truncate">
                {t("engine-tracking-description")}
              </div>
            </div>
            <div className="shrink-0">
              <Toggle
                checked={enableTracking}
                disabled={isSavingGeneral}
                onChange={(checked) => {
                  const previous = enableTracking;
                  setEnableTracking(checked);
                  void persistGeneralSettings(checked, disableTelemetry, () => {
                    setEnableTracking(previous);
                  });
                }}
              />
            </div>
          </div>
          <div
            className={cn(
              "flex items-center justify-between gap-3 px-4 py-3 transition-[background] duration-150 hover:bg-white/2",
              isSavingGeneral && "opacity-50 pointer-events-none",
            )}
          >
            <div className="min-w-0">
              <div className="text-[12.5px] font-medium text-text leading-[1.3]">
                {t("engine-telemetry-label")}
              </div>
              <div className="mt-0.5 text-[11px] text-text-muted leading-[1.4] truncate">
                {t("engine-telemetry-description")}
              </div>
            </div>
            <div className="shrink-0">
              <Toggle
                checked={disableTelemetry}
                disabled={isSavingGeneral}
                onChange={(checked) => {
                  const previous = disableTelemetry;
                  setDisableTelemetry(checked);
                  void persistGeneralSettings(enableTracking, checked, () => {
                    setDisableTelemetry(previous);
                  });
                }}
              />
            </div>
          </div>
        </div>
      </Card.Root>

      {scanInfo.warning && (
        <div className="shrink-0 rounded-lg border border-yellow/25 bg-yellow/10 px-4 py-2.5 text-[12px] text-yellow">
          {t("engine-scan-warning", { message: scanInfo.warning })}
        </div>
      )}
      <div className="min-h-0 flex-1 flex flex-col gap-2.5">
        <div className="shrink-0 flex items-center gap-2">
          <div className="min-w-0 flex-1">
            <div className="flex items-baseline gap-2">
              <span className="text-[12.5px] font-semibold text-text">
                {t("engine-fast-flags")}
              </span>
              <span className="text-[11.5px] text-text-dim">{countLabel}</span>
            </div>
          </div>
          <div className="flex flex-wrap items-center justify-end gap-1.5">
            <Button.Root
              variant="ghost"
              size="sm"
              disabled={!scanInfo.canPatternScan || isBusy}
              onClick={() => void loadState({ forceRescan: true })}
            >
              <Button.Icon>
                <RefreshCw size={11} className={cn(isRescanning && "animate-spin")} />
              </Button.Icon>
              <Button.Label>{t("engine-rescan")}</Button.Label>
            </Button.Root>
            <Button.Root
              variant="ghost"
              size="sm"
              disabled={isBusy}
              onClick={() => importInputRef.current?.click()}
            >
              <Button.Icon>
                <Upload size={11} />
              </Button.Icon>
              <Button.Label>{t("engine-import")}</Button.Label>
            </Button.Root>
            <Button.Root
              variant="ghost"
              size="sm"
              disabled={overrideCount === 0 || isBusy}
              onClick={exportSnapshot}
            >
              <Button.Icon>
                <Download size={11} />
              </Button.Icon>
              <Button.Label>{t("engine-export")}</Button.Label>
            </Button.Root>
            <div className="h-4 w-px self-center bg-border mx-0.5" />
            <Button.Root
              variant="danger"
              size="sm"
              disabled={overrideCount === 0 || isClearingOverrides}
              onClick={() => void clearOverrides()}
            >
              <Button.Icon>
                <Trash2 size={11} />
              </Button.Icon>
              <Button.Label>{t("engine-clear-overrides")}</Button.Label>
            </Button.Root>
            <Button.Root
              variant={showAddPanel ? "ghost" : "primary"}
              size="sm"
              onClick={() => setShowAddPanel((v) => !v)}
            >
              <Button.Icon>
                <Plus
                  size={11}
                  className={cn("transition-transform duration-200", showAddPanel && "rotate-45")}
                />
              </Button.Icon>
              <Button.Label>{t("engine-add-flag")}</Button.Label>
            </Button.Root>
          </div>
        </div>

        <AnimatePresence initial={false}>
          {showAddPanel && (
            <motion.div
              key="add-panel"
              initial={{ opacity: 0, height: 0 }}
              animate={{ opacity: 1, height: "auto" }}
              exit={{ opacity: 0, height: 0 }}
              transition={{ duration: 0.18, ease: [0.25, 0.1, 0.25, 1] }}
              className="shrink-0 overflow-hidden"
            >
              <AddFlagPanel
                existingNames={existingNames}
                onAdd={addFlag}
                onClose={() => setShowAddPanel(false)}
              />
            </motion.div>
          )}
        </AnimatePresence>

        <div className="shrink-0 flex items-center gap-2">
          <SegmentGroup.Root
            value={filterMode}
            onValueChange={(value) => setFilterMode(value as EngineFilterMode)}
            className="grid grid-cols-3 flex-1"
          >
            <SegmentGroup.Item value="all">{t("engine-filter-all")}</SegmentGroup.Item>
            <SegmentGroup.Item value="overrides">{t("engine-filter-overrides")}</SegmentGroup.Item>
            <SegmentGroup.Item value="diff">{t("engine-filter-diff")}</SegmentGroup.Item>
          </SegmentGroup.Root>
          <Input.Root className="w-52 shrink-0">
            <Input.Icon>
              <Search size={13} />
            </Input.Icon>
            <Input.Field
              hasLeadingIcon
              placeholder={t("engine-search-placeholder")}
              value={search}
              onChange={(event) => setSearch(event.target.value)}
            />
          </Input.Root>
        </div>

        {isLoading ? (
          <div className="shrink-0 rounded-lg border border-border bg-card px-4 py-4 text-[12.5px] text-text-muted">
            {t("engine-loading")}
          </div>
        ) : filteredFlags.length === 0 ? (
          <div className="shrink-0 rounded-lg border border-border bg-card px-4 py-4 text-[12.5px] text-text-muted">
            {emptyStateMessage}
          </div>
        ) : null}

        {!isLoading && filteredFlags.length > 0 && (
          <div className="min-h-0 flex-1">
            <div className="h-full overflow-hidden rounded-xl border border-border bg-card/40">
              <AutoSizer>
                {({ height, width }) => {
                  if (height <= 0 || width <= 0) return null;
                  return (
                    <List
                      ref={(instance) => {
                        listRef.current = instance;
                      }}
                      key={listKey}
                      width={width}
                      height={height}
                      rowCount={filteredFlags.length}
                      rowHeight={getFlagRowHeight}
                      rowRenderer={renderFlagRow}
                      overscanRowCount={FLAG_LIST_OVERSCAN}
                      style={{ outline: "none", overflowX: "hidden" }}
                    />
                  );
                }}
              </AutoSizer>
            </div>
          </div>
        )}
      </div>

      {editingListFlag && (
        <ListFlagEditorModal
          flag={editingListFlag}
          sourceLabel={sourceLabel(editingListFlag.source)}
          isSaving={pendingFlags.has(editingListFlag.name)}
          onChange={(value) => updateValue(editingListFlag, value)}
          onRemove={() => {
            void removeFlag(editingListFlag);
          }}
          onClose={() => setEditingListFlagName(null)}
        />
      )}
    </div>
  );
}
