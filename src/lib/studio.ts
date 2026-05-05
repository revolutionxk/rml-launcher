import { invoke } from "@tauri-apps/api/core";

export type StudioInstallPhase = "resolving" | "downloading" | "extracting" | "finalizing" | "completed" | "failed";

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

export async function setDefaultStudioVersion(versionGuid: string | null) {
  return invoke<void>("set_default_studio_version", { versionGuid });
}

export async function installStudioVersion(version: StudioVersionRecord) {
  return invoke<StudioVersionRecord>("install_studio_version", {
    versionGuid: version.versionGuid,
    version: version.version,
    channel: version.channel,
    publishedAt: version.publishedAt,
  });
}

export async function launchStudio(versionGuid: string) {
  return invoke<void>("launch_studio", { versionGuid });
}

export async function openStudioInstallDir(versionGuid: string) {
  return invoke<void>("open_studio_install_dir", { versionGuid });
}

export async function revalidateStudioVersion(versionGuid: string) {
  return invoke<StudioVersionRecord>("revalidate_studio_version", { versionGuid });
}

export async function uninstallStudio(versionGuid: string) {
  return invoke<void>("uninstall_studio", { versionGuid });
}