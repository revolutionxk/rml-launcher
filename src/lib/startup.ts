import { invoke } from "@tauri-apps/api/core";

export interface StartupOptions {
  bootstrap: boolean;
  studioUri: string | null;
}

export async function getStartupOptions() {
  return invoke<StartupOptions>("get_startup_options");
}

export async function createQuickLaunchShortcut() {
  return invoke<void>("create_quick_launch_shortcut");
}
