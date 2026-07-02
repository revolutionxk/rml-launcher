import { Select as BaseSelect } from "@base-ui/react/select";
import { Check, ChevronDown, ChevronUp } from "lucide-react";
import { type ReactNode } from "react";

import { cn } from "@/lib/utils";

function SelectRoot(props: BaseSelect.Root.Props<string>) {
  return <BaseSelect.Root {...props} />;
}
SelectRoot.displayName = "Select.Root";

function SelectLabel({ children, className }: { children: ReactNode; className?: string }) {
  return (
    <BaseSelect.Label
      className={cn("text-[12px] font-medium text-text-muted mb-1.5 block", className)}
    >
      {children}
    </BaseSelect.Label>
  );
}
SelectLabel.displayName = "Select.Label";

function SelectTrigger({
  className,
  children,
  ...props
}: BaseSelect.Trigger.Props & { className?: string; children?: ReactNode }) {
  return (
    <BaseSelect.Trigger
      {...props}
      className={cn(
        "inline-flex items-center justify-between gap-2",
        "px-3 py-[7px] rounded-sm text-[13px]",
        "bg-surface border border-border text-text",
        "cursor-pointer transition-[border-color,background] duration-150",
        "hover:border-[#333] hover:bg-surface-2",
        "data-[popup-open]:border-border-focus",
        "outline-none focus-visible:border-border-focus focus-visible:ring-2 focus-visible:ring-accent/30",
        "disabled:opacity-45 disabled:cursor-not-allowed",
        "min-w-[120px]",
        className,
      )}
    >
      {children ?? <BaseSelect.Value />}
      <BaseSelect.Icon
        className={cn(
          "text-text-dim transition-transform duration-200",
          "data-[popup-open]:rotate-180",
        )}
      >
        <ChevronDown size={14} />
      </BaseSelect.Icon>
    </BaseSelect.Trigger>
  );
}
SelectTrigger.displayName = "Select.Trigger";

function SelectValue(props: BaseSelect.Value.Props) {
  return <BaseSelect.Value {...props} />;
}
SelectValue.displayName = "Select.Value";

function SelectPortal(props: BaseSelect.Portal.Props) {
  return <BaseSelect.Portal {...props} />;
}
SelectPortal.displayName = "Select.Portal";

function SelectPositioner({
  className,
  ...props
}: BaseSelect.Positioner.Props & { className?: string }) {
  return (
    <BaseSelect.Positioner
      sideOffset={4}
      alignItemWithTrigger={false}
      className={cn("z-50 outline-none", className)}
      {...props}
    />
  );
}
SelectPositioner.displayName = "Select.Positioner";

function SelectPopup({ children, className }: { children: ReactNode; className?: string }) {
  return (
    <BaseSelect.Popup
      className={cn(
        "bg-card border border-border rounded-sm py-1",
        "shadow-[0_8px_32px_rgba(0,0,0,0.4)] outline-none",
        "min-w-[var(--anchor-width)] max-h-[var(--available-height)]",
        "select-popup",
        className,
      )}
    >
      {children}
    </BaseSelect.Popup>
  );
}
SelectPopup.displayName = "Select.Popup";

function SelectList({ children, className }: { children: ReactNode; className?: string }) {
  return (
    <BaseSelect.List className={cn("overflow-y-auto max-h-[240px]", className)}>
      {children}
    </BaseSelect.List>
  );
}
SelectList.displayName = "Select.List";

function SelectScrollUpArrow({ className }: { className?: string }) {
  return (
    <BaseSelect.ScrollUpArrow
      className={cn(
        "flex items-center justify-center h-5 text-text-muted",
        "data-[visible]:opacity-100 opacity-0 transition-opacity",
        className,
      )}
    >
      <ChevronUp size={12} />
    </BaseSelect.ScrollUpArrow>
  );
}

function SelectScrollDownArrow({ className }: { className?: string }) {
  return (
    <BaseSelect.ScrollDownArrow
      className={cn(
        "flex items-center justify-center h-5 text-text-muted",
        "data-[visible]:opacity-100 opacity-0 transition-opacity",
        className,
      )}
    >
      <ChevronDown size={12} />
    </BaseSelect.ScrollDownArrow>
  );
}

interface SelectItemProps {
  value: string;
  disabled?: boolean;
  children: ReactNode;
  className?: string;
}

function SelectItem({ value, disabled, children, className }: SelectItemProps) {
  return (
    <BaseSelect.Item
      value={value}
      disabled={disabled}
      className={cn(
        "flex items-center gap-2 px-3 py-[7px] mx-1 rounded-sm",
        "text-[12.5px] text-text cursor-pointer outline-none",
        "transition-[background] duration-100",
        "data-[highlighted]:bg-surface-2",
        "data-[selected]:text-accent",
        "data-[disabled]:opacity-45 data-[disabled]:cursor-not-allowed",
        className,
      )}
    >
      <BaseSelect.ItemIndicator
        className="w-4 shrink-0 flex items-center justify-center data-[hidden]:invisible"
        keepMounted
      >
        <Check size={11} />
      </BaseSelect.ItemIndicator>
      <BaseSelect.ItemText>{children}</BaseSelect.ItemText>
    </BaseSelect.Item>
  );
}
SelectItem.displayName = "Select.Item";

function SelectSeparator({ className }: { className?: string }) {
  return (
    <BaseSelect.Separator className={cn("h-px bg-border-subtle my-1 mx-2", className)} />
  );
}
SelectSeparator.displayName = "Select.Separator";

export const Select = {
  Root: SelectRoot,
  Label: SelectLabel,
  Trigger: SelectTrigger,
  Value: SelectValue,
  Portal: SelectPortal,
  Positioner: SelectPositioner,
  Popup: SelectPopup,
  List: SelectList,
  ScrollUpArrow: SelectScrollUpArrow,
  ScrollDownArrow: SelectScrollDownArrow,
  Item: SelectItem,
  Separator: SelectSeparator,
};
