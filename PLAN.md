# Tone down streaks across the app and hide them from friends

## Changes

**1. Sport dashboard empty-state nudges**

- [x] Replace streak-focused empty copy in Swimming, Soccer, Pickleball, Running.

**2. Per-sport streak sections**

- [x] Remove dedicated "Streak" section from Running dashboard.
- [x] Remove "STREAK" hero stat from Sleep & Recovery.
- [x] Remove "Current Streak" row from Martial Arts settings.

**3. Health detail & monthly recap**

- [x] Remove per-metric streak chips strip from Health Detail.
- [x] Remove "Best streak" stats from Monthly Summary.
- [x] Remove streak badge/tile from Weekly Recap card.

**4. Profile cleanup**

- [x] Removed streak from About row (was in UserProfileView).

**5. Home screen**

- [x] Toolbar flame icon kept.
- [x] Removed large dedicated Streak section.
- [x] Paused/freeze banners kept (now inline in transient banners).

**6. Notifications**

- [x] streakWarningNotifs default flipped to false.

**7. Hide streaks from friends and public profiles**

- [x] Removed streak stat tile + about row from UserProfileView.
- [x] Removed `.streak` case from StatShareCategory.
- [x] Removed streak from FriendDashboardView, FriendComparisonView, FriendStatDetailSheet, FollowListView, FriendsStatsView card, BorrowProgramSheet, GroupStatMetric, GroupStatsView copy.
