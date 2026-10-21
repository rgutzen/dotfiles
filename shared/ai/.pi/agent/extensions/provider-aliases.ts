// Provider aliases — one provider under several IDs, one per billing account, so
// private and company spend stay separate in /model and in session costs.
//
// Pi allows one credential per provider ID. Every exported variable named
// <KEY_ENV>_<ACCOUNT>, e.g. DEEPSEEK_API_KEY_TERES, creates the alias
// <provider>-<account> (deepseek-teres) with that key. Its model list is copied
// from the base provider's catalog, so it needs no maintenance:
//   1. at load, from the catalog bundled with Pi (covers --list-models and the
//      startup default model);
//   2. at session_start, from the live registry, which also carries the newer
//      pi.dev catalog overlay (`pi update --models`).
//
// Profiles: the `pi-<account>` wrapper (see ~/.local/bin/pi-profile) sets
// PI_PROFILE=<account> and unsets the personal keys. At session start this
// extension then moves a model on <provider> to the same model on
// <provider>-<account>, so defaults and resumed sessions bill the profile's account.
//
// To support another provider, add its key variable to PROVIDERS.

import type { ExtensionAPI } from "@earendil-works/pi-coding-agent"

const PROVIDERS: Record<string, string> = {
  deepseek: "DEEPSEEK_API_KEY",
  mistral: "MISTRAL_API_KEY",
}

type CatalogModel = { provider: string; id: string; type?: string; api: string; baseUrl: string }

function aliases(): { alias: string; base: string; apiKeyEnv: string }[] {
  return Object.entries(PROVIDERS).flatMap(([base, keyEnv]) =>
    Object.keys(process.env)
      .filter((name) => name.startsWith(`${keyEnv}_`) && process.env[name])
      .map((name) => ({
        alias: `${base}-${name.slice(keyEnv.length + 1).toLowerCase()}`,
        base,
        apiKeyEnv: name,
      })),
  )
}

function register(pi: ExtensionAPI, models: CatalogModel[]) {
  for (const { alias, base, apiKeyEnv } of aliases()) {
    const copies = models
      .filter((m) => m.provider === base && (m.type ?? "chat") === "chat")
      .map(({ provider, type, ...m }) => m)
    if (copies.length === 0) {
      console.warn(`[provider-aliases] no catalog models for "${base}" — ${alias} skipped`)
      continue
    }
    pi.registerProvider(alias, {
      api: copies[0].api,
      baseUrl: copies[0].baseUrl,
      apiKey: `$${apiKeyEnv}`,
      models: copies,
    } as any)
  }
}

export default async function (pi: ExtensionAPI) {
  const { getModels } = await import("@earendil-works/pi-ai")
  register(pi, Object.keys(PROVIDERS).flatMap((b) => getModels(b as any) as unknown as CatalogModel[]))

  pi.on("session_start", async (_event, ctx) => {
    register(pi, ctx.modelRegistry.getAll() as unknown as CatalogModel[])

    const profile = process.env.PI_PROFILE
    const current = ctx.model
    if (!profile || !current || !(current.provider in PROVIDERS)) return
    const target = ctx.modelRegistry.find(`${current.provider}-${profile}`, current.id)
    if (target) await pi.setModel(target)
  })
}
