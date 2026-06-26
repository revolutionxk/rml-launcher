import { invoke } from "@tauri-apps/api/core";

import type { ModLoaderInstalled } from "@/lib/modloader";
import type { StudioVersionRecord } from "@/lib/studio";

export interface InstanceSummary extends StudioVersionRecord {
  modloader: ModLoaderInstalled | null;
  modsTotal: number;
  modsEnabled: number;
}

export async function listInstances() {
  return invoke<InstanceSummary[]>("list_instances");
}
