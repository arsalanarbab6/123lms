// =====================================================
// CyberEdge Academy — Supabase Client (shared file)
// Included in EVERY page via <script> tag
// =====================================================

const SUPABASE_URL = "https://bxldognxqykyvqtqxiga.supabase.co";
const SUPABASE_KEY  = "sb_publishable_xfaNK_mPjXOtV4owY0qIhg_a8L3J3t8";

const sb = supabase.createClient(SUPABASE_URL, SUPABASE_KEY);

// ---- Auth helpers ----

async function getUser() {
  const { data: { session } } = await sb.auth.getSession();
  return session ? session.user : null;
}

async function getProfile(uid) {
  const { data } = await sb.from("profiles").select("*").eq("id", uid).single();
  return data;
}

async function requireAuth(redirect = "/public/login.html") {
  const user = await getUser();
  if (!user) { window.location.href = redirect; return null; }
  return user;
}

async function requireRole(roles, redirect = "/student/dashboard.html") {
  const user = await getUser();
  if (!user) { window.location.href = "/public/login.html"; return null; }
  const profile = await getProfile(user.id);
  if (!profile || !roles.includes(profile.role)) {
    window.location.href = redirect; return null;
  }
  return { user, profile };
}

async function signOut() {
  await sb.auth.signOut();
  window.location.href = "/public/login.html";
}

// ---- Nav helper — updates nav buttons based on login state ----
async function setupNav() {
  const user = await getUser();
  const navAuth = document.getElementById("nav-auth");
  if (!navAuth) return;
  if (user) {
    const profile = await getProfile(user.id);
    const dashUrl = profile?.role === "admin" ? "/admin/dashboard.html"
                  : profile?.role === "instructor" ? "/instructor/dashboard.html"
                  : "/student/dashboard.html";
    navAuth.innerHTML = `
      <a href="${dashUrl}" class="px-5 py-2 rounded-lg font-bold text-sm bg-gradient text-white">My Dashboard</a>
      <button onclick="signOut()" class="px-5 py-2 rounded-lg font-bold text-sm border border-slate-200 ml-2">Logout</button>`;
  } else {
    navAuth.innerHTML = `
      <a href="/public/login.html"  class="px-5 py-2 rounded-lg font-bold text-sm border border-slate-200">Login</a>
      <a href="/public/signup.html" class="px-5 py-2 rounded-lg font-bold text-sm bg-gradient text-white ml-2">Sign Up</a>`;
  }
}
