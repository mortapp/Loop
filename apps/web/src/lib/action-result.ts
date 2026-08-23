export type ActionResult = { error: string } | null;

export type BoundAction = (
  previousState: ActionResult,
  formData: FormData,
) => Promise<ActionResult>;
