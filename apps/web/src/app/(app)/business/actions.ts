"use server";

import { revalidatePath } from "next/cache";
import { createClient } from "@/lib/supabase/server";
import { setActiveAccountId } from "@/lib/active-account";

export type CreateBusinessState = { error: string } | null;

function slugify(name: string): string {
  return name
    .toLowerCase()
    .trim()
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/(^-|-$)+/g, "");
}

export async function createBusiness(
  _prev: CreateBusinessState,
  formData: FormData,
): Promise<CreateBusinessState> {
  const name = String(formData.get("name") ?? "").trim();
  if (!name) {
    return { error: "Business name is required." };
  }

  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) {
    return { error: "Not signed in." };
  }

  const slug = `${slugify(name)}-${Math.random().toString(36).slice(2, 6)}`;

  const { error } = await supabase.from("businesses").insert({
    name,
    slug,
    created_by: user.id,
  });

  if (error) {
    return { error: error.message };
  }

  revalidatePath("/business");
  return null;
}

export async function switchActiveAccount(formData: FormData): Promise<void> {
  const accountId = String(formData.get("accountId") ?? "");
  if (!accountId) {
    return;
  }

  await setActiveAccountId(accountId);
  revalidatePath("/", "layout");
}
