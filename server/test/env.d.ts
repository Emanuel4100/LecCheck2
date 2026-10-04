import type { Env as WorkerEnv } from "../src/user-store";

declare global {
  namespace Cloudflare {
    interface Env extends WorkerEnv {}
  }
}

export {};
