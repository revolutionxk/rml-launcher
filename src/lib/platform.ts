import { invoke } from "@tauri-apps/api/core";

export type HostOs = "windows" | "macos" | "linux";

export interface HostInfo {
  os: HostOs;
  nativeStudio: boolean;
  vinegarAvailable: boolean;
}

export async function getHostInfo() {
  return invoke<HostInfo>("get_host_info");
}

export type VinegarKind = "binary" | "flatpak" | "none";

export interface VinegarStatus {
  installed: boolean;
  kind: VinegarKind;
  flatpakAvailable: boolean;
}

export async function getVinegarStatus() {
  return invoke<VinegarStatus>("vinegar_status");
}

export async function installVinegar() {
  return invoke<void>("install_vinegar");
}

export async function launchVinegar() {
  return invoke<void>("launch_vinegar");
}
