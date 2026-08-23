# Copilot Instructions

## Migration Parity

`dev/migrations/` and `prod/migrations/` must always be kept in sync. Every migration file added, modified, or removed in one directory must have the identical change applied to the other. There should be no deviations between the two sets of migrations — same filenames, same numbering, same SQL content.

When creating or editing a migration:
- Apply the change to **both** `dev/migrations/` and `prod/migrations/`.
- Never update only one without updating the other.

## Documentation

`docs/schema.md` must be updated whenever the database schema changes. This includes:
- New tables or columns
- Dropped tables or columns
- Type or constraint changes
- Index additions or removals

Update the documentation in the same response/commit as the migration files.
