import { invoke } from "@tauri-apps/api/core";
import { z } from "zod";

export type EngineFlagSource = "remote" | "binary" | "lua" | "custom";
export type EngineScanSource = "cached" | "fresh" | "remoteOnly" | "unavailable";

export interface EngineFlagRecord {
  name: string;
  source: EngineFlagSource;
  defaultValue: string;
  overrideValue: string | null;
  value: string;
  isOverridden: boolean;
  isCustom: boolean;
}

export interface EngineScanInfo {
  canPatternScan: boolean;
  source: EngineScanSource;
  targetVersionGuid: string | null;
  targetVersion: string | null;
  lastScannedVersionGuid: string | null;
  lastScannedAt: string | null;
  warning: string | null;
}

export interface EngineTargetVersionRecord {
  versionGuid: string;
  version: string;
  isDefault: boolean;
}

export interface EngineState {
  flags: EngineFlagRecord[];
  availableFlagCount: number;
  overrideCount: number;
  enableTracking: boolean;
  disableTelemetry: boolean;
  selectedTargetVersionGuid: string | null;
  availableTargets: EngineTargetVersionRecord[];
  scan: EngineScanInfo;
}

export interface EngineOverrideInput {
  name: string;
  value: string;
  custom?: boolean;
}

export interface EngineStatePatch {
  replaceAll?: boolean;
  enableTracking?: boolean;
  disableTelemetry?: boolean;
  overrides?: EngineOverrideInput[];
}

export interface EngineSettingsSnapshot {
  schemaVersion: 1;
  exportedAt: string;
  enableTracking: boolean;
  disableTelemetry: boolean;
  overrides: EngineOverrideInput[];
}

const engineOverrideInputSchema = z.object({
  name: z.string().min(1),
  value: z.string(),
  custom: z.boolean().optional().default(false),
});

const engineSettingsSnapshotSchema = z.object({
  schemaVersion: z.literal(1),
  exportedAt: z.string(),
  enableTracking: z.boolean(),
  disableTelemetry: z.boolean(),
  overrides: z.array(engineOverrideInputSchema),
});

export async function getEngineState() {
  return invoke<EngineState>("get_engine_state");
}

export async function rescanEngineFlags() {
  return invoke<EngineState>("rescan_engine_flags");
}

export async function setEngineTargetVersion(versionGuid: string | null) {
  return invoke<EngineState>("set_engine_target_version", { versionGuid });
}

export async function applyEngineStatePatch(patch: EngineStatePatch) {
  return invoke<EngineState>("apply_engine_state_patch", { patch });
}

export async function upsertEngineFlagOverride(name: string, value: string, custom = false) {
  return invoke<void>("upsert_engine_flag_override", { name, value, custom });
}

export async function removeEngineFlagOverride(name: string) {
  return invoke<void>("remove_engine_flag_override", { name });
}

export async function clearEngineFlagOverrides() {
  return invoke<void>("clear_engine_flag_overrides");
}

export async function setEngineGeneralSettings(
  enableTracking: boolean,
  disableTelemetry: boolean,
) {
  return invoke<void>("set_engine_general_settings", {
    enableTracking,
    disableTelemetry,
  });
}

export function createEngineSettingsSnapshot({
  enableTracking,
  disableTelemetry,
  flags,
}: Pick<EngineState, "enableTracking" | "disableTelemetry" | "flags">): EngineSettingsSnapshot {
  return {
    schemaVersion: 1,
    exportedAt: new Date().toISOString(),
    enableTracking,
    disableTelemetry,
    overrides: flags
      .filter((flag) => flag.isOverridden)
      .map((flag) => ({
        name: flag.name,
        value: flag.value,
        custom: flag.isCustom,
      })),
  };
}

export function parseEngineSettingsSnapshot(raw: string) {
  return engineSettingsSnapshotSchema.parse(JSON.parse(raw));
}

export function downloadEngineSettingsSnapshot(snapshot: EngineSettingsSnapshot, fileName: string) {
  const blob = new Blob([JSON.stringify(snapshot, null, 2)], { type: "application/json" });
  const url = URL.createObjectURL(blob);
  const anchor = document.createElement("a");

  anchor.href = url;
  anchor.download = fileName;
  anchor.click();
  URL.revokeObjectURL(url);
}