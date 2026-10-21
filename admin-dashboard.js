(() => {
  "use strict";

  const c = window.RP_ADMIN_CONFIG || {};
  const msg = document.getElementById("global-message");
  const enquiryMsg = document.getElementById("enquiry-message");

  if (
    !window.supabase ||
    !c.SUPABASE_URL ||
    !c.SUPABASE_PUBLISHABLE_KEY
  ) {
    if (msg) msg.textContent = "Configuration missing. Verify admin-config.js.";
    return;
  }

  const db = window.supabase.createClient(
    c.SUPABASE_URL,
    c.SUPABASE_PUBLISHABLE_KEY
  );

  let user = null;
  let admin = null;
  let enquiryType = "admission";
  let allEnquiries = [];

  const $ = id => document.getElementById(id);

  function setEnquiryMessage(text) {
    if (enquiryMsg) enquiryMsg.textContent = text;
  }

  async function init() {
    const { data, error } = await db.auth.getUser();

    if (error || !data?.user) {
      location.href = "admin-login.html";
      return;
    }

    user = data.user;

    const { data: adminRow, error: adminError } = await db
      .from("admin_users")
      .select("role,active")
      .eq("user_id", user.id)
      .eq("active", true)
      .maybeSingle();

    if (adminError || !adminRow) {
      await db.auth.signOut();
      location.href = "admin-login.html";
      return;
    }

    admin = adminRow;

    $("admin-identity").textContent =
      `Signed in as ${user.email || "authorized user"} · Role: ${admin.role}`;

    $("welcome-title").textContent =
      admin.role === "primary_admin"
        ? "Welcome back, Director"
        : "Admin Dashboard";

    await loadSettings();

    // Enquiry history is Director-only.
    if (admin.role === "primary_admin") {
      await loadEnquiries();
    } else {
      setEnquiryMessage("Enquiry history is restricted to the Director.");
      if ($("enquiries")) $("enquiries").hidden = true;
      const link = document.querySelector('a[href="#enquiries"]');
      if (link) link.hidden = true;
    }
  }

  async function loadSettings() {
    const { data, error } = await db
      .from("site_settings")
      .select("key,value")
      .in("key", [
        "content_notes",
        "seo_title",
        "canonical_url",
        "seo_description",
        "local_seo",
        "announcement"
      ]);

    if (error) {
      msg.textContent =
        "Draft settings could not load. Check the site_settings schema and permissions.";
      $("draft-count").textContent = "0";
      return;
    }

    const settings = Object.fromEntries(
      (data || []).map(row => [row.key, row.value])
    );

    [
      ["content-notes", "content_notes"],
      ["seo-title", "seo_title"],
      ["canonical-url", "canonical_url"],
      ["seo-description", "seo_description"],
      ["local-seo", "local_seo"],
      ["announcement", "announcement"]
    ].forEach(([id, key]) => {
      if ($(id)) $(id).value = settings[key] || "";
    });

    $("draft-count").textContent = String((data || []).length);
  }

  async function saveSettings(values) {
    if (!user) return;

    msg.textContent = "Saving draft…";

    const rows = Object.entries(values).map(([key, value]) => ({
      key,
      value,
      updated_by: user.id,
      updated_at: new Date().toISOString()
    }));

    const { error } = await db
      .from("site_settings")
      .upsert(rows, { onConflict: "key" });

    msg.textContent = error
      ? `Draft save failed: ${error.message}`
      : "Draft saved in Supabase. Public website is not changed.";

    if (!error) await loadSettings();
  }

  function addCell(row, value) {
    const cell = document.createElement("td");
    cell.textContent = value == null || value === "" ? "—" : String(value);
    row.appendChild(cell);
    return cell;
  }

  function renderEnquiries() {
    const tbody = $("enquiry-rows");
    if (!tbody) return;

    tbody.replaceChildren();

    const search = ($("enquiry-search")?.value || "").trim().toLowerCase();
    const statusFilter = $("enquiry-status-filter")?.value || "";

    const filtered = allEnquiries.filter(item => {
      const searchable = [
        item.student_name,
        item.mobile,
        item.father_name,
        item.school_name
      ].join(" ").toLowerCase();

      return (
        (!search || searchable.includes(search)) &&
        (!statusFilter || item.status === statusFilter)
      );
    });

    if (!filtered.length) {
      const row = document.createElement("tr");
      const cell = document.createElement("td");
      cell.colSpan = 9;
      cell.textContent = "No enquiries found for these filters.";
      row.appendChild(cell);
      tbody.appendChild(row);
      return;
    }

    filtered.forEach(item => {
      const row = document.createElement("tr");

      addCell(row, item.created_at
        ? new Date(item.created_at).toLocaleString("en-IN")
        : "—");
      addCell(row, item.student_name);
      addCell(row, item.mobile);
      addCell(row, item.class_name);
      addCell(row, item.course || item.exam_mode);
      addCell(row, item.school_name);
      addCell(row, item.district);

      const statusCell = document.createElement("td");
      const statusSelect = document.createElement("select");

      ["pending", "contacted", "converted", "closed"].forEach(status => {
        const option = document.createElement("option");
        option.value = status;
        option.textContent = status.charAt(0).toUpperCase() + status.slice(1);
        statusSelect.appendChild(option);
      });

      statusSelect.value = item.status;
      statusCell.appendChild(statusSelect);
      row.appendChild(statusCell);

      const actionCell = document.createElement("td");
      const updateButton = document.createElement("button");
      updateButton.type = "button";
      updateButton.textContent = "Save status";

      updateButton.addEventListener("click", async () => {
        if (admin?.role !== "primary_admin") {
          setEnquiryMessage("Only the Director can update enquiry status.");
          return;
        }

        updateButton.disabled = true;
        setEnquiryMessage("Updating status…");

        const { error } = await db
          .from("website_enquiries")
          .update({ status: statusSelect.value })
          .eq("id", item.id);

        updateButton.disabled = false;

        if (error) {
          setEnquiryMessage(
            `Status update failed. Check Director policy: ${error.message}`
          );
          return;
        }

        setEnquiryMessage("Enquiry status updated.");
        await loadEnquiries();
      });

      actionCell.appendChild(updateButton);
      row.appendChild(actionCell);
      tbody.appendChild(row);
    });
  }

  async function loadEnquiries() {
    if (admin?.role !== "primary_admin") return;

    setEnquiryMessage("Loading enquiries…");

    const { data, error } = await db
      .from("website_enquiries")
      .select(
        "id,enquiry_type,student_name,father_name,mobile,class_name,course,school_name,message,district,exam_mode,source,status,created_at"
      )
      .eq("enquiry_type", enquiryType)
      .order("created_at", { ascending: false })
      .limit(500);

    if (error) {
      allEnquiries = [];
      renderEnquiries();
      setEnquiryMessage(
        `Could not load enquiries: ${error.message}`
      );
      return;
    }

    allEnquiries = data || [];
    renderEnquiries();
    setEnquiryMessage(
      `${allEnquiries.length} ${enquiryType === "admission" ? "admission enquiries" : "scholarship registrations"} loaded.`
    );
  }

  $("save-content").addEventListener("click", () =>
    saveSettings({
      content_notes: $("content-notes").value.trim()
    })
  );

  $("save-seo").addEventListener("click", () =>
    saveSettings({
      seo_title: $("seo-title").value.trim(),
      canonical_url: $("canonical-url").value.trim(),
      seo_description: $("seo-description").value.trim(),
      local_seo: $("local-seo").value.trim()
    })
  );

  $("save-announcement").addEventListener("click", () =>
    saveSettings({
      announcement: $("announcement").value.trim()
    })
  );

  $("preview-button").addEventListener("click", () => {
    $("preview-output").textContent = JSON.stringify({
      content_notes: $("content-notes").value,
      seo_title: $("seo-title").value,
      canonical_url: $("canonical-url").value,
      seo_description: $("seo-description").value,
      local_seo: $("local-seo").value,
      announcement: $("announcement").value,
      status: "Draft only; not published."
    }, null, 2);
  });

  $("admission-tab")?.addEventListener("click", async () => {
    enquiryType = "admission";
    await loadEnquiries();
  });

  $("scholarship-tab")?.addEventListener("click", async () => {
    enquiryType = "scholarship";
    await loadEnquiries();
  });

  $("refresh-enquiries")?.addEventListener("click", loadEnquiries);
  $("enquiry-search")?.addEventListener("input", renderEnquiries);
  $("enquiry-status-filter")?.addEventListener("change", renderEnquiries);

  $("logout-button").addEventListener("click", async () => {
    await db.auth.signOut();
    location.href = "admin-login.html";
  });

  init();
})();
