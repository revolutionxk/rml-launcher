import { TagEditor } from "@/components/ui/tag-editor";
import { Input } from "@/components/ui/input";
import Toggle from "@/components/toggle";
import { detectFlagType } from "@/lib/fast-flags";
import { cn } from "@/lib/utils";

interface FlagValueEditorProps {
  name: string;
  value: string;
  onChange: (value: string) => void;
}

export function FlagValueEditor({ name, value, onChange }: FlagValueEditorProps) {
  const type = detectFlagType(name, value);

  if (type === "boolean") {
    return (
      <Toggle
        checked={value === "true"}
        onChange={(checked) => onChange(checked ? "true" : "false")}
      />
    );
  }

  if (type === "integer") {
    return (
      <input
        type="number"
        value={value}
        onChange={(e) => onChange(e.target.value)}
        className={cn(
          "w-28 text-right bg-surface border border-border rounded-sm",
          "text-[12px] font-code text-text px-2.5 py-[7px]",
          "outline-none transition-[border-color,box-shadow] duration-200",
          "focus:border-border-focus focus:ring-2 focus:ring-accent/20",
          "[appearance:textfield]",
          "[&::-webkit-inner-spin-button]:appearance-none",
          "[&::-webkit-outer-spin-button]:appearance-none",
        )}
        spellCheck={false}
      />
    );
  }

  if (type === "list") {
    return <TagEditor value={value} onChange={onChange} />;
  }

  return (
    <Input.Field
      value={value}
      onChange={(e) => onChange(e.target.value)}
      className="text-[12px] font-code w-full"
      spellCheck={false}
    />
  );
}

FlagValueEditor.displayName = "FlagValueEditor";
