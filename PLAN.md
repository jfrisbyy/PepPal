# Fix social media links not saving to your profile

**The problem**

The fields exist in the edit screen, but the database hasn't been told to store them yet — so when you tap Save, the handles silently get dropped on the way to the server. When the profile reloads, those fields come back empty and no icons show.

**What I'll do**

- Apply the missing database update so your Instagram, X, TikTok, and Facebook handles actually have a place to live on the server.
- Surface a clear error message if a profile save ever fails, instead of silently dismissing the screen — so you'll see what's going wrong next time.
- Double-check that handles get cleaned up properly (handles pasted as full URLs like `instagram.com/yourname` will be trimmed down to just the handle).
- After saving, the colorful social icons will appear right under your bio, and tapping any one will open that platform directly to your page.

**What you'll see after**

- Type your handles in Edit Profile → Save → return to your profile → icons appear instantly.
- Each icon opens Instagram, X, TikTok, or Facebook to your page in one tap.
- Empty fields stay hidden (no broken icons).