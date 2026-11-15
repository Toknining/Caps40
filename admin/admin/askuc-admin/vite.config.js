import { fileURLToPath } from 'node:url'
import { defineConfig, searchForWorkspaceRoot } from 'vite'
import react from '@vitejs/plugin-react'

// The campus graph and floor plans live with the mobile app. The Map page
// imports them from there, so the admin panel and the app never disagree.
const askucAssets = fileURLToPath(
  new URL('../../../Capstone40/Capstone40/askuc/assets', import.meta.url),
)

// https://vite.dev/config/
export default defineConfig({
  plugins: [react()],
  resolve: {
    alias: {
      '@askuc-assets': askucAssets,
    },
  },
  server: {
    fs: {
      // The dev server only serves files inside the project unless told to.
      allow: [searchForWorkspaceRoot(process.cwd()), askucAssets],
    },
  },
})
