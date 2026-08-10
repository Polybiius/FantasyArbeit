import js from '@eslint/js';
import html from 'eslint-plugin-html';

export default [
  js.configs.recommended,
  {
    files: ['**/*.html'],
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
];
