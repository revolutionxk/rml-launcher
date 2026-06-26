import { useQuery } from "@tanstack/react-query";

import { listInstances } from "@/lib/instances";
import { listModLoaderReleases } from "@/lib/modloader";
import { listMods } from "@/lib/mods";
import { getHostInfo, getVinegarStatus } from "@/lib/platform";
import { listStudioVersions } from "@/lib/studio";

export const queryKeys = {
  hostInfo: ["host-info"] as const,
  vinegarStatus: ["vinegar-status"] as const,
  instances: ["instances"] as const,
  studioVersions: ["studio-versions"] as const,
  modloaderReleases: ["modloader-releases"] as const,
  mods: (versionGuid: string) => ["mods", versionGuid] as const,
};

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

export function useMods(versionGuid: string) {
  return useQuery({
    queryKey: queryKeys.mods(versionGuid),
    queryFn: () => listMods(versionGuid),
  });
}
