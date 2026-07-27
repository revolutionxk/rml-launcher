import { listen } from "@tauri-apps/api/event";
import { getCurrentWindow, LogicalSize } from "@tauri-apps/api/window";
import { useEffect, useRef, useState } from "react";

import {
  BootstrapperView,
  installDetailLabel,
  installStatusLabel,
} from "@/components/bootstrapper";
import TitleBar from "@/components/title-bar";
import { useI18n } from "@/i18n";
import { getErrorMessage } from "@/lib/format";
import {
  installStudioVersion,
  launchStudio,
  listStudioVersions,
  type StudioInstallProgress,
  type StudioVersionRecord,
} from "@/lib/studio";
import { useSetupStore } from "@/stores/setup";

const STUDIO_INSTALL_EVENT = "studio-install-progress";
const COMPACT_SIZE = { width: 460, height: 340 };
const DEFAULT_SIZE = { width: 880, height: 540 };

type Stage = "checking" | "installing" | "launching" | "done" | "error";

interface BootstrapProps {
  uri: string | null;
  onExit: () => void;
}

export function Bootstrap({ uri, onExit }: BootstrapProps) {
  const { t } = useI18n();
  const autoUpdate = useSetupStore((state) => state.autoUpdateStudio);

  const [stage, setStage] = useState<Stage>("checking");
  const [install, setInstall] = useState<StudioInstallProgress | null>(null);
  const [error, setError] = useState<string | null>(null);
  const startedRef = useRef(false);

  useEffect(() => {
    const window = getCurrentWindow();
    void (async () => {
      await window.setMinSize(new LogicalSize(COMPACT_SIZE.width, COMPACT_SIZE.height));
      await window.setSize(new LogicalSize(COMPACT_SIZE.width, COMPACT_SIZE.height));
      await window.setResizable(false);
      await window.center();
    })().catch(console.error);

    return () => {
      const window = getCurrentWindow();
      void (async () => {
        await window.setResizable(true);
        await window.setMinSize(new LogicalSize(DEFAULT_SIZE.width, DEFAULT_SIZE.height));
        await window.setSize(new LogicalSize(DEFAULT_SIZE.width, DEFAULT_SIZE.height));
        await window.center();
      })().catch(console.error);
    };
  }, []);

  useEffect(() => {
    let disposed = false;
    const unlistenPromise = listen<StudioInstallProgress>(STUDIO_INSTALL_EVENT, ({ payload }) => {
      if (!disposed) {
        setInstall(payload);
      }
    });
    return () => {
      disposed = true;
      void unlistenPromise.then((unlisten) => unlisten());
    };
  }, []);

  useEffect(() => {
    if (startedRef.current) {
      return;
    }
    startedRef.current = true;

    const run = async () => {
      try {
        setStage("checking");
        const versions = await listStudioVersions();
        const installedDefault =
          versions.find((version) => version.isDefault && version.executablePath) ??
          versions.find((version) => version.isInstalled && version.executablePath) ??
          null;
        const latest = versions.find((version) => version.isLatest) ?? null;

        let target: StudioVersionRecord | null = installedDefault;

        if (autoUpdate && latest) {
          if (!latest.isInstalled) {
            setStage("installing");
            await installStudioVersion(latest);
          }
          target = latest;
        } else if (!target && latest) {
          setStage("installing");
          await installStudioVersion(latest);
          target = latest;
        }

        if (!target) {
          throw new Error(t("quick-error-no-studio"));
        }

        setStage("launching");
        await launchStudio(target.id, uri);
        setStage("done");
        window.setTimeout(onExit, 2000);
      } catch (caught) {
        setError(getErrorMessage(caught, t("quick-error-generic")));
        setStage("error");
      }
    };

    void run();
  }, [autoUpdate, uri, onExit, t]);

  const failed = stage === "error";
  const done = stage === "done";
  const activeInstall = stage === "installing" ? install : null;
  const percent = activeInstall ? activeInstall.progress : done ? 100 : 0;
  const indeterminate =
    !failed &&
    !done &&
    (stage === "checking" ||
      stage === "launching" ||
      (stage === "installing" && (!activeInstall || activeInstall.phase === "resolving")));

  const title = failed
    ? t("quick-failed-title")
    : done
      ? t("quick-done-title")
      : t("quick-title");

  const subtitle = (() => {
    if (failed) {
      return error ?? t("quick-error-generic");
    }
    switch (stage) {
      case "installing":
        return t("bootstrapper-version", { version: activeInstall?.version ?? "" });
      case "done":
        return t("quick-done-subtitle");
      default:
        return t("quick-subtitle");
    }
  })();

  const statusLabel = (() => {
    if (activeInstall) {
      return installStatusLabel(activeInstall, t);
    }
    if (stage === "checking") {
      return t("quick-checking");
    }
    if (stage === "launching") {
      return t("quick-launching");
    }
    return "";
  })();

  const detailLabel = activeInstall ? installDetailLabel(activeInstall, t) : "";

  return (
    <div className="flex h-screen flex-col overflow-hidden bg-bg">
      <TitleBar />
      <div className="relative flex-1 overflow-hidden">
        <BootstrapperView
          failed={failed}
          done={done}
          title={title}
          subtitle={subtitle}
          statusLabel={statusLabel}
          detailLabel={detailLabel}
          percent={percent}
          indeterminate={indeterminate}
          onClose={onExit}
          closeLabel={t("quick-close")}
        />
      </div>
    </div>
  );
}
