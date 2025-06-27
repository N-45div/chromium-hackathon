import { defineConfig } from 'tsup';

export default defineConfig({
  entry: ['src/**/*.ts', '!src/__tests__/**/*.ts'],
  outDir: 'dist',
  tsconfig: './tsconfig.build.json',
  sourcemap: true,
  clean: true,
  format: ['esm'],
  splitting: false,
  dts: false,

  outExtension() {
    return {
      js: '.mjs',
    };
  },
});
