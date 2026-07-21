import Logo from "@/components/logo";
import { WindowControls } from "@/components/window-controls";
import { APP_NAME } from "@/constants/app";

const titlebarBase =
  "h-[var(--titlebar-h)] flex items-center justify-between shrink-0 border-b border-border-subtle bg-bg relative z-[100]";

const titleText = "text-[12px] font-medium text-text-dim tracking-[0.01em] flex items-center gap-1";

export default function TitleBar() {
  if (__PLATFORM__ === "darwin") {
    return (
      <div className={`${titlebarBase} pl-20`} data-tauri-drag-region>
        <span className={`${titleText} absolute left-1/2 -translate-x-1/2`} data-tauri-drag-region>
          {APP_NAME}
        </span>
      </div>
    );
  }

  return (
    <div className={`${titlebarBase} pl-3.5`} data-tauri-drag-region>
      <span className={titleText} data-tauri-drag-region>
        {__PLATFORM__ === "windows" && (
          <span className="mr-1">
            <Logo size={14} />
          </span>
        )}
        {APP_NAME}
      </span>
      <WindowControls />
    </div>
  );
}
