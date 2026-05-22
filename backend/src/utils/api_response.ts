export const successResponse = <T>(data: T, message: string | null = null) => ({
  success: true,
  data,
  message,
});

export const errorResponse = (message: string) => ({
  success: false,
  data: null,
  message,
});

export function noteFromRow(row: Record<string, unknown>) {
  return {
    ...row,
    is_pinned: row.is_pinned === 1,
    is_favorite: row.is_favorite === 1,
    is_archived: row.is_archived === 1,
    is_deleted: row.is_deleted === 1,
  };
}
