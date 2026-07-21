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

export async function listMods(installationId: string) {
  return invoke<ModsResponse>("list_mods", { installationId });
}

export async function setModEnabled(installationId: string, modId: string, enabled: boolean) {
  return invoke<void>("set_mod_enabled", { installationId, modId, enabled });
}

export async function removeMod(installationId: string, modId: string) {
  return invoke<void>("remove_mod", { installationId, modId });
}

export async function importMod(installationId: string, sourcePath: string) {
  return invoke<ModEntry>("import_mod", { installationId, sourcePath });
}

export async function openModsDir(installationId: string) {
  return invoke<void>("open_mods_dir", { installationId });
}
