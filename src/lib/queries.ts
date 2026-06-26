import { useQuery } from "@tanstack/react-query";

import { listInstances } from "@/lib/instances";
import { listModLoaderReleases } from "@/lib/modloader";
import { listMods } from "@/lib/mods";
import { listStudioVersions } from "@/lib/studio";

export const queryKeys = {
  instances: ["instances"] as const,
  studioVersions: ["studio-versions"] as const,
  modloaderReleases: ["modloader-releases"] as const,
  mods: (versionGuid: string) => ["mods", versionGuid] as const,
};

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
