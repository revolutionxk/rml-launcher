import { createFileRoute } from "@tanstack/react-router";
import {
  ArrowDown,
  ArrowUp,
  ChevronsUpDown,
  Download,
  Flag,
  MoreHorizontal,
  Plus,
  RefreshCw,
  Search,
  SlidersHorizontal,
  Trash2,
  Upload,
  X,
} from "lucide-react";
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
import { Button } from "@/components/ui/button";
import { Callout } from "@/components/ui/callout";
import { Card } from "@/components/ui/card";
import { EmptyState } from "@/components/ui/empty-state";
import { Input } from "@/components/ui/input";
import { Menu } from "@/components/ui/menu";
import { PageHeader } from "@/components/ui/page-header";
import { Select } from "@/components/ui/select";
import { SegmentGroup } from "@/components/ui/segment-group";
import { TagEditor } from "@/components/ui/tag-editor";
import { Tooltip } from "@/components/ui/tooltip";
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
  isDiffFlag,
  matchesFlagQuery,
  shouldPersistFlagValue,
  sortFlags,
} from "@/lib/engine-utils";
import {
  FLAG_TYPE_COLORS,
  FLAG_TYPE_LABELS,
  type FlagType,
  detectFlagType,
} from "@/lib/fast-flags";
import { cn } from "@/lib/utils";
import { useSetupStore } from "@/stores/setup";

type Translate = ReturnType<typeof useI18n>["t"];

export const Route = createFileRoute("/settings/engine")({
  component: EngineRoute,
});

function EngineRoute() {
  return <EngineFlags />;
}

interface EngineFlagsProps {
  embeddedTargetVersionGuid?: string;
}

const FLAG_ROW_HEIGHT = 46;
const FLAG_LIST_OVERSCAN = 8;

const SOURCE_DOT: Record<EngineFlagSource, string> = {
  binary: "bg-green",
  lua: "bg-yellow",
  custom: "bg-[#a78bfa]",
  remote: "bg-accent",
};

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
type EngineView = "flags" | "config";

type SortColumn = "name" | "type" | "value";
type SortDir = "asc" | "desc";
type FlagSort = { column: SortColumn; dir: SortDir };

const TYPE_ORDER: Record<FlagType, number> = { boolean: 0, integer: 1, string: 2, list: 3 };

function compareFlags(a: EngineFlagRecord, b: EngineFlagRecord, sort: FlagSort): number {
  let result: number;

  if (sort.column === "type") {
    const rankA = TYPE_ORDER[detectFlagType(a.name, a.value)];
    const rankB = TYPE_ORDER[detectFlagType(b.name, b.value)];
    result = rankA - rankB || a.name.localeCompare(b.name);
  } else if (sort.column === "value") {
    const numA = Number(a.value);
    const numB = Number(b.value);
    const numeric =
      a.value.trim() !== "" &&
      b.value.trim() !== "" &&
      !Number.isNaN(numA) &&
      !Number.isNaN(numB);
    result = (numeric ? numA - numB : a.value.localeCompare(b.value)) || a.name.localeCompare(b.name);
  } else {
    result = a.name.localeCompare(b.name);
  }

  return sort.dir === "asc" ? result : -result;
}

function SortHeader({
  label,
  active,
  dir,
  onClick,
  className,
  align = "left",
}: {
  label: string;
  active: boolean;
  dir: SortDir;
  onClick: () => void;
  className?: string;
  align?: "left" | "right";
}) {
  return (
    <button
      type="button"
      onClick={onClick}
      aria-label={label}
      className={cn(
        "group flex items-center gap-1 font-[inherit] text-[10px] font-semibold uppercase tracking-[0.06em]",
        "cursor-pointer outline-none transition-colors",
        active ? "text-text-muted" : "text-text-dim hover:text-text-muted",
        align === "right" && "justify-end",
        className,
      )}
    >
      <span className="truncate">{label}</span>
      {active ? (
        dir === "asc" ? (
          <ArrowUp size={11} className="shrink-0 text-accent" />
        ) : (
          <ArrowDown size={11} className="shrink-0 text-accent" />
        )
      ) : (
        <ChevronsUpDown
          size={11}
          className="shrink-0 opacity-0 transition-opacity group-hover:opacity-60"
        />
      )}
    </button>
  );
}

