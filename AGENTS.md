## Testing (RSpec)

We use RSpec with:

- **`context`** — group examples by scenario or setup.
- **`let`** — define lazy, memoized values used by examples.
- **`subject`** — name the object under test when it improves clarity.
- Declare `subject` above any other `let` declarations.
- Declare `subject` above any other `before` declarations.

We aim for **one `expect` per example** when that keeps failures easy to
interpret; use multiple expectations in the same example when splitting would be
artificial or would hide a single behavioural assertion.

After Ruby changes, run **`bundle exec rspec`**. Add specs for new methods and behaviour.
