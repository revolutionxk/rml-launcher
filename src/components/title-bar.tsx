import { getCurrentWindow } from "@tauri-apps/api/window";
import { useEffect, useState } from "react";

import Logo from "@/components/logo";
import { APP_NAME } from "@/constants/app";
import { useI18n } from "@/i18n";

function IconMinimize() {
  return (
    <svg width="10" height="1" viewBox="0 0 10 1" aria-hidden="true">
      <rect width="10" height="1" fill="currentColor" />
    </svg>
  );
}

function IconMaximize() {
  return (
    <svg width="10" height="10" viewBox="0 0 10 10" fill="none" aria-hidden="true">
      <rect x=".5" y=".5" width="9" height="9" stroke="currentColor" />
    </svg>
  );
}

function IconRestore() {
  return (
    <svg width="11" height="11" viewBox="0 0 11 11" fill="none" aria-hidden="true">
      <rect x="3.5" y=".5" width="7" height="7" stroke="currentColor" />
      <path d="M.5 3.5H3.5V10.5H10.5V7.5" stroke="currentColor" />
    </svg>
  );
}

function IconClose() {
  return (
    <svg width="10" height="10" viewBox="0 0 10 10" fill="none" aria-hidden="true">
      <path
        d="M0 0L10 10M10 0L0 10"
        stroke="currentColor"
        strokeWidth="1.2"
        strokeLinecap="round"
      />
    </svg>
  );
}

const win11BtnBase =
  "w-[46px] h-full flex items-center justify-center bg-transparent border-none text-text-muted cursor-default rounded-none [-webkit-app-region:no-drag] transition-[background,color] duration-[80ms] hover:text-text" +
  " [&:hover]:bg-[var(--win-btn-hover)] [&:active]:bg-[var(--win-btn-active)]";

function Win11Controls() {
  const win = getCurrentWindow();
  const { t } = useI18n();
  const [isMaximized, setIsMaximized] = useState(false);

  useEffect(() => {
    let unlisten: (() => void) | undefined;
    win.isMaximized().then(setIsMaximized);
    win
      .onResized(async () => setIsMaximized(await win.isMaximized()))
      .then((fn) => {
        unlisten = fn;
      });
    return () => {
      unlisten?.();
    };
  }, [win]);

  return (
    <div className="flex h-full items-center">
      <button
        type="button"
        className={win11BtnBase}
        onClick={() => win.minimize()}
        aria-label={t("titlebar-minimize")}
      >
        <IconMinimize />
      </button>
      <button
        type="button"
        className={win11BtnBase}
        onClick={() => win.toggleMaximize()}
        aria-label={isMaximized ? t("titlebar-restore") : t("titlebar-maximize")}
      >
        {isMaximized ? <IconRestore /> : <IconMaximize />}
      </button>
      <button
        type="button"
        className={`${win11BtnBase} hover:bg-[#c42b1c]! hover:text-white! active:bg-[#b52419]!`}
        onClick={() => win.close()}
        aria-label={t("titlebar-close")}
      >
        <IconClose />
      </button>
    </div>
  );
}

function LinuxControls() {
  const win = getCurrentWindow();
  const { t } = useI18n();
  const [isMaximized, setIsMaximized] = useState(false);

  useEffect(() => {
    let unlisten: (() => void) | undefined;
    win.isMaximized().then(setIsMaximized);
    win
      .onResized(async () => setIsMaximized(await win.isMaximized()))
      .then((fn) => {
        unlisten = fn;
      });
    return () => {
      unlisten?.();
    };
  }, [win]);

  const linuxBtnBase =
    "w-7 h-7 flex items-center justify-center rounded-full border text-text-muted cursor-default [-webkit-app-region:no-drag] transition-[background,color,border-color] duration-100 hover:text-text" +
    " bg-[var(--linux-btn-bg)] border-[var(--linux-btn-border)] [&:hover]:bg-[var(--linux-btn-hover)] [&:hover]:border-[var(--linux-btn-hover-border)] [&:active]:bg-[var(--linux-btn-active)]";

  return (
    <div className="flex h-full items-center gap-2 pr-3">
      <button
        type="button"
        className={linuxBtnBase}
        onClick={() => win.minimize()}
        aria-label={t("titlebar-minimize")}
      >
        <IconMinimize />
      </button>
      <button
        type="button"
        className={linuxBtnBase}
        onClick={() => win.toggleMaximize()}
        aria-label={isMaximized ? t("titlebar-restore") : t("titlebar-maximize")}
      >
        {isMaximized ? <IconRestore /> : <IconMaximize />}
      </button>
      <button
        type="button"
        className={`${linuxBtnBase} hover:bg-[#c0392b]! hover:border-[#e74c3c]! hover:text-white! active:bg-[#a93226]!`}
        onClick={() => win.close()}
        aria-label={t("titlebar-close")}
      >
        <IconClose />
      </button>
    </div>
  );
}

const titlebarBase =
  "h-[var(--titlebar-h)] flex items-center justify-between pl-[14px] shrink-0 border-b border-border-subtle bg-bg relative z-[100]";

export default function TitleBar() {
  if (__PLATFORM__ === "macos") {
    return (
      <div className={`${titlebarBase} justify-center! pl-0!`} data-tauri-drag-region>
        <div className="absolute inset-y-0 left-0 w-19" aria-hidden="true" />
        <span
          className="text-[12px] font-medium text-text-dim tracking-[0.01em] flex items-center gap-1"
          data-tauri-drag-region
        >
          {APP_NAME}
        </span>
      </div>
    );
  }

  if (__PLATFORM__ === "linux") {
    return (
      <div className={titlebarBase} data-tauri-drag-region>
        <span
          className="text-[12px] font-medium text-text-dim tracking-[0.01em] flex items-center gap-1"
          data-tauri-drag-region
        >
          {APP_NAME}
        </span>
        <LinuxControls />
      </div>
    );
  }

  return (
    <div className={titlebarBase} data-tauri-drag-region>
      <span
        className="text-[12px] font-medium text-text-dim tracking-[0.01em] flex items-center gap-1"
        data-tauri-drag-region
      >
        <span className="mr-1">
          <Logo size={14} />
        </span>
        {APP_NAME}
      </span>
      <Win11Controls />
    </div>
  );
}
