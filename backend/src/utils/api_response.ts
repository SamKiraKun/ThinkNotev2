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

export function noteFromRow(
  row: Record<string, unknown>,
  tags: string[] = [],
) {
  return {
    ...row,
    is_pinned: row.is_pinned === 1,
    is_favorite: row.is_favorite === 1,
    is_archived: row.is_archived === 1,
    is_deleted: row.is_deleted === 1,
    tags,
  };
}

export function folderFromRow(row: Record<string, unknown>) {
  return {
    id: row.id,
    name: row.name,
    color_key: row.color_key,
    emoji: row.emoji,
    created_at: row.created_at,
    updated_at: row.updated_at,
    is_system: false,
  };
}

export function tagFromRow(row: Record<string, unknown>) {
  return {
    id: row.id,
    label: row.name,
    emoji: row.emoji,
    created_at: row.created_at,
    updated_at: row.updated_at,
  };
}

export function deletedEntityFromRow(row: Record<string, unknown>) {
  return {
    entity_type: row.entity_type,
    id: row.entity_id,
    deleted_at: row.deleted_at,
  };
}
