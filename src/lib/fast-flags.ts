export type FlagType = "boolean" | "integer" | "string" | "list";

export interface FastFlag {
  id: string;
  name: string;
  value: string;
}

export function detectFlagType(name: string, value: string): FlagType {
  if (/^(FFlag|DFFlag|SFFlag)/i.test(name)) return "boolean";
  if (/^(FInt|DFInt|SFInt|FLog|DFLog|SFLog)/i.test(name)) return "integer";
  if (value.includes(";")) return "list";
  if (value === "true" || value === "false") return "boolean";
  if (/^-?\d+$/.test(value.trim())) return "integer";
  return "string";
}

export function defaultValueForType(type: FlagType): string {
  if (type === "boolean") return "false";
  if (type === "integer") return "0";
  return "";
}

export const FLAG_TYPE_LABELS: Record<FlagType, string> = {
  boolean: "bool",
  integer: "int",
  string: "str",
  list: "list",
};

export const FLAG_TYPE_COLORS: Record<FlagType, string> = {
  boolean: "text-accent bg-accent-muted",
  integer: "text-green bg-green-muted",
  string: "text-[#fb923c] bg-[rgba(251,146,60,0.12)]",
  list: "text-[#a78bfa] bg-[rgba(139,92,246,0.12)]",
};

export const FLAG_TYPE_HINTS: Record<FlagType, string> = {
  boolean: "Boolean — toggles true / false",
  integer: "Integer — accepts a whole number",
  string: "String — accepts any text value",
  list: "List — multiple values separated by semicolons",
};
