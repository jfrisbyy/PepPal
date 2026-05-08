# Rebuild DMs end-to-end so messages actually appear when sent

## What's broken today

Every screen that opens a chat (profile, friends, social tab) creates its **own separate** messaging "brain." When you send a message in one place, the other places never see it. The chat screen also wraps that brain in a second local copy, so updates inside the conversation don't always re-render the bubble list. That's why messages disappear.

## The fix

**One shared messaging brain for the whole app.** Created once at app launch and used everywhere. No more duplicates, no more local copies, no more merge gymnastics.

### Send flow (rewritten to be dead simple)

1. You tap send → bubble appears immediately in the chat (optimistic).
2. In the background it makes sure the conversation exists on the server, then saves the message.
3. When the server confirms, the bubble's "sent" checkmark lights up.
4. If anything fails, the bubble shows a red "tap to retry" state instead of vanishing silently.

### Receive flow

- Realtime listener attaches the moment you open a chat (and re-attaches automatically if the connection drops).
- Incoming messages from the other person stream in live.

### Chat screen rebuild

- Cleaner, single source of truth for the message list.
- Auto-scrolls to the newest bubble on send and on receive.
- Shows a clear empty state, a "sending…" state, and a "failed — tap to retry" state.
- Keeps the existing editorial styling (serif text, teal bubbles, floating top bar) — visual design stays the same.

### Verification before I hand it back

- I'll run the build to confirm it compiles cleanly.
- I'll send a test message from a seeded account and confirm via runtime logs that the bubble actually renders in the UI (not just that the row was inserted in the database).
- If the log shows the bubble didn't render, I keep iterating until it does.

## What stays the same

- Your conversations list, search, blocking, reporting, voice notes, photo/video attachments, typing indicator, read receipts — all preserved.
- Database schema and Supabase functions are untouched.

## What changes for you

- Messages you send appear instantly and stay there.
- Opening the same chat from different places (profile vs. friends vs. inbox) shows the same conversation with the same messages.
- New incoming DMs surface live without needing to leave and come back.

