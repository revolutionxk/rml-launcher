import type { ReactNode } from "react";

import { SettingRow as SettingRowCompound } from "@/components/ui/setting-row";

interface SettingRowProps {
  label: string;
  description?: string;
  children: ReactNode;
  disabled?: boolean;
}

export default function SettingRow({ label, description, children, disabled }: SettingRowProps) {
  return (
    <SettingRowCompound.Root disabled={disabled}>
      <SettingRowCompound.Text>
        <SettingRowCompound.Label>{label}</SettingRowCompound.Label>
        {description && (
          <SettingRowCompound.Description>{description}</SettingRowCompound.Description>
        )}
      </SettingRowCompound.Text>
      <SettingRowCompound.Control>{children}</SettingRowCompound.Control>
    </SettingRowCompound.Root>
  );
}
