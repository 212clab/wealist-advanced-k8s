// Runtime configuration for Docker development environment
// This overrides the default config.js in public/

window.__ENV__ = {
  // Docker-compose mode: use localhost with ports
  API_BASE_URL: "http://localhost",
  // Not needed for local dev
  API_DOMAIN: ""
};
