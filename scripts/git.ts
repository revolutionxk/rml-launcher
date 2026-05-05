import { execSync } from "node:child_process";

export const getGitHash = () => {
    try {
        const hash = execSync("git rev-parse --short HEAD").toString().trim();
        return hash;
    } catch (error) {
        console.error("Failed to get git hash:", error);
        return "unknown";
    }
};