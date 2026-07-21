import { invoke } from "@tauri-apps/api/core";

export type StudioInstallPhase = "resolving" | "downloading" | "extracting" | "finalizing" | "completed" | "failed";

export type InstallationSource = "managed" | "robloxOfficial" | "bloxstrap" | "macBundle" | "vinegar";

export const Capability = {
  Launch: 1 << 0,
  Mods: 1 << 1,
  EngineFlags: 1 << 2,
  Uninstall: 1 << 3,
  Revalidate: 1 << 4,
} as const;

export function can(record: { capabilities: number }, capability: number) {
  return (record.capabilities & capability) === capability;
}

export interface StudioVersionRecord {
  id: string;
  versionGuid: string;
  version: string;
  channel: string;
  installedAt: string | null;
  publishedAt: string | null;
  integrityVerifiedAt: string | null;
  isDefault: boolean;
  isLatest: boolean;
  isInstalled: boolean;
  source: InstallationSource;
  capabilities: number;
  executablePath: string | null;
  installDir: string | null;
}

export interface StudioInstallProgress {
  versionGuid: string;
  version: string;
  channel: string;
  phase: StudioInstallPhase;
  currentPackage: string | null;
  downloadedBytes: number;
  totalDownloadBytes: number;
  extractedPackages: number;
  totalPackages: number;
  progress: number;
  error: string | null;
}

interface StudioVersionsResponse {
  versions: StudioVersionRecord[];
}

export async function listStudioVersions() {
  const response = await invoke<StudioVersionsResponse>("list_studio_versions");
  return response.versions;
}

export async function installLatestStudio() {
  return invoke<StudioVersionRecord>("install_latest_studio");
}

export async function setDefaultStudioVersion(installationId: string | null) {
  return invoke<void>("set_default_studio_version", { installationId });
}

export async function installStudioVersion(version: StudioVersionRecord) {
  return invoke<StudioVersionRecord>("install_studio_version", {
    versionGuid: version.versionGuid,
    version: version.version,
    channel: version.channel,
    publishedAt: version.publishedAt,
  });
}

export async function launchStudio(installationId: string, uri?: string | null) {
  return invoke<void>("launch_studio", { installationId, uri: uri ?? null });
}

export async function openStudioInstallDir(installationId: string) {
  return invoke<void>("open_studio_install_dir", { installationId });
}

export async function revalidateStudioVersion(installationId: string) {
  return invoke<StudioVersionRecord>("revalidate_studio_version", { installationId });
}

export async function uninstallStudio(installationId: string) {
  return invoke<void>("uninstall_studio", { installationId });
}