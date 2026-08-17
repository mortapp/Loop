// Shared ESLint flat config, extended by each app/package.
// @ts-check
import js from "@eslint/js";
import tseslint from "typescript-eslint";

/** @type {import("eslint").Linter.Config[]} */
export const baseConfig = [
  js.configs.recommended,
  ...tseslint.configs.recommended,
  {
    rules: {
      "@typescript-eslint/no-unused-vars": [
        "error",
        { argsIgnorePattern: "^_", varsIgnorePattern: "^_" },
      ],
      "@typescript-eslint/consistent-type-imports": "error",
    },
  },
  {
    ignores: ["**/dist/**", "**/.next/**", "**/node_modules/**", "**/build/**"],
  },
];

export default baseConfig;
