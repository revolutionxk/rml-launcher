import { invoke } from "@tauri-apps/api/core";

export type ModKind = "native" | "dotnet" | "scripts" | "other";

export interface ModEntry {
  id: string;
  name: string;
  enabled: boolean;
  sizeBytes: number;
  kinds: ModKind[];
}

export interface ModsResponse {
  loaderInstalled: boolean;
  mods: ModEntry[];
}

export async function listMods(versionGuid: string) {
  return invoke<ModsResponse>("list_mods", { versionGuid });
}

export async function setModEnabled(versionGuid: string, modId: string, enabled: boolean) {
  return invoke<void>("set_mod_enabled", { versionGuid, modId, enabled });
}

export async function removeMod(versionGuid: string, modId: string) {
  return invoke<void>("remove_mod", { versionGuid, modId });
}

export async function importMod(versionGuid: string, sourcePath: string) {
  return invoke<ModEntry>("import_mod", { versionGuid, sourcePath });
}

export async function openModsDir(versionGuid: string) {
  return invoke<void>("open_mods_dir", { versionGuid });
}
