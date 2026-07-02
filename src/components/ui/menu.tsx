import { Menu as BaseMenu } from "@base-ui/react/menu";
import { type ReactNode } from "react";

import { cn } from "@/lib/utils";

function MenuRoot(props: BaseMenu.Root.Props<unknown>) {
  return <BaseMenu.Root modal={false} {...props} />;
}
MenuRoot.displayName = "Menu.Root";

function MenuTrigger({ children, className, render, ...props }: BaseMenu.Trigger.Props<unknown>) {
  return (
    <BaseMenu.Trigger className={cn("outline-none", className)} render={render} {...props}>
      {children}
    </BaseMenu.Trigger>
  );
}
MenuTrigger.displayName = "Menu.Trigger";

function MenuPortal(props: BaseMenu.Portal.Props) {
  return <BaseMenu.Portal {...props} />;
}
MenuPortal.displayName = "Menu.Portal";

function MenuPositioner({
  className,
  align = "end",
  sideOffset = 8,
  ...props
}: BaseMenu.Positioner.Props & { className?: string }) {
  return (
    <BaseMenu.Positioner
      align={align}
      sideOffset={sideOffset}
      className={cn("z-50", className)}
      {...props}
    />
  );
}
MenuPositioner.displayName = "Menu.Positioner";

function MenuPopup({
  children,
  className,
  ...props
}: BaseMenu.Popup.Props & { children?: ReactNode; className?: string }) {
  return (
    <BaseMenu.Popup
      className={cn(
        "min-w-[188px] overflow-hidden rounded-sm border border-border bg-[#101010] p-1.5",
        "shadow-[0_18px_40px_rgba(0,0,0,0.42)] backdrop-blur-sm",
        className,
      )}
      {...props}
    >
      {children}
    </BaseMenu.Popup>
  );
}
MenuPopup.displayName = "Menu.Popup";

function MenuItem({
  children,
  className,
  ...props
}: BaseMenu.Item.Props & { children?: ReactNode; className?: string }) {
  return (
    <BaseMenu.Item
      className={cn(
        "flex cursor-default select-none items-center gap-2 rounded-sm px-2.5 py-2 text-[12px] font-medium text-text-muted outline-none",
        "transition-[background,color,opacity] duration-150 data-[highlighted]:bg-surface-2 data-[highlighted]:text-text",
        "data-[disabled]:pointer-events-none data-[disabled]:opacity-45",
        className,
      )}
      {...props}
    >
      {children}
    </BaseMenu.Item>
  );
}
MenuItem.displayName = "Menu.Item";

export const Menu = {
  Root: MenuRoot,
  Trigger: MenuTrigger,
  Portal: MenuPortal,
  Positioner: MenuPositioner,
  Popup: MenuPopup,
  Item: MenuItem,
};
