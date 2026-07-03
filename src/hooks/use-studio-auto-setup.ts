import { useQueryClient } from "@tanstack/react-query";
import { useEffect } from "react";

import { setStudioProtocolHandler } from "@/lib/protocol";
import { queryKeys, useHostInfo, useInstances } from "@/lib/queries";
import { createQuickLaunchShortcut } from "@/lib/startup";
import { useSetupStore } from "@/stores/setup";

export function useStudioAutoSetup() {
  const queryClient = useQueryClient();
  const { data: host } = useHostInfo();
  const { data: instances } = useInstances();
  const autoSetupDone = useSetupStore((state) => state.autoSetupDone);
  const markAutoSetupDone = useSetupStore((state) => state.markAutoSetupDone);

  useEffect(() => {
    if (autoSetupDone || host?.os !== "windows") {
      return;
    }
    if (!instances?.some((instance) => instance.executablePath)) {
      return;
    }

    let cancelled = false;

    void (async () => {
      try {
        const status = await setStudioProtocolHandler(true);
        queryClient.setQueryData(queryKeys.studioProtocol, status);
        void createQuickLaunchShortcut().catch(console.error);
        if (!cancelled) {
          markAutoSetupDone();
        }
      } catch (error) {
        console.error(error);
      }
    })();

    return () => {
      cancelled = true;
    };
  }, [host, instances, autoSetupDone, markAutoSetupDone, queryClient]);
}
