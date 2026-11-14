## graphify

This project has a knowledge graph at graphify-out/ with god nodes, community structure, and cross-file relationships.

Rules:
- For codebase questions, first run `graphify query "<question>"` when graphify-out/graph.json exists. Use `graphify path "<A>" "<B>"` for relationships and `graphify explain "<concept>"` for focused concepts. These return a scoped subgraph, usually much smaller than GRAPH_REPORT.md or raw grep output.
- If graphify-out/wiki/index.md exists, use it for broad navigation instead of raw source browsing.
- Read graphify-out/GRAPH_REPORT.md only for broad architecture review or when query/path/explain do not surface enough context.
- After modifying code, run `graphify update .` to keep the graph current (AST-only, no API cost).

## Team changelog (every push)

The team is Nabil (`Nishmam12`, RTX 4070 Ti Super), Afnan (`Afnan Mojumder` /
`afnan-mojumder`, RTX 2070 Super) and Daniel (`capitalD` / `capitalD10`,
RTX 5060). Tell who is pushing from `git config user.name`.

Before **any** `git push` to GitHub, by anyone on the team:

1. `git fetch`, then check `TEAM_CHANGELOG.md` against the git history. For
   any push by anyone since the newest entry that has no entry, add one from
   the history and mark it "Added from the git history by <name>'s Claude".
2. Add an entry for this push at the top of the push log in
   `TEAM_CHANGELOG.md`, in the format the file shows: date, who and machine,
   branch, version (or "no version bump"), commit range, what changed in plain
   words, what the others need to do (update first, database change, new
   dependency, `flutter pub get`, or nothing), and what was tested (analyze,
   tests, which device, or "not on a device yet").
3. Commit it and push it in the same push.

Write it for a teammate who wasn't there. Never put emails, tokens or other
secrets in it. If two branches both add entries, keep both when merging,
newest first. The app's own version history stays in `CHANGELOG.md`; this
file is the record of who pushed what.
