import { getCurrentWindow } from "@tauri-apps/api/window";
import { useEffect, useMemo, useState } from "react";

import { useI18n } from "@/i18n";

interface ControlsProps {
  onMinimize: () => void;
  onMaximize: () => void;
  onClose: () => void;
  isMaximized?: boolean;
}

function WindowsControls({ onMinimize, onMaximize, onClose, isMaximized }: ControlsProps) {
  const { t } = useI18n();

  return (
    <div className="flex h-full items-stretch [-webkit-app-region:no-drag]">
      <button
        type="button"
        aria-label={t("titlebar-minimize")}
        onClick={onMinimize}
        className="flex w-[46px] items-center justify-center text-zinc-400 transition-colors duration-100 hover:bg-white/[0.08] hover:text-zinc-100"
      >
        <svg width="10" height="10" viewBox="0 0 10 10" fill="currentColor" aria-hidden="true">
          <rect y="4.5" width="10" height="1" rx="0.5" />
        </svg>
      </button>

      <button
        type="button"
        aria-label={isMaximized ? t("titlebar-restore") : t("titlebar-maximize")}
        onClick={onMaximize}
        className="flex w-[46px] items-center justify-center text-zinc-400 transition-colors duration-100 hover:bg-white/[0.08] hover:text-zinc-100"
      >
        {isMaximized ? (
          <svg
            width="10"
            height="10"
            viewBox="0 0 10 10"
            fill="none"
            stroke="currentColor"
            strokeWidth="1"
            strokeLinecap="square"
            strokeLinejoin="miter"
            aria-hidden="true"
          >
            <path d="M3.5 0.5H9.5V6.5" />
            <rect x="0.5" y="3.5" width="6" height="6" />
          </svg>
        ) : (
          <svg
            width="10"
            height="10"
            viewBox="0 0 10 10"
            fill="none"
            stroke="currentColor"
            strokeWidth="1"
            aria-hidden="true"
          >
            <rect x="0.5" y="0.5" width="9" height="9" rx="0.5" />
          </svg>
        )}
      </button>

      <button
        type="button"
        aria-label={t("titlebar-close")}
        onClick={onClose}
        className="flex w-[46px] items-center justify-center text-zinc-400 transition-colors duration-100 hover:bg-[#C42B1C] hover:text-white"
      >
        <svg
          width="10"
          height="10"
          viewBox="0 0 10 10"
          fill="none"
          stroke="currentColor"
          strokeWidth="1"
          strokeLinecap="round"
          aria-hidden="true"
        >
          <path d="M1 1L9 9M9 1L1 9" />
        </svg>
      </button>
    </div>
  );
}

function LinuxControls({ onMinimize, onMaximize, onClose, isMaximized }: ControlsProps) {
  const { t } = useI18n();

  return (
    <div className="flex items-center gap-1.5 pr-3 [-webkit-app-region:no-drag]">
      <button
        type="button"
        aria-label={t("titlebar-minimize")}
        onClick={onMinimize}
        className="group flex size-[22px] items-center justify-center rounded-full bg-white/[0.07] transition-colors duration-150 hover:bg-white/[0.13]"
      >
        <svg
          width="8"
          height="8"
          viewBox="0 0 8 8"
          fill="none"
          stroke="currentColor"
          strokeWidth="1.5"
          strokeLinecap="round"
          className="text-zinc-400 transition-colors group-hover:text-zinc-100"
          aria-hidden="true"
        >
          <line x1="1" y1="4" x2="7" y2="4" />
        </svg>
      </button>

      <button
        type="button"
        aria-label={isMaximized ? t("titlebar-restore") : t("titlebar-maximize")}
        onClick={onMaximize}
        className="group flex size-[22px] items-center justify-center rounded-full bg-white/[0.07] transition-colors duration-150 hover:bg-white/[0.13]"
      >
        {isMaximized ? (
          <svg
            width="9"
            height="9"
            viewBox="0 0 9 9"
            fill="none"
            stroke="currentColor"
            strokeWidth="1.2"
            strokeLinecap="round"
            strokeLinejoin="round"
            className="text-zinc-400 transition-colors group-hover:text-zinc-100"
            aria-hidden="true"
          >
            <path d="M3.5 0.5H8.5V5.5M0.5 3.5H5.5V8.5H0.5V3.5Z" />
          </svg>
        ) : (
          <svg
            width="8"
            height="8"
            viewBox="0 0 8 8"
            fill="none"
            stroke="currentColor"
            strokeWidth="1.2"
            strokeLinecap="round"
            strokeLinejoin="round"
            className="text-zinc-400 transition-colors group-hover:text-zinc-100"
            aria-hidden="true"
          >
            <rect x="0.6" y="0.6" width="6.8" height="6.8" rx="0.6" />
          </svg>
        )}
      </button>

      <button
        type="button"
        aria-label={t("titlebar-close")}
        onClick={onClose}
        className="group flex size-[22px] items-center justify-center rounded-full bg-white/[0.07] transition-colors duration-150 hover:bg-rose-500/75"
      >
        <svg
          width="8"
          height="8"
          viewBox="0 0 8 8"
          fill="none"
          stroke="currentColor"
          strokeWidth="1.5"
          strokeLinecap="round"
          className="text-zinc-400 transition-colors group-hover:text-white"
          aria-hidden="true"
        >
          <path d="M1 1L7 7M7 1L1 7" />
        </svg>
      </button>
    </div>
  );
}

export function WindowControls() {
  const win = useMemo(() => getCurrentWindow(), []);
  const [isMaximized, setIsMaximized] = useState(false);

  useEffect(() => {
    let unlistenResized: (() => void) | undefined;

    void win.isMaximized().then(setIsMaximized);
    void win
      .onResized(async () => setIsMaximized(await win.isMaximized()))
      .then((fn) => {
        unlistenResized = fn;
      });

    return () => {
      unlistenResized?.();
    };
  }, [win]);

  const props: ControlsProps = {
    onMinimize: () => void win.minimize(),
    onMaximize: () => void win.toggleMaximize(),
    onClose: () => void win.close(),
    isMaximized,
  };
  
  if (__PLATFORM__ === "darwin") return null;
  if (__PLATFORM__ === "windows") return <WindowsControls {...props} />;
  return <LinuxControls {...props} />;
}
