import { createFileRoute } from "@tanstack/react-router";
import { FolderOpen, Plus, Puzzle, Trash2 } from "lucide-react";
import { AnimatePresence, motion } from "motion/react";
import { useState } from "react";

import Toggle from "@/components/toggle";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Card } from "@/components/ui/card";
import { Tooltip } from "@/components/ui/tooltip";
import { useI18n } from "@/i18n";

export const Route = createFileRoute("/settings/mods")({
  component: ModsPage,
});

interface Mod {
  id: string;
  nameId: string;
  descriptionId: string;
  size: string;
  enabled: boolean;
  type: "texture" | "sound" | "script" | "other";
}

const TYPE_LABELS: Record<Mod["type"], string> = {
  texture: "mods-type-texture",
  sound: "mods-type-sound",
  script: "mods-type-script",
  other: "mods-type-other",
};

const TYPE_VARIANTS: Record<Mod["type"], "blue" | "purple" | "yellow" | "gray"> = {
  texture: "blue",
  sound: "purple",
  script: "yellow",
  other: "gray",
};

const MOCK_MODS: Mod[] = [
  {
    id: "1",
    nameId: "mods-item-terrain-name",
    descriptionId: "mods-item-terrain-description",
    size: "14.2 MB",
    enabled: true,
    type: "texture",
  },
  {
    id: "2",
    nameId: "mods-item-sounds-name",
    descriptionId: "mods-item-sounds-description",
    size: "3.8 MB",
    enabled: false,
    type: "sound",
  },
  {
    id: "3",
    nameId: "mods-item-icons-name",
    descriptionId: "mods-item-icons-description",
    size: "0.9 MB",
    enabled: true,
    type: "texture",
  },
];

function ModsPage() {
  const { t } = useI18n();
  const [mods, setMods] = useState<Mod[]>(MOCK_MODS);

  const toggle = (id: string) => {
    setMods((m) => m.map((mod) => (mod.id === id ? { ...mod, enabled: !mod.enabled } : mod)));
  };

  const remove = (id: string) => {
    setMods((m) => m.filter((mod) => mod.id !== id));
  };

  return (
    <Tooltip.Provider>
      <div>
        <div className="mb-5">
          <h1 className="text-[18px] font-semibold text-text tracking-[-0.018em] leading-[1.25]">
            {t("mods-title")}
          </h1>
          <p className="text-[12.5px] text-text-muted mt-1 leading-normal">
            {t("mods-description")}
          </p>
        </div>

        <div className="flex gap-2 mb-4">
          <Button.Root variant="primary">
            <Button.Icon>
              <Plus size={13} />
            </Button.Icon>
            <Button.Label>{t("mods-add")}</Button.Label>
          </Button.Root>
          <Button.Root variant="ghost">
            <Button.Icon>
              <FolderOpen size={13} />
            </Button.Icon>
            <Button.Label>{t("mods-open-folder")}</Button.Label>
          </Button.Root>
        </div>

        <AnimatePresence mode="popLayout" initial={false}>
          {mods.length === 0 ? (
            <motion.div
              key="empty"
              className="flex flex-col items-center justify-center gap-2.5 py-12 px-5 text-center bg-card border border-border rounded-lg"
              initial={{ opacity: 0 }}
              animate={{ opacity: 1 }}
              exit={{ opacity: 0 }}
            >
              <Puzzle size={32} className="text-text-dim opacity-50" />
              <div className="text-[13px] font-medium text-text-muted">{t("mods-empty-title")}</div>
              <div className="text-[12px] text-text-dim max-w-52 leading-relaxed">
                {t("mods-empty-description")}
              </div>
            </motion.div>
          ) : (
            <motion.div key="list" layout>
              <Card.Root>
                <AnimatePresence initial={false}>
                  {mods.map((mod, i) => {
                    const modName = t(mod.nameId);
                    return (
                      <motion.div
                        key={mod.id}
                        initial={{ opacity: 0 }}
                        animate={{ opacity: 1 }}
                        exit={{ opacity: 0, height: 0, overflow: "hidden" }}
                        transition={{ duration: 0.16 }}
                        layout="position"
                        className={
                          "flex items-center gap-3 px-4 py-3 transition-colors duration-120 hover:bg-card-hover" +
                          (i > 0 ? " border-t border-border-subtle" : "")
                        }
                      >
                        <div className="w-8 h-8 flex items-center justify-center rounded icon-box--purple shrink-0">
                          <Puzzle size={14} />
                        </div>

                        <div className="flex-1 min-w-0">
                          <div className="flex items-center gap-1.5 mb-0.5 min-w-0">
                            <span className="text-[13px] font-medium text-text truncate">
                              {modName}
                            </span>
                            <Badge.Root variant={TYPE_VARIANTS[mod.type]}>
                              <Badge.Label>{t(TYPE_LABELS[mod.type])}</Badge.Label>
                            </Badge.Root>
                          </div>
                          <div className="text-[11.5px] text-text-muted truncate">
                            {t(mod.descriptionId)}
                          </div>
                        </div>

                        <span className="text-[11.5px] text-text-dim shrink-0 tabular-nums">
                          {mod.size}
                        </span>

                        <div className="flex items-center gap-2 shrink-0">
                          <Toggle
                            checked={mod.enabled}
                            onChange={() => toggle(mod.id)}
                            label={t("mods-toggle", { name: modName })}
                          />
                          <Tooltip.Root>
                            <Tooltip.Trigger
                              render={
                                <Button.Root
                                  variant="danger"
                                  size="icon"
                                  aria-label={t("mods-remove")}
                                  onClick={() => remove(mod.id)}
                                >
                                  <Button.Icon>
                                    <Trash2 size={13} />
                                  </Button.Icon>
                                </Button.Root>
                              }
                            />
                            <Tooltip.Portal>
                              <Tooltip.Positioner>
                                <Tooltip.Popup>{t("mods-remove")}</Tooltip.Popup>
                              </Tooltip.Positioner>
                            </Tooltip.Portal>
                          </Tooltip.Root>
                        </div>
                      </motion.div>
                    );
                  })}
                </AnimatePresence>
              </Card.Root>
            </motion.div>
          )}
        </AnimatePresence>
      </div>
    </Tooltip.Provider>
  );
}
