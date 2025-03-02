import path from "path";
import react from "@vitejs/plugin-react";
import { defineConfig } from "vite";
import { nodePolyfills } from 'vite-plugin-node-polyfills';


export default defineConfig({
  build: {
    outDir: "dist",
  },
  server: {
    open: true,
  },
  plugins: [
    react(), nodePolyfills()
  ],
  resolve: {
    alias: {
      "@": path.resolve(__dirname, "./frontend"),
    },
  },
});
