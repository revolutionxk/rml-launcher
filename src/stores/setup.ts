import { create } from "zustand";
import { persist } from "zustand/middleware";

interface SetupStore {
  loaderDeferred: boolean;
  deferLoader: () => void;
  resumeLoaderSetup: () => void;
  flagsIntroDismissed: boolean;
  dismissFlagsIntro: () => void;
  autoUpdateStudio: boolean;
  setAutoUpdateStudio: (value: boolean) => void;
  autoSetupDone: boolean;
  markAutoSetupDone: () => void;
}

export const useSetupStore = create<SetupStore>()(
  persist(
    (set) => ({
      loaderDeferred: false,
      deferLoader: () => set({ loaderDeferred: true }),
      resumeLoaderSetup: () => set({ loaderDeferred: false }),
      flagsIntroDismissed: false,
      dismissFlagsIntro: () => set({ flagsIntroDismissed: true }),
      autoUpdateStudio: true,
      setAutoUpdateStudio: (autoUpdateStudio) => set({ autoUpdateStudio }),
      autoSetupDone: false,
      markAutoSetupDone: () => set({ autoSetupDone: true }),
    }),
    {
      name: "rml-setup",
      partialize: ({ loaderDeferred, flagsIntroDismissed, autoUpdateStudio, autoSetupDone }) => ({
        loaderDeferred,
        flagsIntroDismissed,
        autoUpdateStudio,
        autoSetupDone,
      }),
    },
  ),
);
