import { X } from "lucide-react";
import { useRef, useState } from "react";

interface TagEditorProps {
  value: string;
  onChange: (value: string) => void;
  placeholder?: string;
}

export function TagEditor({ value, onChange, placeholder }: TagEditorProps) {
  const tags = value ? value.split(";").filter(Boolean) : [];
  const [input, setInput] = useState("");
  const inputRef = useRef<HTMLInputElement>(null);

  const commit = () => {
    const trimmed = input.trim();
    if (!trimmed || tags.includes(trimmed)) {
      setInput("");
      return;
    }
    onChange([...tags, trimmed].join(";"));
    setInput("");
  };

  const removeTag = (idx: number) => {
    onChange(
      tags
        .filter((_, i) => i !== idx)
        .join(";"),
    );
  };

  return (
    <div
      className="flex flex-wrap gap-1.5 items-center min-h-[32px] px-2 py-1.5 bg-surface border border-border rounded-sm focus-within:border-border-focus focus-within:ring-2 focus-within:ring-accent/20 transition-[border-color,box-shadow] duration-200 cursor-text w-full"
      onClick={() => inputRef.current?.focus()}
    >
      {tags.map((tag, i) => (
        <span
          key={i}
          className="inline-flex items-center gap-1 px-1.5 py-0.5 bg-surface-2 border border-border rounded-sm text-[11px] font-code text-text leading-none shrink-0"
        >
          {tag}
          <button
            type="button"
            onClick={(e) => {
              e.stopPropagation();
              removeTag(i);
            }}
            className="text-text-dim hover:text-red transition-colors cursor-pointer ml-0.5"
          >
            <X size={9} />
          </button>
        </span>
      ))}
      <input
        ref={inputRef}
        value={input}
        onChange={(e) => setInput(e.target.value)}
        onKeyDown={(e) => {
          if (e.key === "Enter" || e.key === ";") {
            e.preventDefault();
            commit();
          } else if (e.key === "Backspace" && !input && tags.length > 0) {
            removeTag(tags.length - 1);
          }
        }}
        onBlur={commit}
        placeholder={tags.length === 0 ? (placeholder ?? "Add value, press Enter or ;") : ""}
        className="bg-transparent outline-none text-[12px] font-code text-text placeholder:text-text-dim min-w-[140px] flex-1"
        spellCheck={false}
      />
    </div>
  );
}

TagEditor.displayName = "TagEditor";
