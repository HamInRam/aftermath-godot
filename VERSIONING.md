# Version Workflow

1. `main` is the protected integration branch. Do not develop directly on it.
2. Start each version from the latest `main` using sequential branches: `v.0.0.1`, `v.0.0.2`, and so on.
3. Commit all work for a version only to its version branch.
4. Update `CHANGELOG.md` with every meaningful version change before pushing.
5. Push the version branch to GitHub and keep its pull request in draft status.
6. Do not merge into `main` until the project owner explicitly approves the merge.
7. After approval, merge the version branch, mark its changelog entry as released, and begin the next version from the updated `main`.
