(() => {
 const c=window.RP_ADMIN_CONFIG||{}, m=document.getElementById("login-message"), b=document.getElementById("login-button");
 if(!window.supabase||!c.SUPABASE_URL||!c.SUPABASE_PUBLISHABLE_KEY){m.textContent="Configuration missing. Verify admin-config.js.";return}
 const db=window.supabase.createClient(c.SUPABASE_URL,c.SUPABASE_PUBLISHABLE_KEY);
 document.getElementById("login-form").addEventListener("submit",async e=>{
  e.preventDefault();b.disabled=true;m.textContent="Signing in…";
  const {error}=await db.auth.signInWithPassword({email:document.getElementById("email").value.trim(),password:document.getElementById("password").value});
  if(error){m.textContent="Sign-in failed. Check credentials and try again.";b.disabled=false;return}
  const {data}=await db.auth.getUser(), user=data?.user;
  if(!user){await db.auth.signOut();m.textContent="Could not verify account.";b.disabled=false;return}
  const {data:admin,error:ae}=await db.from("admin_users").select("user_id,role,active").eq("user_id",user.id).eq("active",true).maybeSingle();
  if(ae||!admin){await db.auth.signOut();m.textContent="This account is not on the authorized admin list.";b.disabled=false;return}
  location.href="admin-dashboard.html";
 });
})();