function ListFlagPreview({
  value,
  emptyLabel,
  onEdit,
}: {
  value: string;
  emptyLabel: string;
  onEdit: () => void;
}) {
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
        <span className="text-[11px] text-text-dim">{emptyLabel}</span>
      ) : (
        <>
          {preview.map((tag, i) => (
            <span
              key={i}
              className="shrink-0 inline-flex items-center px-1.5 py-0.5 bg-surface-2 border border-border rounded-sm text-[10px] font-code text-text leading-none"
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
  t: Translate;
}

function ListFlagEditorModal({
  flag,
  sourceLabel,
  isSaving,
  onChange,
  onRemove,
  onClose,
  t,
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
          className="relative z-10 w-full max-w-120 bg-card border border-border rounded-sm shadow-2xl p-5"
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
                  {t("engine-list-items", { count: tags.length })}
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
                  <Button.Label>{t("engine-list-reset")}</Button.Label>
                </Button.Root>
              )}
              <Button.Root variant="ghost" size="icon" aria-label={t("common-dismiss")} onClick={onClose}>
                <Button.Icon>
                  <X size={13} />
                </Button.Icon>
              </Button.Root>
            </div>
          </div>

          <TagEditor
            value={flag.value}
            onChange={onChange}
            placeholder={t("engine-tag-placeholder")}
          />

          <div className="mt-4 flex items-center justify-between">
            <span className="text-[11px] text-text-dim">{t("engine-list-hint")}</span>
            <Button.Root variant="primary" size="sm" onClick={onClose}>
              <Button.Label>{t("engine-list-done")}</Button.Label>
            </Button.Root>
          </div>
        </motion.div>
      </div>
    </AnimatePresence>,
    document.body,
  );
}

export function EngineFlags({ embeddedTargetVersionGuid }: EngineFlagsProps) {
  const { t } = useI18n();
  const embedded = embeddedTargetVersionGuid != null;
  const flagsIntroDismissed = useSetupStore((s) => s.flagsIntroDismissed);
  const dismissFlagsIntro = useSetupStore((s) => s.dismissFlagsIntro);
  const importInputRef = useRef<HTMLInputElement | null>(null);
  const listRef = useRef<List | null>(null);
  const [flags, setFlags] = useState<EngineFlagRecord[]>([]);
  const [search, setSearch] = useState("");
  const [view, setView] = useState<EngineView>("flags");
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
  const [sort, setSort] = useState<FlagSort | null>(null);

  const toggleSort = (column: SortColumn) => {
    setSort((current) => {
      if (!current || current.column !== column) return { column, dir: "asc" };
      if (current.dir === "asc") return { column, dir: "desc" };
      return null;
    });
  };

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

  const visibleFlags = sort
    ? [...filteredFlags].sort((a, b) => compareFlags(a, b, sort))
    : filteredFlags;
  const existingNames = new Set(flags.map((flag) => flag.name));
  const listKey = `${filterMode}:${deferredSearch}:${filteredFlags.length}:${overrideCount}:${diffCount}:${sort?.column ?? ""}:${sort?.dir ?? ""}`;
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
    
  const effectiveView: EngineView = embedded ? "flags" : view;

  useEffect(() => {
    listRef.current?.recomputeRowHeights();
    listRef.current?.forceUpdateGrid();
  }, [flags, filterMode, deferredSearch, sort]);

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

  const loadEmbeddedTarget = async (guid: string) => {
    setIsLoading(true);
    try {
      const nextState = await setEngineTargetVersion(guid);
      applyEngineState(nextState);
      setErrorMessage(null);
    } catch (error) {
      setErrorMessage(getErrorMessage(error, t("engine-error-load")));
    } finally {
      setIsLoading(false);
    }
  };

  useEffect(() => {
    if (embeddedTargetVersionGuid) {
      void loadEmbeddedTarget(embeddedTargetVersionGuid);
    } else {
      void loadState({ showLoading: true });
    }
  }, [embeddedTargetVersionGuid]);

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

  const scanDotClass =
    scanInfo.source === "fresh"
      ? "bg-green shadow-[0_0_6px_rgba(61,204,122,0.45)]"
      : scanInfo.source === "cached"
        ? "bg-accent shadow-[0_0_6px_var(--color-accent-muted)]"
        : scanInfo.source === "remoteOnly"
          ? "bg-yellow"
          : "bg-text-dim";

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
    const flag = visibleFlags[index];

    if (!flag) {
      return null;
    }

    const type = detectFlagType(flag.name, flag.value);
    const isList = type === "list";
    const isSavingFlag = pendingFlags.has(flag.name);
    const rowStyle: CSSProperties = {
      ...style,
      boxSizing: "border-box",
      padding: "2px 4px",
      width: "100%",
    };
    const detail = flag.isOverridden
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
            "group relative flex h-full items-center gap-2.5 overflow-hidden rounded-sm border pl-3.5 pr-1.5",
            "transition-[border-color,background] duration-150",
            flag.isOverridden
              ? "border-accent/25 bg-accent-muted/5"
              : "border-transparent hover:border-border hover:bg-card-hover",
          )}
        >
          {flag.isOverridden && (
            <span className="absolute inset-y-1.5 left-0 w-[2.5px] rounded-full bg-accent" />
          )}

          <Tooltip.Root>
            <Tooltip.Trigger
              render={
                <div className="flex min-w-0 flex-1 cursor-default items-center gap-2 overflow-hidden">
                  <span
                    className={cn(
                      "h-1.5 w-1.5 shrink-0 rounded-full",
                      flag.isOverridden ? "bg-accent" : SOURCE_DOT[flag.source],
                    )}
                  />
                  <span
                    className={cn(
                      "truncate font-code text-[12px]",
                      flag.isOverridden ? "font-medium text-accent" : "text-text",
                    )}
                  >
                    {flag.name}
                  </span>
                </div>
              }
            />
            <Tooltip.Portal>
              <Tooltip.Positioner>
                <Tooltip.Popup className="max-w-72 leading-normal">
                  <div className="font-code text-[11px] text-text">{flag.name}</div>
                  <div className="mt-1 flex items-center gap-1.5">
                    <span className="text-text-muted">{sourceLabel(flag.source)}</span>
                    <span className="text-text-dim">·</span>
                    <span className="text-text-muted">{detail}</span>
                  </div>
                </Tooltip.Popup>
              </Tooltip.Positioner>
            </Tooltip.Portal>
          </Tooltip.Root>

          <div className="w-14 shrink-0">
            <span
              className={cn(
                "inline-block rounded-sm px-1.5 py-0.5 text-[10px] font-semibold leading-none",
                FLAG_TYPE_COLORS[type],
              )}
            >
              {FLAG_TYPE_LABELS[type]}
            </span>
          </div>

          <div className="flex w-44 shrink-0 items-center justify-end">
            {isList ? (
              <ListFlagPreview
                value={flag.value}
                emptyLabel={t("engine-list-empty")}
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

          <div className="flex w-7 shrink-0 justify-center">
            {flag.isOverridden && (
              <Button.Root
                variant="danger"
                size="icon-sm"
                aria-label={t("engine-reset-flag")}
                disabled={isSavingFlag}
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
            )}
          </div>
        </div>
      </div>
    );
  };

  return (
    <div className="flex h-full min-h-0 flex-col gap-3 overflow-hidden">
      <input
        ref={importInputRef}
        type="file"
        accept="application/json,.json"
        className="hidden"
        onChange={(event) => {
          void importSnapshot(event);
        }}
      />

      {!embedded && (
        <>
      <PageHeader
        className="shrink-0"
        title={t("engine-title")}
        description={
          <>
            {t("engine-description")}
            {scanInfo.targetVersion && (
              <span className="text-text-dim">
                {" · "}
                {t("engine-scan-target", { version: scanInfo.targetVersion })}
              </span>
            )}
          </>
        }
        actions={
          <Tooltip.Provider>
            <Tooltip.Root>
              <Tooltip.Trigger
                render={
                  <div className="flex cursor-default items-center gap-1.5 rounded-full border border-border bg-surface px-2.5 py-1">
                    <span className={cn("h-1.5 w-1.5 rounded-full", scanDotClass)} />
                    <span className="text-[11px] font-medium text-text-muted">
                      {scanStatusLabel}
                    </span>
                  </div>
                }
              />
              <Tooltip.Portal>
                <Tooltip.Positioner>
                  <Tooltip.Popup className="max-w-60 leading-normal">
                    {t("engine-scan-help")}
                  </Tooltip.Popup>
                </Tooltip.Positioner>
              </Tooltip.Portal>
            </Tooltip.Root>
          </Tooltip.Provider>
        }
      />

      <SegmentGroup.Root
        value={view}
        onValueChange={(value) => setView(value as EngineView)}
        className="grid w-full max-w-[320px] shrink-0 grid-cols-2"
      >
        <SegmentGroup.Item value="flags">
          <Flag size={12} />
          {t("engine-tab-flags")}
        </SegmentGroup.Item>
        <SegmentGroup.Item value="config">
          <SlidersHorizontal size={12} />
          {t("engine-tab-config")}
        </SegmentGroup.Item>
      </SegmentGroup.Root>
        </>
      )}

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
            <Callout variant="danger">{errorMessage}</Callout>
          </motion.div>
        )}
      </AnimatePresence>

      {effectiveView === "config" && (
        <motion.div
          initial={{ opacity: 0, y: 4 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.15 }}
          className="shrink-0"
        >
          <Card.Root>
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
            <div className="rounded-sm border border-border bg-surface px-3 py-1.75 text-[13px] text-text-dim lg:min-w-[320px]">
              {t("engine-target-empty")}
            </div>
          )}
        </div>
        <Card.Separator />
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
        </motion.div>
      )}

      {effectiveView === "flags" && (
        <div className="flex min-h-0 flex-1 flex-col gap-2.5">
          {!flagsIntroDismissed && (
            <Callout
              variant="info"
              className="shrink-0"
              title={t("engine-flags-intro-title")}
              onDismiss={dismissFlagsIntro}
              dismissLabel={t("common-dismiss")}
            >
              {t("engine-flags-intro")}
            </Callout>
          )}
          {scanInfo.warning && (
            <Callout variant="warning" className="shrink-0">
              {t("engine-scan-warning", { message: scanInfo.warning })}
            </Callout>
          )}

        <div className="flex shrink-0 flex-wrap items-center gap-2">
          <Input.Root className="min-w-40 flex-1">
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
          <SegmentGroup.Root
            value={filterMode}
            onValueChange={(value) => setFilterMode(value as EngineFilterMode)}
            className="grid w-full shrink-0 grid-cols-3 sm:w-66"
          >
            <SegmentGroup.Item value="all">{t("engine-filter-all")}</SegmentGroup.Item>
            <SegmentGroup.Item value="overrides">
              {t("engine-filter-overrides")}
              {overrideCount > 0 && (
                <span className="ml-1 rounded-full bg-current/15 px-1.5 text-[10px] font-semibold tabular-nums">
                  {overrideCount}
                </span>
              )}
            </SegmentGroup.Item>
            <SegmentGroup.Item value="diff">
              {t("engine-filter-diff")}
              {diffCount > 0 && (
                <span className="ml-1 rounded-full bg-current/15 px-1.5 text-[10px] font-semibold tabular-nums">
                  {diffCount}
                </span>
              )}
            </SegmentGroup.Item>
          </SegmentGroup.Root>
          <Button.Root
            variant={showAddPanel ? "ghost" : "primary"}
            onClick={() => setShowAddPanel((v) => !v)}
          >
            <Button.Icon>
              <Plus
                size={13}
                className={cn("transition-transform duration-200", showAddPanel && "rotate-45")}
              />
            </Button.Icon>
            <Button.Label>{t("engine-add-flag")}</Button.Label>
          </Button.Root>
          <Menu.Root>
            <Menu.Trigger
              render={
                <Button.Root variant="ghost" size="icon" aria-label={t("engine-fast-flags")}>
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
                    disabled={!scanInfo.canPatternScan || isBusy}
                    onClick={() => void loadState({ forceRescan: true })}
                  >
                    <span className="flex h-[13px] w-[13px] items-center justify-center text-text-dim">
                      <RefreshCw size={13} className={cn(isRescanning && "animate-spin")} />
                    </span>
                    <span>{t("engine-rescan")}</span>
                  </Menu.Item>
                  <Menu.Item disabled={isBusy} onClick={() => importInputRef.current?.click()}>
                    <span className="flex h-[13px] w-[13px] items-center justify-center text-text-dim">
                      <Upload size={13} />
                    </span>
                    <span>{t("engine-import")}</span>
                  </Menu.Item>
                  <Menu.Item disabled={overrideCount === 0 || isBusy} onClick={exportSnapshot}>
                    <span className="flex h-[13px] w-[13px] items-center justify-center text-text-dim">
                      <Download size={13} />
                    </span>
                    <span>{t("engine-export")}</span>
                  </Menu.Item>
                  <div className="my-1 h-px bg-border-subtle" />
                  <Menu.Item
                    disabled={overrideCount === 0 || isClearingOverrides}
                    className="text-red data-[highlighted]:text-red"
                    onClick={() => void clearOverrides()}
                  >
                    <span className="flex h-[13px] w-[13px] items-center justify-center text-red/85">
                      <Trash2 size={13} />
                    </span>
                    <span>{t("engine-clear-overrides")}</span>
                  </Menu.Item>
                </Menu.Popup>
              </Menu.Positioner>
            </Menu.Portal>
          </Menu.Root>
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

        <div className="flex min-h-0 flex-1 flex-col overflow-hidden rounded-sm border border-border bg-card/40">
          <div className="flex shrink-0 items-center gap-2.5 border-b border-border-subtle bg-surface/40 py-2 pl-4.5 pr-2.75 text-[10px] font-semibold uppercase tracking-[0.06em] text-text-dim">
            <div className="flex min-w-0 flex-1 items-center gap-2">
              <span className="w-1.5 shrink-0" />
              <SortHeader
                label={t("engine-col-name")}
                active={sort?.column === "name"}
                dir={sort?.dir ?? "asc"}
                onClick={() => toggleSort("name")}
              />
              <span className="font-normal normal-case tracking-normal text-text-dim tabular-nums">
                · {countLabel}
              </span>
            </div>
            <SortHeader
              className="w-14 shrink-0"
              label={t("engine-col-type")}
              active={sort?.column === "type"}
              dir={sort?.dir ?? "asc"}
              onClick={() => toggleSort("type")}
            />
            <SortHeader
              className="w-44 shrink-0"
              align="right"
              label={t("engine-col-value")}
              active={sort?.column === "value"}
              dir={sort?.dir ?? "asc"}
              onClick={() => toggleSort("value")}
            />
            <span className="w-7 shrink-0" />
          </div>

          <div className="min-h-0 flex-1">
            {isLoading ? (
              <div className="flex h-full items-center justify-center text-[12.5px] text-text-muted">
                <span className="flex items-center gap-2">
                  <RefreshCw size={13} className="animate-spin" />
                  {t("engine-loading")}
                </span>
              </div>
            ) : visibleFlags.length === 0 ? (
              <div className="flex h-full items-center justify-center px-6 py-10">
                <EmptyState
                  className="border-transparent bg-transparent p-0 shadow-none"
                  icon={<Flag size={22} />}
                  title={t("engine-empty-title")}
                  description={emptyStateMessage}
                />
              </div>
            ) : (
              <Tooltip.Provider delay={350}>
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
                        rowCount={visibleFlags.length}
                        rowHeight={getFlagRowHeight}
                        rowRenderer={renderFlagRow}
                        overscanRowCount={FLAG_LIST_OVERSCAN}
                        style={{ outline: "none", overflowX: "hidden" }}
                      />
                    );
                  }}
                </AutoSizer>
              </Tooltip.Provider>
            )}
          </div>
        </div>
        </div>
      )}

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
          t={t}
        />
      )}
    </div>
  );
}
