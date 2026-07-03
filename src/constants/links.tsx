import { BookOpen, Bug, GitBranch, Heart } from "lucide-react";

export const RML_DISCORD_URL = "https://robloxmodloader.com";
export const RML_SPONSOR_URL = "https://github.com/sponsors/revolutionxk";

export const RML_GITHUB_URL = "https://github.com/revolutionxk/roblox-modloader";
export const RML_WIKI_URL = `${RML_GITHUB_URL}/wiki`;
export const RML_RELEASES_URL = `${RML_GITHUB_URL}/releases`;

export const LINKS = [
  {
    icon: <GitBranch size={16} />,
    labelId: "about-link-source",
    descriptionId: "about-link-source-description",
    href: RML_GITHUB_URL,
  },
  {
    icon: <BookOpen size={16} />,
    labelId: "about-link-documentation",
    descriptionId: "about-link-documentation-description",
    href: RML_WIKI_URL,
  },
  {
    icon: <Bug size={16} />,
    labelId: "about-link-bug",
    descriptionId: "about-link-bug-description",
    href: `${RML_GITHUB_URL}/issues`,
  },
  {
    icon: <Heart size={16} />,
    labelId: "about-link-sponsor",
    descriptionId: "about-link-sponsor-description",
    href: RML_SPONSOR_URL,
  },
] as const;
