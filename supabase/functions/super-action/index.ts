// Supabase Edge Function: super-action
// Action router — reads { action, payload } and dispatches to a handler.
// Deployed as the canonical multi-action function so we don't depend on
// deploying per-action functions manually.

import { createClient, type SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2.45.4";

const CORS_HEADERS = {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
    "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const JSON_HEADERS = { ...CORS_HEADERS, "Content-Type": "application/json" };

function json(status: number, body: unknown): Response {
    return new Response(JSON.stringify(body), { status, headers: JSON_HEADERS });
}

// ---- Curated test-friend data -----------------------------------------

const NAMES: string[] = [
    "Ava Chen",
    "Marcus Lee",
    "Priya Patel",
    "Diego Ramirez",
    "Sofia Müller",
    "Kenji Tanaka",
    "Zara Ahmed",
    "Noah Williams",
    "Emma Johansson",
    "Liam O'Connor",
    "Maya Singh",
    "Oliver Brown",
    "Isabela Costa",
    "Finn Hartley",
    "Luna Park",
];

const AVATAR_PALETTE: string[] = [
    "#F59E0B", "#8B5CF6", "#14B8A6", "#3B82F6",
    "#EC4899", "#10B981", "#F97316", "#A855F7",
];

const BIOS: string[] = [
    "Push day devotee. Building strength one rep at a time.",
    "Powerlifting. Meet prep. Steady progress.",
    "Running & lifting — half marathon training.",
    "Calisthenics-first. Bodyweight forever.",
    "Yoga teacher. Mobility > intensity.",
    "Crossfit. Community. Community.",
    "Peptide protocol journey. Tracking everything.",
    "Consistency > motivation. 5/3/1 lifer.",
    "Couch to 5K convert. Steps queen.",
    "Vegan athlete. Macros on point.",
    "Climbing, cardio, coffee.",
    "Full body, four days a week.",
    "Strength & conditioning coach.",
    "New to the gym, all in.",
    "Long game. Slow gains. Big lifts.",
];

function slugify(name: string): string {
    return name
        .toLowerCase()
        .normalize("NFD")
        .replace(/[\u0300-\u036f]/g, "")
        .replace(/[^a-z0-9]+/g, "")
        .slice(0, 20);
}

function initialsFor(name: string): string {
    return name
        .split(/\s+/)
        .filter(Boolean)
        .map((p) => p[0]?.toUpperCase() ?? "")
        .join("")
        .slice(0, 2);
}

function randInt(min: number, maxInclusive: number): number {
    return Math.floor(Math.random() * (maxInclusive - min + 1)) + min;
}

function isoDate(daysAgo: number): string {
    const d = new Date();
    d.setDate(d.getDate() - daysAgo);
    return d.toISOString().slice(0, 10);
}

// ---- ISO week helpers -------------------------------------------------

function isoWeekStart(d: Date = new Date()): string {
    const date = new Date(Date.UTC(d.getUTCFullYear(), d.getUTCMonth(), d.getUTCDate()));
    const day = date.getUTCDay() || 7; // Mon=1..Sun=7
    if (day !== 1) date.setUTCDate(date.getUTCDate() - (day - 1));
    return date.toISOString().slice(0, 10);
}

function previousIsoWeekStart(d: Date = new Date()): string {
    const start = new Date(isoWeekStart(d));
    start.setUTCDate(start.getUTCDate() - 7);
    return start.toISOString().slice(0, 10);
}

// ---- APNs push --------------------------------------------------------

async function importApnsKey(pem: string): Promise<CryptoKey | null> {
    try {
        const cleaned = pem.replace(/-----BEGIN PRIVATE KEY-----/g, "")
            .replace(/-----END PRIVATE KEY-----/g, "")
            .replace(/\s+/g, "");
        const der = Uint8Array.from(atob(cleaned), (c) => c.charCodeAt(0));
        return await crypto.subtle.importKey(
            "pkcs8",
            der,
            { name: "ECDSA", namedCurve: "P-256" },
            false,
            ["sign"],
        );
    } catch (e) {
        console.error("importApnsKey failed", e);
        return null;
    }
}

function b64url(bytes: Uint8Array): string {
    let s = btoa(String.fromCharCode(...bytes));
    return s.replace(/=+$/g, "").replace(/\+/g, "-").replace(/\//g, "_");
}
function b64urlString(str: string): string {
    return b64url(new TextEncoder().encode(str));
}

async function buildApnsJWT(teamId: string, keyId: string, key: CryptoKey): Promise<string> {
    const header = b64urlString(JSON.stringify({ alg: "ES256", kid: keyId, typ: "JWT" }));
    const claims = b64urlString(JSON.stringify({ iss: teamId, iat: Math.floor(Date.now() / 1000) }));
    const signingInput = `${header}.${claims}`;
    const sig = new Uint8Array(
        await crypto.subtle.sign({ name: "ECDSA", hash: "SHA-256" }, key, new TextEncoder().encode(signingInput)),
    );
    return `${signingInput}.${b64url(sig)}`;
}

let cachedJwt: { token: string; created: number } | null = null;
async function getApnsJWT(): Promise<{ token: string; bundleId: string; host: string } | null> {
    const teamId = Deno.env.get("APNS_TEAM_ID");
    const keyId = Deno.env.get("APNS_KEY_ID");
    const keyPem = Deno.env.get("APNS_AUTH_KEY");
    const bundleId = Deno.env.get("APNS_BUNDLE_ID");
    const env = (Deno.env.get("APNS_ENV") ?? "production").toLowerCase();
    if (!teamId || !keyId || !keyPem || !bundleId) return null;
    if (cachedJwt && Date.now() - cachedJwt.created < 30 * 60 * 1000) {
        return { token: cachedJwt.token, bundleId, host: env === "sandbox" ? "https://api.sandbox.push.apple.com" : "https://api.push.apple.com" };
    }
    const key = await importApnsKey(keyPem);
    if (!key) return null;
    const token = await buildApnsJWT(teamId, keyId, key);
    cachedJwt = { token, created: Date.now() };
    const host = env === "sandbox" ? "https://api.sandbox.push.apple.com" : "https://api.push.apple.com";
    return { token, bundleId, host };
}

async function sendApnsToTokens(
    tokens: string[],
    title: string,
    body: string,
    data: Record<string, unknown> = {},
): Promise<{ sent: number; failed: number }> {
    const auth = await getApnsJWT();
    if (!auth || tokens.length === 0) return { sent: 0, failed: 0 };
    let sent = 0;
    let failed = 0;
    const payload = JSON.stringify({
        aps: { alert: { title, body }, sound: "default", "mutable-content": 1 },
        ...data,
    });
    await Promise.all(tokens.map(async (t) => {
        try {
            const r = await fetch(`${auth.host}/3/device/${t}`, {
                method: "POST",
                headers: {
                    "authorization": `bearer ${auth.token}`,
                    "apns-topic": auth.bundleId,
                    "apns-push-type": "alert",
                    "content-type": "application/json",
                },
                body: payload,
            });
            if (r.ok) sent += 1; else failed += 1;
        } catch (_) {
            failed += 1;
        }
    }));
    return { sent, failed };
}

async function pushToUsers(
    admin: SupabaseClient,
    userIds: string[],
    title: string,
    body: string,
    data: Record<string, unknown> = {},
): Promise<{ sent: number; failed: number }> {
    if (userIds.length === 0) return { sent: 0, failed: 0 };
    const { data: rows } = await admin
        .from("device_tokens")
        .select("token, user_id")
        .in("user_id", userIds);
    const tokens = (rows ?? [])
        .map((r: { token: unknown }) => (typeof r.token === "string" ? r.token : null))
        .filter((t): t is string => !!t);
    return await sendApnsToTokens(tokens, title, body, data);
}

// ---- Auth helper ------------------------------------------------------

async function requireUser(req: Request, admin: SupabaseClient): Promise<
    { userId: string } | { response: Response }
> {
    const authHeader = req.headers.get("Authorization") ?? "";
    const jwt = authHeader.toLowerCase().startsWith("bearer ")
        ? authHeader.slice(7).trim()
        : "";
    if (!jwt) {
        return { response: json(401, { error: "unauthorized" }) };
    }
    const { data, error } = await admin.auth.getUser(jwt);
    if (error || !data?.user) {
        return { response: json(401, { error: "unauthorized" }) };
    }
    return { userId: data.user.id };
}

// ---- Handler: seedTestFriends ----------------------------------------

async function seedTestFriends(
    admin: SupabaseClient,
    callerId: string,
    payload: Record<string, unknown>,
): Promise<Response> {
    const rawCount = Number(payload.count ?? 15);
    const count = Math.min(50, Math.max(1, Number.isFinite(rawCount) ? rawCount : 15));

    // Pre-load an active training program id if any exist
    let programIds: string[] = [];
    try {
        const { data } = await admin.from("training_programs").select("id").limit(50);
        if (Array.isArray(data)) {
            programIds = data
                .map((r: { id: unknown }) => (typeof r.id === "string" ? r.id : null))
                .filter((v): v is string => v !== null);
        }
    } catch (_) {
        programIds = [];
    }

    let created = 0;
    let existed = 0;
    const createdIds: string[] = [];
    const errors: string[] = [];

    // Pre-fetch existing auth users once (paginated) to avoid scanning every loop
    const existingByEmail = new Map<string, string>();
    {
        let page = 1;
        while (page < 20) {
            const { data, error } = await admin.auth.admin.listUsers({ page, perPage: 200 });
            if (error) {
                errors.push(`listUsers page ${page}: ${error.message}`);
                break;
            }
            const users = data?.users ?? [];
            for (const u of users) {
                if (u.email) existingByEmail.set(u.email.toLowerCase(), u.id);
            }
            if (users.length < 200) break;
            page += 1;
        }
    }

    for (let i = 1; i <= count; i += 1) {
        const name = NAMES[(i - 1) % NAMES.length];
        const email = `peppal-test-${i}@peppaltest.app`;
        const avatarColor = AVATAR_PALETTE[(i - 1) % AVATAR_PALETTE.length];
        const bio = BIOS[(i - 1) % BIOS.length];
        const username = `${slugify(name)}${i}`;
        const streak = randInt(0, 42);
        const program = programIds.length > 0
            ? programIds[randInt(0, programIds.length - 1)]
            : null;

        let userId: string | null = existingByEmail.get(email.toLowerCase()) ?? null;

        if (!userId) {
            const { data: createRes, error: createErr } = await admin.auth.admin.createUser({
                email,
                password: crypto.randomUUID(),
                email_confirm: true,
                user_metadata: { is_test_user: true, full_name: name },
            });
            if (createRes?.user) {
                userId = createRes.user.id;
                created += 1;
            } else {
                // Either already exists or another error. Try to look it up.
                const { data: list } = await admin.auth.admin.listUsers({ page: 1, perPage: 200 });
                const match = list?.users?.find((u) => (u.email ?? "").toLowerCase() === email.toLowerCase());
                if (match) {
                    userId = match.id;
                    existed += 1;
                } else {
                    const msg = createErr?.message ?? "unknown";
                    errors.push(`createUser ${email}: ${msg}`);
                    console.error("createUser failed", email, createErr);
                    continue;
                }
            }
        } else {
            existed += 1;
        }

        if (!userId) continue;
        createdIds.push(userId);

        const { error: upsertErr } = await admin.from("profiles").upsert({
            id: userId,
            display_name: name,
            username,
            initials: initialsFor(name),
            bio,
            avatar_color: avatarColor,
            active_program: program,
            current_streak: streak,
            is_private: false,
            is_test_user: true,
        }, { onConflict: "id" });

        if (upsertErr) {
            errors.push(`profile upsert ${email}: ${upsertErr.message}`);
            console.error("profile upsert failed", email, upsertErr);
        }
    }

    // Mutual follows in both directions — idempotent via the unique index
    const followRows: { follower_id: string; following_id: string }[] = [];
    for (const id of createdIds) {
        followRows.push({ follower_id: callerId, following_id: id });
        followRows.push({ follower_id: id, following_id: callerId });
    }
    let followed = 0;
    if (followRows.length > 0) {
        const { error: followErr, count: followCount } = await admin
            .from("follows")
            .upsert(followRows, { onConflict: "follower_id,following_id", ignoreDuplicates: true, count: "exact" });
        if (followErr) {
            errors.push(`follows upsert: ${followErr.message}`);
            console.error("follows upsert failed", followErr);
        } else {
            followed = followCount ?? followRows.length;
        }
    }

    const { count: totalTestProfiles } = await admin
        .from("profiles")
        .select("id", { count: "exact", head: true })
        .eq("is_test_user", true);

    return json(200, {
        ok: errors.length === 0,
        version: "seed-v2",
        created,
        existed,
        total_test_profiles: totalTestProfiles ?? createdIds.length,
        followed,
        error: errors.length > 0 ? errors.slice(0, 5).join("; ") : undefined,
        error_details: errors,
    });
}

// ---- Handler: clearTestFriends ---------------------------------------

async function clearTestFriends(admin: SupabaseClient): Promise<Response> {
    let deleted = 0;
    let page = 1;
    while (page < 20) {
        const { data } = await admin.auth.admin.listUsers({ page, perPage: 200 });
        const users = data?.users ?? [];
        const targets = users.filter((u) => {
            const e = (u.email ?? "").toLowerCase();
            return e.endsWith("@peppal.test") || e.endsWith("@peppaltest.app");
        });
        for (const u of targets) {
            const { error } = await admin.auth.admin.deleteUser(u.id);
            if (error) {
                console.error("deleteUser failed", u.id, error);
                continue;
            }
            deleted += 1;
        }
        if (users.length < 200) break;
        page += 1;
    }
    return json(200, { ok: true, version: "seed-v2", deleted });
}

// ---- Friends helpers --------------------------------------------------

async function mutualFriendIds(admin: SupabaseClient, userId: string): Promise<string[]> {
    const [{ data: outRows }, { data: inRows }] = await Promise.all([
        admin.from("follows").select("following_id").eq("follower_id", userId),
        admin.from("follows").select("follower_id").eq("following_id", userId),
    ]);
    const out = new Set((outRows ?? []).map((r: { following_id: string }) => r.following_id));
    const inn = new Set((inRows ?? []).map((r: { follower_id: string }) => r.follower_id));
    return Array.from(out).filter((id) => inn.has(id));
}

async function followerIds(admin: SupabaseClient, userId: string): Promise<string[]> {
    const { data } = await admin.from("follows").select("follower_id").eq("following_id", userId);
    return (data ?? []).map((r: { follower_id: string }) => r.follower_id);
}

async function fetchProfilesByIds(admin: SupabaseClient, ids: string[]) {
    if (ids.length === 0) return [];
    const { data } = await admin
        .from("profiles")
        .select("id, display_name, username, avatar_url, avatar_color, active_program, total_fp, current_streak")
        .in("id", ids);
    return data ?? [];
}

async function friendsFeed(admin: SupabaseClient, userId: string): Promise<Response> {
    const friendIds = await mutualFriendIds(admin, userId);
    if (friendIds.length === 0) {
        return json(200, { ok: true, friends: [], events: [], myRecap: null });
    }

    const week = isoWeekStart();
    const [profilesData, prefsData, snapsData, eventsData] = await Promise.all([
        fetchProfilesByIds(admin, friendIds),
        admin.from("stat_sharing_prefs").select("*").in("user_id", friendIds).eq("is_enabled", true),
        admin.from("friend_stat_snapshots").select("*").in("user_id", friendIds).eq("week_start", week),
        admin
            .from("friend_activity_events")
            .select("*")
            .in("user_id", friendIds)
            .order("created_at", { ascending: false })
            .limit(60),
    ]);

    const prefsById = new Map<string, { audience: string; categories: string[] }>();
    for (const p of (prefsData.data ?? [])) {
        prefsById.set(p.user_id, { audience: p.audience, categories: p.categories });
    }
    const snapsById = new Map<string, Record<string, unknown>>();
    for (const s of (snapsData.data ?? [])) {
        snapsById.set(s.user_id, s);
    }

    const friends = profilesData.map((p: { id: string }) => ({
        profile: p,
        prefs: prefsById.get(p.id) ?? null,
        snapshot: snapsById.get(p.id) ?? null,
    })).filter((f) => f.prefs !== null);

    return json(200, {
        ok: true,
        friends,
        events: (eventsData.data ?? []).filter((e: { user_id: string }) => prefsById.has(e.user_id)),
        myRecap: await myRecapPayload(admin, userId),
    });
}

async function myRecapPayload(admin: SupabaseClient, userId: string): Promise<unknown> {
    const { data: latest } = await admin
        .from("friend_activity_events")
        .select("*")
        .eq("user_id", userId)
        .eq("type", "weekly_recap")
        .order("created_at", { ascending: false })
        .limit(1);
    return latest?.[0] ?? null;
}

async function recordActivityEvent(
    admin: SupabaseClient,
    userId: string,
    payload: Record<string, unknown>,
): Promise<Response> {
    const type = String(payload.type ?? "");
    const title = String(payload.title ?? "");
    const subtitle = payload.subtitle == null ? null : String(payload.subtitle);
    const data = (payload.data && typeof payload.data === "object") ? payload.data : {};
    const fanout = payload.fanout !== false;
    if (!type || !title) return json(400, { error: "missing_fields" });

    const { data: inserted, error } = await admin
        .from("friend_activity_events")
        .insert({ user_id: userId, type, title, subtitle, data })
        .select("*")
        .single();
    if (error) return json(500, { error: error.message });

    if (fanout) {
        const followers = await followerIds(admin, userId);
        if (followers.length > 0) {
            const notifRows = followers.map((uid) => ({
                user_id: uid,
                type: `friend_${type}`,
                title,
                body: subtitle ?? "",
                data: { event_id: inserted.id, friend_id: userId, ...(data as Record<string, unknown>) },
            }));
            await admin.from("notifications").insert(notifRows);
            await pushToUsers(admin, followers, title, subtitle ?? "", { event_id: inserted.id, friend_id: userId, type });
        }
    }
    return json(200, { ok: true, event: inserted });
}

async function sendNudge(
    admin: SupabaseClient,
    userId: string,
    payload: Record<string, unknown>,
): Promise<Response> {
    const receiver = String(payload.receiver_id ?? "");
    const kind = String(payload.kind ?? "check");
    const title = String(payload.title ?? "You got a nudge");
    const body = String(payload.body ?? "A friend is checking in.");
    if (!receiver) return json(400, { error: "missing_receiver" });

    // 6-hour cooldown
    const sixHoursAgo = new Date(Date.now() - 6 * 3600 * 1000).toISOString();
    const { data: recent } = await admin
        .from("friend_nudges")
        .select("id")
        .eq("sender_id", userId)
        .eq("receiver_id", receiver)
        .gte("created_at", sixHoursAgo)
        .limit(1);
    if ((recent ?? []).length > 0) return json(429, { error: "cooldown" });

    const { data: inserted, error } = await admin
        .from("friend_nudges")
        .insert({ sender_id: userId, receiver_id: receiver, kind })
        .select("*")
        .single();
    if (error) return json(500, { error: error.message });

    await admin.from("notifications").insert({
        user_id: receiver,
        type: "friend_nudge",
        title,
        body,
        data: { nudge_id: inserted.id, friend_id: userId, kind },
    });
    await pushToUsers(admin, [receiver], title, body, { nudge_id: inserted.id, friend_id: userId, kind, type: "nudge" });
    return json(200, { ok: true, nudge: inserted });
}

async function sendReaction(
    admin: SupabaseClient,
    userId: string,
    payload: Record<string, unknown>,
): Promise<Response> {
    const receiver = String(payload.receiver_id ?? "");
    const target = String(payload.target ?? "");
    const emoji = String(payload.emoji ?? "");
    if (!receiver || !target || !emoji) return json(400, { error: "missing_fields" });
    const { data: inserted, error } = await admin
        .from("friend_reactions")
        .insert({ sender_id: userId, receiver_id: receiver, target, emoji })
        .select("*")
        .single();
    if (error) return json(500, { error: error.message });
    await admin.from("notifications").insert({
        user_id: receiver,
        type: "friend_reaction",
        title: "New reaction",
        body: `Someone reacted ${emoji}`,
        data: { reaction_id: inserted.id, friend_id: userId, emoji, target },
    });
    return json(200, { ok: true, reaction: inserted });
}

async function upsertSharingPrefs(
    admin: SupabaseClient,
    userId: string,
    payload: Record<string, unknown>,
): Promise<Response> {
    const isEnabled = !!payload.is_enabled;
    const audience = String(payload.audience ?? "friends");
    const categories = Array.isArray(payload.categories) ? (payload.categories as unknown[]).map(String) : [];

    // Detect transition off→on
    const { data: existing } = await admin
        .from("stat_sharing_prefs")
        .select("is_enabled")
        .eq("user_id", userId)
        .maybeSingle();
    const wasEnabled = existing?.is_enabled === true;

    const { error } = await admin.from("stat_sharing_prefs").upsert({
        user_id: userId,
        is_enabled: isEnabled,
        audience,
        categories,
        updated_at: new Date().toISOString(),
    }, { onConflict: "user_id" });
    if (error) return json(500, { error: error.message });

    if (!wasEnabled && isEnabled) {
        // Fan out a sharing_on event
        const { data: profile } = await admin.from("profiles").select("display_name").eq("id", userId).maybeSingle();
        const name = profile?.display_name ?? "A friend";
        const { data: inserted } = await admin
            .from("friend_activity_events")
            .insert({
                user_id: userId,
                type: "sharing_on",
                title: `${name} is sharing stats now`,
                subtitle: "Tap to see their progress",
                data: {},
            })
            .select("*")
            .single();
        const followers = await followerIds(admin, userId);
        if (followers.length > 0) {
            const rows = followers.map((uid) => ({
                user_id: uid,
                type: "friend_sharing_on",
                title: `${name} turned on stat sharing`,
                body: "Check out their progress",
                data: { event_id: inserted?.id, friend_id: userId },
            }));
            await admin.from("notifications").insert(rows);
            await pushToUsers(admin, followers, `${name} is sharing stats`, "Check out their progress", { friend_id: userId, type: "sharing_on" });
        }
    }
    return json(200, { ok: true });
}

async function upsertWeeklySnapshot(
    admin: SupabaseClient,
    userId: string,
    payload: Record<string, unknown>,
): Promise<Response> {
    const week = String(payload.week_start ?? isoWeekStart());
    const row = {
        user_id: userId,
        week_start: week,
        weekly_workouts: Number(payload.weekly_workouts ?? 0) | 0,
        weekly_volume_kg: Number(payload.weekly_volume_kg ?? 0) | 0,
        weekly_steps: Number(payload.weekly_steps ?? 0) | 0,
        weekly_calories: Number(payload.weekly_calories ?? 0) | 0,
        weekly_water_ml: Number(payload.weekly_water_ml ?? 0) | 0,
        streak: Number(payload.streak ?? 0) | 0,
        latest_pr: payload.latest_pr == null ? null : String(payload.latest_pr),
        active_program: payload.active_program == null ? null : String(payload.active_program),
        active_protocol: payload.active_protocol == null ? null : String(payload.active_protocol),
        updated_at: new Date().toISOString(),
    };
    const { error } = await admin.from("friend_stat_snapshots").upsert(row, { onConflict: "user_id,week_start" });
    if (error) return json(500, { error: error.message });
    return json(200, { ok: true });
}

async function buildAndStoreRecap(admin: SupabaseClient, userId: string): Promise<unknown> {
    const lastWeek = previousIsoWeekStart();
    const thisWeek = isoWeekStart();
    const { data: rows } = await admin
        .from("friend_stat_snapshots")
        .select("*")
        .eq("user_id", userId)
        .in("week_start", [lastWeek, thisWeek]);
    const last = (rows ?? []).find((r: { week_start: string }) => r.week_start === lastWeek);
    const prev = (rows ?? []).find((r: { week_start: string }) => r.week_start === thisWeek);
    if (!last) return null;

    const workouts = last.weekly_workouts ?? 0;
    const volume = last.weekly_volume_kg ?? 0;
    const steps = last.weekly_steps ?? 0;
    const streak = last.streak ?? 0;
    const data = {
        week_start: lastWeek,
        weekly_workouts: workouts,
        weekly_volume_kg: volume,
        weekly_steps: steps,
        weekly_calories: last.weekly_calories ?? 0,
        weekly_water_ml: last.weekly_water_ml ?? 0,
        streak,
        latest_pr: last.latest_pr,
        prev_workouts: prev?.weekly_workouts ?? 0,
        prev_volume_kg: prev?.weekly_volume_kg ?? 0,
        prev_steps: prev?.weekly_steps ?? 0,
    };
    const title = `Your week: ${workouts} workouts`;
    const subtitle = volume > 0 ? `${(volume / 1000).toFixed(1)}t lifted · ${streak}d streak` : `${steps.toLocaleString()} steps · ${streak}d streak`;

    const { data: inserted } = await admin
        .from("friend_activity_events")
        .insert({ user_id: userId, type: "weekly_recap", title, subtitle, data })
        .select("*")
        .single();

    await admin.from("notifications").insert({
        user_id: userId,
        type: "weekly_recap",
        title: "Your weekly recap is ready",
        body: subtitle,
        data: { event_id: inserted?.id },
    });
    await pushToUsers(admin, [userId], "Your weekly recap is ready", subtitle, { type: "weekly_recap", event_id: inserted?.id });
    return inserted;
}

async function weeklyRecap(admin: SupabaseClient, userId: string): Promise<Response> {
    const inserted = await buildAndStoreRecap(admin, userId);
    return json(200, { ok: true, event: inserted });
}

async function weeklyRecapAll(admin: SupabaseClient, payload: Record<string, unknown>): Promise<Response> {
    const cronSecret = Deno.env.get("CRON_SECRET");
    if (cronSecret && payload.secret !== cronSecret) return json(401, { error: "unauthorized" });
    const lastWeek = previousIsoWeekStart();
    const { data: users } = await admin
        .from("friend_stat_snapshots")
        .select("user_id")
        .eq("week_start", lastWeek);
    const ids = Array.from(new Set((users ?? []).map((u: { user_id: string }) => u.user_id)));
    let count = 0;
    for (const id of ids) {
        await buildAndStoreRecap(admin, id);
        count += 1;
    }
    return json(200, { ok: true, count });
}

async function sendPushAction(
    admin: SupabaseClient,
    _userId: string,
    payload: Record<string, unknown>,
): Promise<Response> {
    const userIds = Array.isArray(payload.user_ids) ? (payload.user_ids as unknown[]).map(String) : [];
    const title = String(payload.title ?? "");
    const body = String(payload.body ?? "");
    const data = (payload.data && typeof payload.data === "object") ? payload.data as Record<string, unknown> : {};
    if (userIds.length === 0 || !title) return json(400, { error: "missing_fields" });
    const result = await pushToUsers(admin, userIds, title, body, data);
    return json(200, { ok: true, ...result });
}

// ---- Handler: deleteAccount (GDPR / App Store requirement) -----------

async function deleteAccount(
    admin: SupabaseClient,
    userId: string,
): Promise<Response> {
    // 1) Wipe every public.<table> row keyed to the user via the SECURITY
    //    DEFINER helper. Catches every table that has a `user_id` column,
    //    so we don't have to maintain a hand-curated list as the schema grows.
    try {
        const { error: rpcErr } = await admin.rpc("delete_user_data", { target_user_id: userId });
        if (rpcErr) {
            console.error("delete_user_data rpc failed", rpcErr);
            return json(500, { error: rpcErr.message });
        }
    } catch (e) {
        console.error("delete_user_data threw", e);
        return json(500, { error: String(e) });
    }

    // 2) Storage objects in per-user folders.
    const buckets = ["avatars", "banners", "body-progress", "meal-photos", "dm-media", "protocol-note-photos"];
    for (const bucket of buckets) {
        try {
            const { data: files } = await admin.storage.from(bucket).list(userId, { limit: 1000 });
            if (!files || files.length === 0) continue;
            const paths = files.map((f) => `${userId}/${f.name}`);
            const { error: rmErr } = await admin.storage.from(bucket).remove(paths);
            if (rmErr) console.error(`storage remove ${bucket} failed`, rmErr);
        } catch (e) {
            console.error(`storage cleanup ${bucket} threw`, e);
        }
    }

    // 3) Delete the auth.users row last so the client gets signed out.
    const { error: authErr } = await admin.auth.admin.deleteUser(userId);
    if (authErr) {
        console.error("auth deleteUser failed", authErr);
        return json(500, { error: authErr.message });
    }

    return json(200, { ok: true, deleted_user_id: userId });
}

// ---- Handler: logClientError -----------------------------------------

async function logClientError(
    admin: SupabaseClient,
    userId: string,
    payload: Record<string, unknown>,
): Promise<Response> {
    const message = String(payload.message ?? "").slice(0, 4000);
    if (!message) return json(400, { error: "missing_message" });
    const row = {
        user_id: userId,
        platform: String(payload.platform ?? "ios"),
        app_version: payload.app_version == null ? null : String(payload.app_version),
        os_version: payload.os_version == null ? null : String(payload.os_version),
        device_model: payload.device_model == null ? null : String(payload.device_model),
        screen: payload.screen == null ? null : String(payload.screen),
        severity: String(payload.severity ?? "error"),
        message,
        stack: payload.stack == null ? null : String(payload.stack).slice(0, 8000),
        context: (payload.context && typeof payload.context === "object") ? payload.context : {},
    };
    const { error } = await admin.from("client_errors").insert(row);
    if (error) return json(500, { error: error.message });
    return json(200, { ok: true });
}

// ---- Entry point ------------------------------------------------------

Deno.serve(async (req) => {
    if (req.method === "OPTIONS") {
        return new Response(null, { status: 204, headers: CORS_HEADERS });
    }

    try {
        const supabaseUrl = Deno.env.get("SUPABASE_URL");
        const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
        if (!supabaseUrl || !serviceRoleKey) {
            return json(500, { error: "server_misconfigured" });
        }

        const admin = createClient(supabaseUrl, serviceRoleKey, {
            auth: { autoRefreshToken: false, persistSession: false },
        });

        const auth = await requireUser(req, admin);
        if ("response" in auth) return auth.response;

        let body: { action?: unknown; payload?: unknown } = {};
        try {
            body = await req.json();
        } catch (_) {
            body = {};
        }

        const action = typeof body.action === "string" ? body.action : "";
        const payload = (body.payload && typeof body.payload === "object")
            ? body.payload as Record<string, unknown>
            : {};

        switch (action) {
            case "ping":
                return json(200, { ok: true, version: "seed-v2", action: "ping" });
            case "seedTestFriends":
                return await seedTestFriends(admin, auth.userId, payload);
            case "clearTestFriends":
                return await clearTestFriends(admin);
            case "friendsFeed":
                return await friendsFeed(admin, auth.userId);
            case "recordActivityEvent":
                return await recordActivityEvent(admin, auth.userId, payload);
            case "sendNudge":
                return await sendNudge(admin, auth.userId, payload);
            case "sendReaction":
                return await sendReaction(admin, auth.userId, payload);
            case "upsertSharingPrefs":
                return await upsertSharingPrefs(admin, auth.userId, payload);
            case "upsertWeeklySnapshot":
                return await upsertWeeklySnapshot(admin, auth.userId, payload);
            case "weeklyRecap":
                return await weeklyRecap(admin, auth.userId);
            case "weeklyRecapAll":
                return await weeklyRecapAll(admin, payload);
            case "sendPush":
                return await sendPushAction(admin, auth.userId, payload);
            case "deleteAccount":
                return await deleteAccount(admin, auth.userId);
            case "logClientError":
                return await logClientError(admin, auth.userId, payload);
            default:
                return json(400, { error: "unknown_action", action });
        }
    } catch (err) {
        console.error("super-action error", err);
        return json(500, { error: String(err) });
    }
});
