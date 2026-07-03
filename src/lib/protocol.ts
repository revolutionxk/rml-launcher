import { invoke } from "@tauri-apps/api/core";

export interface StudioProtocolStatus {
  supported: boolean;
  enabled: boolean;
}

export async function getStudioProtocolStatus() {
  return invoke<StudioProtocolStatus>("studio_protocol_status");
}

export async function setStudioProtocolHandler(enabled: boolean) {
  return invoke<StudioProtocolStatus>("set_studio_protocol_handler", { enabled });
}
