# reference-skills

A single plugin bundling third-party reference skills vendored from the
open agent-skills ecosystem. Skills are namespaced per plugin
(`/reference-skills:<skill-name>`), so any number of skills can live here
under one `skills/` directory without collisions — install this one plugin
once and every skill in the bundle becomes available.

Vendored via the [Skills CLI](https://skills.sh/) (`npx skills`), never
hand-copied. Source repo and content hash for each skill are tracked in the
marketplace root's `skills-lock.json`.

## Try it locally

```bash
claude --plugin-dir plugins/reference-skills
```

## Skills

### modern-jetpack-compose (`skills/modern-jetpack-compose`)

Writing, reviewing, and reasoning about modern Android UI code using
Jetpack Compose: state management, side effects, recomposition, navigation,
Material 3 design, accessibility, and performance.

- Upstream: [anhvt52/jetpack-compose-skills](https://github.com/anhvt52/jetpack-compose-skills)
- License: MIT (see `SKILL.md` frontmatter)
- Author: Anh Vu

### using-robolectric-correctly (`skills/using-robolectric-correctly`)

Running Android-aware unit tests correctly with Robolectric: runner choice,
`@Config`, `includeAndroidResources`, common shadows, looper draining, the
AGP 7.2+ `sharedTest` gotcha, and when NOT to reach for Robolectric.

- Upstream: [skydoves/android-testing-skills](https://github.com/skydoves/android-testing-skills)
  (skill path `jvm-tests/robolectric/using-robolectric-correctly`)
- License: Apache-2.0 (see `SKILL.md` frontmatter)
- Author: Jaewoong Eum (skydoves)

## Vendoring another skill into this bundle

1. Fetch it with the Skills CLI, copying (not symlinking) so the content
   lands in the repo:

   ```bash
   npx skills add <owner/repo> -s <skill-name> -a claude-code --copy -y
   ```

2. Move the fetched `.claude/skills/<skill-name>` folder into
   `plugins/reference-skills/skills/<skill-name>`.
3. Strip anything that isn't Claude Code content (other agents' adapter
   files, `.gitkeep` placeholders in now-populated directories). Leave
   `SKILL.md` and its real reference files untouched — they're licensed
   third-party content.
4. Add a `### <skill-name>` entry above with source/license/author, and
   bump `version` in `.claude-plugin/plugin.json`.

No new plugin, no new marketplace entry — the bundle grows by adding a
folder.
