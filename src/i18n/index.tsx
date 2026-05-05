import { FluentBundle, FluentResource, type FluentVariable } from "@fluent/bundle";
import { createContext, useContext, useEffect, useState, type ReactNode } from "react";

import { APP_NAME } from "@/constants/app";
import { MESSAGES } from "@/i18n/messages";

const LOCALE_STORAGE_KEY = "rml-locale";

export const SUPPORTED_LOCALES = ["en-US", "pt-BR"] as const;

export type SupportedLocale = (typeof SUPPORTED_LOCALES)[number];
export type LocalePreference = SupportedLocale | "system";

type TranslationArgs = Record<string, string | number | null | undefined>;

interface I18nContextValue {
  locale: SupportedLocale;
  preference: LocalePreference;
  setPreference: (value: LocalePreference) => void;
  t: (id: string, args?: TranslationArgs) => string;
  formatDate: (value: string | Date, options?: Intl.DateTimeFormatOptions) => string;
}

export const LOCALE_OPTIONS: { value: LocalePreference; labelId: string }[] = [
  { value: "system", labelId: "locale-option-system" },
  { value: "en-US", labelId: "locale-option-en-US" },
  { value: "pt-BR", labelId: "locale-option-pt-BR" },
];

const I18nContext = createContext<I18nContextValue | null>(null);

function isSupportedLocale(value: string): value is SupportedLocale {
  return SUPPORTED_LOCALES.some((locale) => locale === value);
}

function isLocalePreference(value: string | null): value is LocalePreference {
  return value === "system" || (value !== null && isSupportedLocale(value));
}

function resolveLocale(candidate: string | null | undefined): SupportedLocale | null {
  if (!candidate) {
    return null;
  }

  const normalized = candidate.toLowerCase();

  if (normalized.startsWith("pt")) {
    return "pt-BR";
  }

  if (normalized.startsWith("en")) {
    return "en-US";
  }

  return null;
}

function getSystemLocale(): SupportedLocale {
  if (typeof navigator === "undefined") {
    return "en-US";
  }

  const candidates = navigator.languages?.length ? navigator.languages : [navigator.language];

  for (const candidate of candidates) {
    const locale = resolveLocale(candidate);
    if (locale) {
      return locale;
    }
  }

  return "en-US";
}

function getStoredPreference(): LocalePreference {
  if (typeof window === "undefined") {
    return "system";
  }

  const stored = window.localStorage.getItem(LOCALE_STORAGE_KEY);
  return isLocalePreference(stored) ? stored : "system";
}

function createBundle(locale: SupportedLocale) {
  const bundle = new FluentBundle(locale);
  bundle.addResource(new FluentResource(MESSAGES[locale]));
  return bundle;
}

function normalizeArgs(args?: TranslationArgs): Record<string, FluentVariable> | undefined {
  if (!args) {
    return undefined;
  }

  const normalized = Object.fromEntries(
    Object.entries(args).filter(
      ([, value]) => typeof value === "string" || typeof value === "number",
    ),
  ) as Record<string, FluentVariable>;

  return Object.keys(normalized).length > 0 ? normalized : undefined;
}

export function I18nProvider({ children }: { children: ReactNode }) {
  const [preference, setPreference] = useState<LocalePreference>(() => getStoredPreference());
  const [systemLocale, setSystemLocale] = useState<SupportedLocale>(() => getSystemLocale());

  const locale = preference === "system" ? systemLocale : preference;
  const bundle = createBundle(locale);

  useEffect(() => {
    window.localStorage.setItem(LOCALE_STORAGE_KEY, preference);
  }, [preference]);

  useEffect(() => {
    const handleLanguageChange = () => setSystemLocale(getSystemLocale());

    window.addEventListener("languagechange", handleLanguageChange);
    return () => window.removeEventListener("languagechange", handleLanguageChange);
  }, []);

  useEffect(() => {
    document.documentElement.lang = locale;
    document.title = APP_NAME;
  }, [locale]);

  const t = (id: string, args?: TranslationArgs) => {
    const message = bundle.getMessage(id);

    if (!message?.value) {
      return id;
    }

    return bundle.formatPattern(message.value, normalizeArgs(args));
  };

  const formatDate = (value: string | Date, options?: Intl.DateTimeFormatOptions) => {
    const date = value instanceof Date ? value : new Date(value);

    if (Number.isNaN(date.getTime())) {
      return "";
    }

    return new Intl.DateTimeFormat(locale, options ?? { dateStyle: "long" }).format(date);
  };

  return (
    <I18nContext.Provider value={{ locale, preference, setPreference, t, formatDate }}>
      {children}
    </I18nContext.Provider>
  );
}

export function useI18n() {
  const context = useContext(I18nContext);

  if (!context) {
    throw new Error("useI18n must be used inside I18nProvider");
  }

  return context;
}
