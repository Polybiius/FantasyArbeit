import js from '@eslint/js';
import globals from 'globals';
import html from 'eslint-plugin-html';
import tseslint from 'typescript-eslint';
import reactHooks from 'eslint-plugin-react-hooks';
import reactRefresh from 'eslint-plugin-react-refresh';

// Drei Code-Welten in einem Repo (siehe die jeweiligen files:-Blöcke):
//   1) src/**            React + striktes TypeScript (der Umbau)
//   2) index.html        Vanilla-<script>-Block (die bestehende App)
//   3) tests/**          Node-ESM + Playwright (Regressions-Suiten)
// plus die Node-Konfigdateien im Wurzelverzeichnis.
export default tseslint.config(
  {
    ignores: [
      'dist/**',
      'node_modules/**',
      'sql/**',
      'src/shared/types/supabase.ts', // generiert (npm run gen:types)
    ],
  },

  // --- 1) React + TypeScript ---
  {
    files: ['src/**/*.{ts,tsx}'],
    extends: [js.configs.recommended, ...tseslint.configs.recommendedTypeChecked],
    languageOptions: {
      ecmaVersion: 2022,
      globals: globals.browser,
      parserOptions: {
        projectService: true,
        tsconfigRootDir: import.meta.dirname,
      },
    },
    plugins: {
      'react-hooks': reactHooks,
      'react-refresh': reactRefresh,
    },
    rules: {
      ...reactHooks.configs['recommended-latest'].rules,
      'react-refresh/only-export-components': ['warn', { allowConstantExport: true }],
      // Der Umbau hat keinen menschlichen Code-Review -- kein any als Ausweg.
      '@typescript-eslint/no-explicit-any': 'error',
    },
  },

  // --- 2) Bestehender Vanilla-<script>-Block in index.html ---
  {
    files: ['**/*.html'],
    extends: [js.configs.recommended],
    plugins: { html },
    languageOptions: {
      ecmaVersion: 2022,
      sourceType: 'script',
      globals: {
        window: 'readonly',
        document: 'readonly',
        console: 'readonly',
        fetch: 'readonly',
        alert: 'readonly',
        confirm: 'readonly',
        prompt: 'readonly',
        localStorage: 'readonly',
        setTimeout: 'readonly',
        clearTimeout: 'readonly',
        setInterval: 'readonly',
        clearInterval: 'readonly',
        Intl: 'readonly',
        FormData: 'readonly',
        FileReader: 'readonly',
        URL: 'readonly',
        URLSearchParams: 'readonly',
        navigator: 'readonly',
        history: 'readonly',
        location: 'readonly',
        Image: 'readonly',
        indexedDB: 'readonly',
        crypto: 'readonly',
        // von den zwei CDN-Skripten geladen (supabase-js, Leaflet)
        supabase: 'readonly',
        L: 'readonly',
      },
    },
    rules: {
      'no-unused-vars': 'warn',
      'no-undef': 'warn',
    },
  },

  // --- 3) Regressions-Suiten (Node + Playwright), siehe tests/README.md ---
  {
    files: ['tests/**/*.mjs'],
    extends: [js.configs.recommended],
    languageOptions: {
      ecmaVersion: 2023,
      sourceType: 'module',
      globals: {
        ...globals.node,
        // in page.evaluate()-Callbacks referenziert -- laufen im Browser-Kontext
        window: 'readonly',
        document: 'readonly',
        getComputedStyle: 'readonly',
      },
    },
    rules: {
      'no-unused-vars': 'warn',
      'no-undef': 'warn',
    },
  },

  // --- 4) Node-Konfigdateien im Wurzelverzeichnis ---
  {
    files: ['*.js', '*.ts'],
    extends: [js.configs.recommended, ...tseslint.configs.recommended],
    languageOptions: {
      globals: globals.node,
    },
  },
);
