(() => {
 const c=window.RP_ADMIN_CONFIG||{}, msg=document.getElementById("global-message");
 if(!window.supabase||!c.SUPABASE_URL||!c.SUPABASE_PUBLISHABLE_KEY){msg.textContent="Configuration missing. Verify admin-config.js.";return}
 const db=window.supabase.createClient(c.SUPABASE_URL,c.SUPABASE_PUBLISHABLE_KEY);let user=null;
 async function init(){
  const {data,error}=await db.auth.getUser();if(error||!data?.user){location.href="admin-login.html";return}user=data.user;
  const {data:admin,error:ae}=await db.from("admin_users").select("role,active").eq("user_id",user.id).eq("active",true).maybeSingle();
  if(ae||!admin){await db.auth.signOut();location.href="admin-login.html";return}
  document.getElementById("admin-identity").textContent=`Signed in as ${user.email||"authorized user"} · Role: ${admin.role}`;
  document.getElementById("welcome-title").textContent=admin.role==="primary_admin"?"Welcome back, Director":"Admin Dashboard";
  await load();
 }
 async function load(){
  const {data,error}=await db.from("site_settings").select("key,value").in("key",["content_notes","seo_title","canonical_url","seo_description","local_seo","announcement"]);
  if(error){msg.textContent="Draft settings table is not ready. Schema has not been installed by this starter.";document.getElementById("draft-count").textContent="0";return}
  const s=Object.fromEntries((data||[]).map(r=>[r.key,r.value]));
  for(const [id,key] of [["content-notes","content_notes"],["seo-title","seo_title"],["canonical-url","canonical_url"],["seo-description","seo_description"],["local-seo","local_seo"],["announcement","announcement"]])document.getElementById(id).value=s[key]||"";
  document.getElementById("draft-count").textContent=String((data||[]).length);
 }
 async function save(values){
  msg.textContent="Saving draft…";
  const rows=Object.entries(values).map(([key,value])=>({key,value,updated_by:user.id,updated_at:new Date().toISOString()}));
  const {error}=await db.from("site_settings").upsert(rows,{onConflict:"key"});
  msg.textContent=error?"Draft save failed. Confirm schema and permissions.":"Draft saved in Supabase. Public website is not changed.";
  if(!error)await load();
 }
 document.getElementById("save-content").addEventListener("click",()=>save({content_notes:document.getElementById("content-notes").value.trim()}));
 document.getElementById("save-seo").addEventListener("click",()=>save({seo_title:document.getElementById("seo-title").value.trim(),canonical_url:document.getElementById("canonical-url").value.trim(),seo_description:document.getElementById("seo-description").value.trim(),local_seo:document.getElementById("local-seo").value.trim()}));
 document.getElementById("save-announcement").addEventListener("click",()=>save({announcement:document.getElementById("announcement").value.trim()}));
 document.getElementById("preview-button").addEventListener("click",()=>{document.getElementById("preview-output").textContent=JSON.stringify({content_notes:document.getElementById("content-notes").value,seo_title:document.getElementById("seo-title").value,canonical_url:document.getElementById("canonical-url").value,seo_description:document.getElementById("seo-description").value,local_seo:document.getElementById("local-seo").value,announcement:document.getElementById("announcement").value,status:"Draft only; not published."},null,2)});
 document.getElementById("logout-button").addEventListener("click",async()=>{await db.auth.signOut();location.href="admin-login.html"});init();
})();
