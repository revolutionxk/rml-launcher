import { type EngineFlagRecord, type EngineFlagSource, type EngineScanInfo } from "@/lib/engine";
import { detectFlagType } from "@/lib/fast-flags";

export function getErrorMessage(error: unknown, fallback: string) {
  if (typeof error === "string" && error.length > 0) {
    return error;
  }

  if (error instanceof Error && error.message.length > 0) {
    return error.message;
  }

  return fallback;
}

export function sortFlags(flags: EngineFlagRecord[]) {
  return [...flags].sort(
    (left, right) =>
      Number(right.isOverridden) - Number(left.isOverridden) || left.name.localeCompare(right.name),
  );
}

export function matchesFlagQuery(flag: EngineFlagRecord, query: string) {
  return `${flag.name} ${flag.source} ${flag.value} ${flag.defaultValue}`
    .toLowerCase()
    .includes(query);
}

export function shouldPersistFlagValue(name: string, value: string) {
  const type = detectFlagType(name, value);

  if (type === "boolean") {
    return value === "true" || value === "false";
  }

  if (type === "integer") {
    return /^-?\d+$/.test(value.trim());
  }

  return true;
}

export function isDiffFlag(flag: EngineFlagRecord) {
  return flag.isOverridden && (flag.isCustom || flag.overrideValue !== flag.defaultValue);
}

export function getSourceVariant(source: EngineFlagSource) {
  if (source === "binary") return "green" as const;
  if (source === "lua") return "yellow" as const;
  if (source === "custom") return "purple" as const;
  return "blue" as const;
}

export function getScanVariant(scan: EngineScanInfo) {
  if (scan.source === "fresh") return "green" as const;
  if (scan.source === "cached") return "blue" as const;
  if (scan.source === "remoteOnly") return "yellow" as const;
  return "gray" as const;
}
