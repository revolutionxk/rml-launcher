import { type ReactNode } from "react";

import { cn } from "@/lib/utils";

interface SettingRowRootProps {
  children: ReactNode;
  disabled?: boolean;
  className?: string;
}

function SettingRowRoot({ children, disabled, className }: SettingRowRootProps) {
  return (
    <div
      className={cn(
        "setting-row flex items-center justify-between gap-4 px-[18px] py-[15px]",
        "transition-[background] duration-150 hover:bg-white/[0.02]",
        disabled && "opacity-50 pointer-events-none",
        className,
      )}
    >
      {children}
    </div>
  );
}
SettingRowRoot.displayName = "SettingRow.Root";

function SettingRowText({ children, className }: { children: ReactNode; className?: string }) {
  return <div className={cn("flex-1 min-w-0", className)}>{children}</div>;
}
SettingRowText.displayName = "SettingRow.Text";

function SettingRowLabel({ children, className }: { children: ReactNode; className?: string }) {
  return (
    <div className={cn("text-[13px] font-medium text-text leading-[1.3]", className)}>
      {children}
    </div>
  );
}
SettingRowLabel.displayName = "SettingRow.Label";

function SettingRowDescription({
  children,
  className,
}: {
  children: ReactNode;
  className?: string;
}) {
  return (
    <div className={cn("text-[11.5px] text-text-muted mt-0.5 leading-[1.5]", className)}>
      {children}
    </div>
  );
}
SettingRowDescription.displayName = "SettingRow.Description";

function SettingRowControl({ children, className }: { children: ReactNode; className?: string }) {
  return <div className={cn("shrink-0", className)}>{children}</div>;
}
SettingRowControl.displayName = "SettingRow.Control";

export const SettingRow = {
  Root: SettingRowRoot,
  Text: SettingRowText,
  Label: SettingRowLabel,
  Description: SettingRowDescription,
  Control: SettingRowControl,
};
