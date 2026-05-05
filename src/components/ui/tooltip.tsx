import { Tooltip as BaseTooltip } from "@base-ui/react/tooltip";
import { type ReactNode } from "react";

import { cn } from "@/lib/utils";

function TooltipProvider({
  delay = 600,
  children,
}: {
  delay?: number;
  children: ReactNode;
}) {
  return <BaseTooltip.Provider delay={delay}>{children}</BaseTooltip.Provider>;
}
TooltipProvider.displayName = "Tooltip.Provider";

function TooltipRoot(props: BaseTooltip.Root.Props) {
  return <BaseTooltip.Root {...props} />;
}
TooltipRoot.displayName = "Tooltip.Root";

function TooltipTrigger({
  children,
  className,
  render,
  ...props
}: BaseTooltip.Trigger.Props) {
  return (
    <BaseTooltip.Trigger
      className={cn("outline-none", className)}
      render={render}
      {...props}
    >
      {children}
    </BaseTooltip.Trigger>
  );
}
TooltipTrigger.displayName = "Tooltip.Trigger";

function TooltipPortal(props: BaseTooltip.Portal.Props) {
  return <BaseTooltip.Portal {...props} />;
}

function TooltipPositioner({
  className,
  sideOffset = 6,
  ...props
}: BaseTooltip.Positioner.Props & { className?: string }) {
  return (
    <BaseTooltip.Positioner sideOffset={sideOffset} className={cn("z-50", className)} {...props} />
  );
}
TooltipPositioner.displayName = "Tooltip.Positioner";

function TooltipPopup({ children, className }: { children?: ReactNode; className?: string }) {
  return (
    <BaseTooltip.Popup
      className={cn(
        "px-2.5 py-1.5 rounded-sm text-[11.5px] font-medium text-white",
        "bg-[#1a1a1a] border border-border",
        "shadow-[0_4px_16px_rgba(0,0,0,0.4)]",
        "tooltip-popup",
        className,
      )}
    >
      {children}
    </BaseTooltip.Popup>
  );
}
TooltipPopup.displayName = "Tooltip.Popup";

export const Tooltip = {
  Provider: TooltipProvider,
  Root: TooltipRoot,
  Trigger: TooltipTrigger,
  Portal: TooltipPortal,
  Positioner: TooltipPositioner,
  Popup: TooltipPopup,
};
