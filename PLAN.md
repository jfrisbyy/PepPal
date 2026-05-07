# Seed personas once globally — no auto-attach on signup

**What changes**

- Stop auto-connecting every new sign-up to the seeded personas. Right now, each new account silently follows (and is followed by) all 25 personas the moment it's created — that's why it feels like an onboarding side-effect rather than a real community.
- The personas remain in the database as fully-real users (profile, avatar, banner, posts, follow graph among themselves). New users will simply *discover* them through the community/discover/search surfaces like any other account.
- Keep a developer-only "Seed personas" button (already in Developer Settings) so the one-time global drop can be triggered manually, and re-run if needed. Nothing fires automatically on signup anymore.

**Result for users**

- Brand-new accounts start with an empty Following list (as expected for a real social app), and the personas appear organically in Discover/search/community feeds.
- Follower/following counts on personas only grow when real users actually follow them.
- No behavioral difference between personas and real accounts — they post, can be followed, appear in lists and counts.

**Note**

- Existing accounts that were already auto-followed to personas keep those follows; this only changes future signups. If you want me to also unwind those existing auto-follows for current users, say the word and I'll add that as a follow-up.