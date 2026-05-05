import type { ReactNode } from "react";

import { ActionButton as ActionButtonCompound } from "@/components/ui/action-button";

interface ActionButtonProps {
  icon: ReactNode;
  iconClass?: string;
  label: string;
  description?: string;
  onClick: () => void;
  disabled?: boolean;
}

export default function ActionButton({
  icon,
  iconClass = "icon-box--blue",
  label,
  description,
  onClick,
  disabled,
}: ActionButtonProps) {
  return (
    <ActionButtonCompound.Root onClick={onClick} disabled={disabled}>
      <ActionButtonCompound.Icon className={iconClass}>{icon}</ActionButtonCompound.Icon>
      <ActionButtonCompound.Content>
        <ActionButtonCompound.Label>{label}</ActionButtonCompound.Label>
        {description && (
          <ActionButtonCompound.Description>{description}</ActionButtonCompound.Description>
        )}
      </ActionButtonCompound.Content>
      <ActionButtonCompound.Arrow />
    </ActionButtonCompound.Root>
  );
}
