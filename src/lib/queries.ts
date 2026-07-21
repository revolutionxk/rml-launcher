import { useQuery } from "@tanstack/react-query";

import { getEngineState } from "@/lib/engine";
import { listInstances } from "@/lib/instances";
import { getModLoaderStatus, listModLoaderReleases } from "@/lib/modloader";
import { listMods } from "@/lib/mods";
import { getHostInfo, getVinegarStatus } from "@/lib/platform";
import { getStudioProtocolStatus } from "@/lib/protocol";
import { listStudioVersions } from "@/lib/studio";

export const queryKeys = {
  hostInfo: ["host-info"] as const,
  vinegarStatus: ["vinegar-status"] as const,
  instances: ["instances"] as const,
  studioVersions: ["studio-versions"] as const,
  modloaderReleases: ["modloader-releases"] as const,
  modloaderStatus: (installationId: string) => ["modloader-status", installationId] as const,
  mods: (installationId: string) => ["mods", installationId] as const,
  engineGeneralSettings: ["engine-general-settings"] as const,
  studioProtocol: ["studio-protocol"] as const,
};

export function useStudioProtocolStatus() {
  return useQuery({
    queryKey: queryKeys.studioProtocol,
    queryFn: getStudioProtocolStatus,
    staleTime: 60 * 1000,
  });
}

export function useEngineGeneralSettings() {
  return useQuery({
    queryKey: queryKeys.engineGeneralSettings,
    queryFn: getEngineState,
    staleTime: 5 * 60 * 1000,
    select: (state) => ({
      enableTracking: state.enableTracking,
      disableTelemetry: state.disableTelemetry,
    }),
  });
}

export function useHostInfo() {
  return useQuery({
    queryKey: queryKeys.hostInfo,
    queryFn: getHostInfo,
    staleTime: Infinity,
    gcTime: Infinity,
  });
}

export function useVinegarStatus(enabled: boolean) {
  return useQuery({
    queryKey: queryKeys.vinegarStatus,
    queryFn: getVinegarStatus,
    enabled,
  });
}

export function useInstances() {
  return useQuery({
    queryKey: queryKeys.instances,
    queryFn: listInstances,
  });
}

export function useStudioVersions() {
  return useQuery({
    queryKey: queryKeys.studioVersions,
    queryFn: listStudioVersions,
  });
}

export function useModLoaderReleases() {
  return useQuery({
    queryKey: queryKeys.modloaderReleases,
    queryFn: listModLoaderReleases,
    staleTime: 10 * 60 * 1000,
  });
}

export function useModLoaderStatus(installationId: string, enabled = true) {
  return useQuery({
    queryKey: queryKeys.modloaderStatus(installationId),
    queryFn: () => getModLoaderStatus(installationId),
    enabled,
  });
}

export function useMods(installationId: string) {
  return useQuery({
    queryKey: queryKeys.mods(installationId),
    queryFn: () => listMods(installationId),
  });
}
