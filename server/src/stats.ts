/**
 * Usage events for the owner, in Workers Analytics Engine:
 * free (100,000 points a day on the Workers Free plan), kept 3 months, and
 * read with the SQL API, so they cost no Durable Object storage or rows.
 *
 * One point when a device connects or disconnects live sync, says hello, or
 * syncs over HTTP. Nothing a user wrote is in it: only the account id, the
 * app build and platform, how many devices are connected, and the account's
 * size (rows, bytes) and rows written today.
 *
 * The dataset's columns (queries that read it depend on them):
 *   index1   account id (`g:<google id>`)
 *   blob1    event: connect | close | hello | sync
 *   blob2    platform (android, ios, linux, …; "" if the app didn't say)
 *   blob3    app build ("" if unknown)
 *   double1  devices connected after the event
 *   double2  rows stored      (hello and sync only, else 0)
 *   double3  bytes stored     (hello and sync only, else 0)
 *   double4  rows written today (UTC, hello and sync only, else 0)
 */

export type StatsEvent = "connect" | "close" | "hello" | "sync";

export interface StatsPoint {
  sub: string;
  event: StatsEvent;
  platform?: string;
  build?: number | null;
  sockets: number;
  rows?: number;
  bytes?: number;
  written?: number;
}

/** What the app says it runs on, if it looks like a platform name. */
export function platformOf(value: unknown): string {
  return typeof value === "string" && /^[a-z]{1,20}$/.test(value) ? value : "";
}

/** Writes [point] if the dataset is bound. Never throws: stats must not
 * break sync. */
export function record(dataset: AnalyticsEngineDataset | undefined, point: StatsPoint): void {
  if (!dataset || !point.sub) return;
  try {
    dataset.writeDataPoint({
      indexes: [point.sub.slice(0, 96)],
      blobs: [
        point.event,
        point.platform ?? "",
        typeof point.build === "number" ? String(point.build) : "",
      ],
      doubles: [point.sockets, point.rows ?? 0, point.bytes ?? 0, point.written ?? 0],
    });
  } catch (error) {
    console.error("stats write failed", error);
  }
}
