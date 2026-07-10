import { mkdir } from "node:fs/promises";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";
import { chromium } from "playwright-core";

const scriptDirectory = dirname(fileURLToPath(import.meta.url));
const root = resolve(scriptDirectory, "..");
const outputDirectory = join(root, ".qa");
const edgePath = process.env.EDGE_PATH ??
  String.raw`C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe`;

const viewports = [
  { name: "desktop", width: 1440, height: 1000 },
  { name: "mobile", width: 390, height: 844 },
];

await mkdir(outputDirectory, { recursive: true });

const browser = await chromium.launch({
  executablePath: edgePath,
  headless: true,
});

try {
  for (const viewport of viewports) {
    const page = await browser.newPage({
      viewport: { width: viewport.width, height: viewport.height },
      colorScheme: "light",
    });

    await page.goto(pathToFileURL(join(root, "index.html")).href);
    await page.waitForLoadState("load");

    const layout = await page.evaluate(() => {
      const ignored = new Set(["skip-link"]);
      const overflowingElements = [...document.querySelectorAll("body *")]
        .filter((element) => {
          if ([...element.classList].some((name) => ignored.has(name))) return false;
          const style = getComputedStyle(element);
          if (style.display === "none" || style.visibility === "hidden") return false;
          const rect = element.getBoundingClientRect();
          if (rect.width === 0 || rect.height === 0) return false;
          return rect.left < -0.5 || rect.right > window.innerWidth + 0.5;
        })
        .map((element) => ({
          tag: element.tagName.toLowerCase(),
          className: element.className,
          text: element.textContent?.trim().slice(0, 80) ?? "",
          rect: element.getBoundingClientRect().toJSON(),
        }));

      const icon = document.querySelector(".app-icon");
      return {
        innerWidth: window.innerWidth,
        clientWidth: document.documentElement.clientWidth,
        scrollWidth: document.documentElement.scrollWidth,
        overflowingElements,
        h1: document.querySelector("h1")?.textContent?.trim(),
        contactVisible: Boolean(document.querySelector(".contact-link")),
        iconLoaded: icon instanceof HTMLImageElement && icon.complete && icon.naturalWidth === 512,
      };
    });

    if (layout.innerWidth !== viewport.width || layout.clientWidth !== viewport.width) {
      throw new Error(
        `${viewport.name}: expected ${viewport.width}px viewport, got ` +
        `${layout.innerWidth}px inner / ${layout.clientWidth}px client`,
      );
    }
    if (layout.scrollWidth > viewport.width || layout.overflowingElements.length > 0) {
      throw new Error(
        `${viewport.name}: horizontal overflow detected: ` +
        JSON.stringify(layout.overflowingElements, null, 2),
      );
    }
    if (layout.h1 !== "Your receipts stay under your control.") {
      throw new Error(`${viewport.name}: privacy-policy heading is missing or changed.`);
    }
    if (!layout.contactVisible || !layout.iconLoaded) {
      throw new Error(`${viewport.name}: contact link or app icon failed to render.`);
    }

    await page.screenshot({
      path: join(outputDirectory, `${viewport.name}-viewport.png`),
      fullPage: false,
    });
    await page.screenshot({
      path: join(outputDirectory, `${viewport.name}-full-page.png`),
      fullPage: true,
    });
    await page.close();

    console.log(
      `${viewport.name}: ${viewport.width}x${viewport.height}, no horizontal overflow`,
    );
  }
} finally {
  await browser.close();
}
