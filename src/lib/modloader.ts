import { invoke } from "@tauri-apps/api/core";

export type ModLoaderChannel =
  | "stable"
  | "beta"
  | "nightly"
  | "experimental"
  | "prerelease";

export type ModLoaderPhase =
  | "resolving"
  | "downloading"
  | "applying"
  | "finalizing"
  | "completed"
  | "failed";

export interface ModLoaderAsset {
  name: string;
  size: number;
  downloadUrl: string;
  sha256: string | null;
  updatedAt: string;
}

export interface ModLoaderRelease {
  tag: string;
  name: string;
  channel: ModLoaderChannel;
  prerelease: boolean;
  publishedAt: string | null;
  htmlUrl: string;
  notes: string | null;
  asset: ModLoaderAsset;
  isInstalled: boolean;
  updateAvailable: boolean;
}

export interface ModLoaderInstalled {
  installationId: string;
  tag: string;
  name: string;
  channel: ModLoaderChannel;
  assetName: string;
  assetSize: number;
  assetSha256: string | null;
  assetUpdatedAt: string;
  installedAt: string;
  artifacts: string[];
}

export interface ModLoaderInstallProgress {
  installationId: string;
  tag: string;
  phase: ModLoaderPhase;
  downloadedBytes: number;
  totalBytes: number;
  progress: number;
  error: string | null;
}

export const MODLOADER_INSTALL_EVENT = "modloader-install-progress";

export async function listModLoaderReleases() {
  return invoke<ModLoaderRelease[]>("list_modloader_releases");
}

export async function getModLoaderStatus(installationId: string) {
  return invoke<ModLoaderInstalled | null>("get_modloader_status", { installationId });
}

export async function installModLoader(installationId: string, tag: string) {
  return invoke<ModLoaderInstalled>("install_modloader", { installationId, tag });
}

export async function uninstallModLoader(installationId: string) {
  return invoke<void>("uninstall_modloader", { installationId });
}

export function isModLoaderUpdateAvailable(
  installed: ModLoaderInstalled | null | undefined,
  release: ModLoaderRelease | null | undefined,
) {
  if (!installed || !release || installed.tag !== release.tag) {
    return false;
  }

  if (installed.assetSha256 && release.asset.sha256) {
    return installed.assetSha256.toLowerCase() !== release.asset.sha256.toLowerCase();
  }

  return installed.assetUpdatedAt !== release.asset.updatedAt;
}
