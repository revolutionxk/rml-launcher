import { Toggle } from "@base-ui/react/toggle";
import { ToggleGroup } from "@base-ui/react/toggle-group";
import { type ReactNode } from "react";

import { cn } from "@/lib/utils";

interface SegmentGroupRootProps {
  value: string;
  onValueChange?: (value: string) => void;
  className?: string;
  children: ReactNode;
  disabled?: boolean;
}

function SegmentGroupRoot({
  value,
  onValueChange,
  className,
  children,
  disabled,
}: SegmentGroupRootProps) {
  return (
    <ToggleGroup
      value={[value]}
      onValueChange={(vals) => {
        const next = vals.find((v) => v !== value);
        if (next !== undefined) onValueChange?.(next);
      }}
      disabled={disabled}
      className={cn(
        "flex gap-1.5",
        className,
      )}
    >
      {children}
    </ToggleGroup>
  );
}
SegmentGroupRoot.displayName = "SegmentGroup.Root";

interface SegmentGroupItemProps {
  value: string;
  disabled?: boolean;
  className?: string;
  children: ReactNode;
}

function SegmentGroupItem({ value, disabled, className, children }: SegmentGroupItemProps) {
  return (
    <Toggle
      value={value}
      disabled={disabled}
      className={cn(
        "relative flex-1 flex items-center justify-center gap-2",
        "py-2.5 rounded-sm text-[12.5px] font-medium",
        "cursor-pointer border transition-all duration-150 outline-none",
        "focus-visible:ring-2 focus-visible:ring-accent/40",
        "border-border bg-surface text-text-muted hover:border-text-dim hover:text-text",
        "data-[pressed]:border-accent data-[pressed]:bg-accent-muted data-[pressed]:text-accent data-[pressed]:font-semibold",
        className,
      )}
    >
      <span className="relative flex items-center justify-center gap-2 pointer-events-none">
        {children}
      </span>
    </Toggle>
  );
}
SegmentGroupItem.displayName = "SegmentGroup.Item";

export const SegmentGroup = {
  Root: SegmentGroupRoot,
  Item: SegmentGroupItem,
};
