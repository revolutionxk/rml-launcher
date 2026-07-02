import { Plus } from "lucide-react";
import { useState } from "react";

import { FlagValueEditor } from "@/components/flag-value-editor";
import { Button } from "@/components/ui/button";
import { Card } from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { useI18n } from "@/i18n";
import {
  FLAG_TYPE_COLORS,
  FLAG_TYPE_HINTS,
  FLAG_TYPE_LABELS,
  defaultValueForType,
  detectFlagType,
} from "@/lib/fast-flags";
import { cn } from "@/lib/utils";

interface AddFlagPanelProps {
  existingNames: Set<string>;
  onAdd: (name: string, value: string) => void;
  onClose: () => void;
}

export function AddFlagPanel({ existingNames, onAdd, onClose }: AddFlagPanelProps) {
  const { t } = useI18n();
  const [name, setName] = useState("");
  const [value, setValue] = useState("");

  const trimmedName = name.trim();
  const detectedType = trimmedName ? detectFlagType(trimmedName, value) : null;
  const alreadyExists = existingNames.has(trimmedName);

  const handleNameChange = (newName: string) => {
    setName(newName);

    const type = detectFlagType(newName.trim(), value);
    if (type === "boolean" && value !== "true" && value !== "false") setValue("false");
    else if (type === "integer" && !/^-?\d+$/.test(value.trim())) setValue("0");
  };

  const handleAdd = () => {
    if (!trimmedName || alreadyExists) return;
    const type = detectFlagType(trimmedName, value);
    onAdd(trimmedName, value !== "" ? value : defaultValueForType(type));
    setName("");
    setValue("");
    onClose();
  };

  return (
    <Card.Root className="mb-3">
      <Card.Body>
        <div className="flex flex-col gap-3">
          <div>
            <div className="flex items-center gap-2 mb-1.5">
              <label className="text-[11px] font-medium text-text-muted">
                {t("engine-add-panel-name")}
              </label>
              {detectedType && (
                <span
                  className={cn(
                    "text-[10px] font-semibold px-1.5 py-0.5 rounded-sm leading-none",
                    FLAG_TYPE_COLORS[detectedType],
                  )}
                >
                  {FLAG_TYPE_LABELS[detectedType]}
                </span>
              )}
              {alreadyExists && (
                <span className="text-[10px] text-red ml-auto">
                  {t("engine-add-panel-duplicate")}
                </span>
              )}
            </div>
            <Input.Field
              value={name}
              onChange={(e) => handleNameChange(e.target.value)}
              placeholder={t("engine-add-panel-name-placeholder")}
              className={cn("font-code text-[12px]", alreadyExists && "border-red! ring-red/20!")}
              spellCheck={false}
              autoFocus
              onKeyDown={(e) => {
                if (e.key === "Escape") onClose();
                if (e.key === "Enter" && !alreadyExists) handleAdd();
              }}
            />
            {trimmedName && detectedType && !alreadyExists && (
              <p className="text-[10.5px] text-text-dim mt-1.5">{FLAG_TYPE_HINTS[detectedType]}</p>
            )}
          </div>

          {trimmedName && detectedType && (
            <div>
              <label className="text-[11px] font-medium text-text-muted mb-1.5 block">
                {t("engine-add-panel-value")}
              </label>
              <FlagValueEditor name={name} value={value} onChange={setValue} />
            </div>
          )}

          <div className="flex gap-2">
            <Button.Root
              variant="primary"
              onClick={handleAdd}
              disabled={!trimmedName || alreadyExists}
            >
              <Button.Icon>
                <Plus size={12} />
              </Button.Icon>
              <Button.Label>{t("engine-add-panel-submit")}</Button.Label>
            </Button.Root>
            <Button.Root variant="ghost" onClick={onClose}>
              <Button.Label>{t("common-cancel")}</Button.Label>
            </Button.Root>
          </div>
        </div>
      </Card.Body>
    </Card.Root>
  );
}

AddFlagPanel.displayName = "AddFlagPanel";
