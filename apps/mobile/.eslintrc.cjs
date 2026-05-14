/** @type {import("eslint").Linter.Config} */
module.exports = {
  root: true,
  extends: ['expo'],
  ignorePatterns: ['/dist/*', '.expo', 'node_modules', 'expo-env.d.ts'],
  rules: {
    '@typescript-eslint/no-unused-vars': ['warn', { argsIgnorePattern: '^_' }],
  },
};
