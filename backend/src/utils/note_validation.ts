export const notePayloadLimits = {
  title: 200,
  content: 100_000,
  excerpt: 500,
  category: 80,
  tagLabel: 80,
  tagsPerNote: 24,
  folderName: 120,
  folderId: 128,
  colorKey: 40,
  emoji: 16,
  id: 128,
  timestamp: 64,
  syncNotesPerPush: 100,
  syncFoldersPerPush: 100,
  syncTagsPerPush: 100,
  syncDeletesPerPush: 200,
} as const;

type ValidationResult<T> =
  | {
      ok: true;
      value: T;
    }
  | {
      ok: false;
      message: string;
    };

export type ValidatedNoteWritePayload = {
  title?: string;
  content?: string;
  excerpt?: string;
  category?: string;
  tags?: string[];
  folder_id?: string | null;
  color_key?: string;
  emoji?: string;
  is_pinned?: boolean;
  is_favorite?: boolean;
  is_archived?: boolean;
  is_deleted?: boolean;
  deleted_at?: string | null;
};

export type ValidatedSyncNotePayload = ValidatedNoteWritePayload & {
  id?: string;
  created_at?: string;
  updated_at?: string;
};

export type ValidatedSyncFolderPayload = {
  id: string;
  name: string;
  color_key?: string;
  emoji?: string;
  created_at?: string;
  updated_at?: string;
};

export type ValidatedSyncTagPayload = {
  id: string;
  label: string;
  emoji?: string;
  created_at?: string;
  updated_at?: string;
};

export type ValidatedSyncDeletePayload = {
  id: string;
  deleted_at?: string;
};

export function validateCreateNotePayload(
  rawPayload: unknown,
): ValidationResult<
  Required<Pick<ValidatedNoteWritePayload, "title" | "content">> &
    Omit<ValidatedNoteWritePayload, "title" | "content">
> {
  const payload = objectPayload(rawPayload);
  if (!payload.ok) {
    return payload;
  }

  const validated = validateBaseNoteFields(payload.value, false);
  if (!validated.ok) {
    return validated;
  }

  const title = validated.value.title ?? "";
  const content = validated.value.content ?? "";
  if (!title && !content.trim()) {
    return {
      ok: false,
      message: "Title or content is required",
    };
  }

  return {
    ok: true,
    value: {
      ...validated.value,
      title,
      content,
    },
  };
}

export function validatePatchNotePayload(
  rawPayload: unknown,
): ValidationResult<ValidatedNoteWritePayload> {
  const payload = objectPayload(rawPayload);
  if (!payload.ok) {
    return payload;
  }

  return validateBaseNoteFields(payload.value, true);
}

export function validateSyncNotePayload(
  rawPayload: unknown,
): ValidationResult<ValidatedSyncNotePayload> {
  const payload = objectPayload(rawPayload);
  if (!payload.ok) {
    return payload;
  }

  const validated = validateBaseNoteFields(payload.value, true);
  if (!validated.ok) {
    return validated;
  }

  const id = optionalString(payload.value, "id", notePayloadLimits.id, true);
  if (!id.ok) {
    return id;
  }

  const createdAt = optionalString(
    payload.value,
    "created_at",
    notePayloadLimits.timestamp,
    true,
  );
  if (!createdAt.ok) {
    return createdAt;
  }

  const updatedAt = optionalString(
    payload.value,
    "updated_at",
    notePayloadLimits.timestamp,
    true,
  );
  if (!updatedAt.ok) {
    return updatedAt;
  }

  return {
    ok: true,
    value: {
      ...validated.value,
      ...(id.value !== undefined ? { id: id.value } : {}),
      ...(createdAt.value !== undefined ? { created_at: createdAt.value } : {}),
      ...(updatedAt.value !== undefined ? { updated_at: updatedAt.value } : {}),
    },
  };
}

export function validateSyncFolderPayload(
  rawPayload: unknown,
): ValidationResult<ValidatedSyncFolderPayload> {
  const payload = objectPayload(rawPayload);
  if (!payload.ok) {
    return payload;
  }

  const id = requiredString(payload.value, "id", notePayloadLimits.id, true);
  if (!id.ok) {
    return id;
  }

  const name = requiredString(
    payload.value,
    "name",
    notePayloadLimits.folderName,
    true,
  );
  if (!name.ok) {
    return name;
  }

  const colorKey = optionalString(
    payload.value,
    "color_key",
    notePayloadLimits.colorKey,
    true,
  );
  if (!colorKey.ok) {
    return colorKey;
  }

  const emoji = optionalString(payload.value, "emoji", notePayloadLimits.emoji, true);
  if (!emoji.ok) {
    return emoji;
  }

  const createdAt = optionalString(
    payload.value,
    "created_at",
    notePayloadLimits.timestamp,
    true,
  );
  if (!createdAt.ok) {
    return createdAt;
  }

  const updatedAt = optionalString(
    payload.value,
    "updated_at",
    notePayloadLimits.timestamp,
    true,
  );
  if (!updatedAt.ok) {
    return updatedAt;
  }

  return {
    ok: true,
    value: {
      id: id.value,
      name: name.value,
      ...(colorKey.value !== undefined ? { color_key: colorKey.value } : {}),
      ...(emoji.value !== undefined ? { emoji: emoji.value } : {}),
      ...(createdAt.value !== undefined ? { created_at: createdAt.value } : {}),
      ...(updatedAt.value !== undefined ? { updated_at: updatedAt.value } : {}),
    },
  };
}

export function validateSyncTagPayload(
  rawPayload: unknown,
): ValidationResult<ValidatedSyncTagPayload> {
  const payload = objectPayload(rawPayload);
  if (!payload.ok) {
    return payload;
  }

  const id = requiredString(payload.value, "id", notePayloadLimits.id, true);
  if (!id.ok) {
    return id;
  }

  const label = requiredString(
    payload.value,
    "label",
    notePayloadLimits.tagLabel,
    true,
  );
  if (!label.ok) {
    return label;
  }

  const emoji = optionalString(payload.value, "emoji", notePayloadLimits.emoji, true);
  if (!emoji.ok) {
    return emoji;
  }

  const createdAt = optionalString(
    payload.value,
    "created_at",
    notePayloadLimits.timestamp,
    true,
  );
  if (!createdAt.ok) {
    return createdAt;
  }

  const updatedAt = optionalString(
    payload.value,
    "updated_at",
    notePayloadLimits.timestamp,
    true,
  );
  if (!updatedAt.ok) {
    return updatedAt;
  }

  return {
    ok: true,
    value: {
      id: id.value,
      label: label.value,
      ...(emoji.value !== undefined ? { emoji: emoji.value } : {}),
      ...(createdAt.value !== undefined ? { created_at: createdAt.value } : {}),
      ...(updatedAt.value !== undefined ? { updated_at: updatedAt.value } : {}),
    },
  };
}

export function validateSyncDeletePayload(
  rawPayload: unknown,
): ValidationResult<ValidatedSyncDeletePayload> {
  const payload = objectPayload(rawPayload);
  if (!payload.ok) {
    return payload;
  }

  const id = requiredString(payload.value, "id", notePayloadLimits.id, true);
  if (!id.ok) {
    return id;
  }

  const deletedAt = optionalString(
    payload.value,
    "deleted_at",
    notePayloadLimits.timestamp,
    true,
  );
  if (!deletedAt.ok) {
    return deletedAt;
  }

  return {
    ok: true,
    value: {
      id: id.value,
      ...(deletedAt.value !== undefined ? { deleted_at: deletedAt.value } : {}),
    },
  };
}

function validateBaseNoteFields(
  payload: Record<string, unknown>,
  allowMissingTitleAndContent: boolean,
): ValidationResult<ValidatedNoteWritePayload> {
  const title = optionalString(payload, "title", notePayloadLimits.title, true);
  if (!title.ok) {
    return title;
  }

  const content = optionalString(
    payload,
    "content",
    notePayloadLimits.content,
    false,
  );
  if (!content.ok) {
    return content;
  }

  if (
    !allowMissingTitleAndContent &&
    title.value === undefined &&
    content.value === undefined
  ) {
    return {
      ok: false,
      message: "Title or content is required",
    };
  }

  const excerpt = optionalString(
    payload,
    "excerpt",
    notePayloadLimits.excerpt,
    true,
  );
  if (!excerpt.ok) {
    return excerpt;
  }

  const category = optionalString(
    payload,
    "category",
    notePayloadLimits.category,
    true,
  );
  if (!category.ok) {
    return category;
  }

  const tags = optionalStringArray(
    payload,
    "tags",
    notePayloadLimits.tagsPerNote,
    notePayloadLimits.tagLabel,
  );
  if (!tags.ok) {
    return tags;
  }

  const folderId = optionalNullableString(
    payload,
    "folder_id",
    notePayloadLimits.folderId,
    true,
  );
  if (!folderId.ok) {
    return folderId;
  }

  const colorKey = optionalString(
    payload,
    "color_key",
    notePayloadLimits.colorKey,
    true,
  );
  if (!colorKey.ok) {
    return colorKey;
  }

  const emoji = optionalString(payload, "emoji", notePayloadLimits.emoji, true);
  if (!emoji.ok) {
    return emoji;
  }

  const deletedAt = optionalNullableString(
    payload,
    "deleted_at",
    notePayloadLimits.timestamp,
    true,
  );
  if (!deletedAt.ok) {
    return deletedAt;
  }

  const booleans = validateOptionalBooleans(payload, [
    "is_pinned",
    "is_favorite",
    "is_archived",
    "is_deleted",
  ]);
  if (!booleans.ok) {
    return booleans;
  }

  return {
    ok: true,
    value: {
      ...(title.value !== undefined ? { title: title.value } : {}),
      ...(content.value !== undefined ? { content: content.value } : {}),
      ...(excerpt.value !== undefined ? { excerpt: excerpt.value } : {}),
      ...(category.value !== undefined ? { category: category.value } : {}),
      ...(tags.value !== undefined ? { tags: tags.value } : {}),
      ...(folderId.value !== undefined ? { folder_id: folderId.value } : {}),
      ...(colorKey.value !== undefined ? { color_key: colorKey.value } : {}),
      ...(emoji.value !== undefined ? { emoji: emoji.value } : {}),
      ...(deletedAt.value !== undefined
        ? { deleted_at: deletedAt.value }
        : {}),
      ...booleans.value,
    },
  };
}

function objectPayload(
  rawPayload: unknown,
): ValidationResult<Record<string, unknown>> {
  if (
    rawPayload === null ||
    typeof rawPayload !== "object" ||
    Array.isArray(rawPayload)
  ) {
    return {
      ok: false,
      message: "Request body must be a JSON object",
    };
  }

  return {
    ok: true,
    value: rawPayload as Record<string, unknown>,
  };
}

function optionalString(
  payload: Record<string, unknown>,
  field: string,
  maxLength: number,
  trim: boolean,
): ValidationResult<string | undefined> {
  const raw = payload[field];
  if (raw === undefined) {
    return { ok: true, value: undefined };
  }

  if (typeof raw !== "string") {
    return {
      ok: false,
      message: `${field} must be a string`,
    };
  }

  const value = trim ? raw.trim() : raw;
  if (value.length > maxLength) {
    return {
      ok: false,
      message: `${field} must be ${maxLength} characters or fewer`,
    };
  }

  return {
    ok: true,
    value,
  };
}

function requiredString(
  payload: Record<string, unknown>,
  field: string,
  maxLength: number,
  trim: boolean,
): ValidationResult<string> {
  const value = optionalString(payload, field, maxLength, trim);
  if (!value.ok) {
    return value;
  }

  if (value.value === undefined || value.value.length === 0) {
    return {
      ok: false,
      message: `${field} is required`,
    };
  }

  return {
    ok: true,
    value: value.value,
  };
}

function optionalNullableString(
  payload: Record<string, unknown>,
  field: string,
  maxLength: number,
  trim: boolean,
): ValidationResult<string | null | undefined> {
  if (payload[field] === null) {
    return {
      ok: true,
      value: null,
    };
  }

  return optionalString(payload, field, maxLength, trim);
}

function validateOptionalBooleans(
  payload: Record<string, unknown>,
  fields: string[],
): ValidationResult<Record<string, boolean>> {
  const values: Record<string, boolean> = {};

  for (const field of fields) {
    const raw = payload[field];
    if (raw === undefined) {
      continue;
    }

    if (typeof raw !== "boolean") {
      return {
        ok: false,
        message: `${field} must be a boolean`,
      };
    }

    values[field] = raw;
  }

  return {
    ok: true,
    value: values,
  };
}

function optionalStringArray(
  payload: Record<string, unknown>,
  field: string,
  maxItems: number,
  maxItemLength: number,
): ValidationResult<string[] | undefined> {
  const raw = payload[field];
  if (raw === undefined) {
    return {
      ok: true,
      value: undefined,
    };
  }

  if (!Array.isArray(raw)) {
    return {
      ok: false,
      message: `${field} must be an array`,
    };
  }

  if (raw.length > maxItems) {
    return {
      ok: false,
      message: `${field} must contain ${maxItems} items or fewer`,
    };
  }

  const normalized: string[] = [];
  for (const entry of raw) {
    if (typeof entry !== "string") {
      return {
        ok: false,
        message: `${field} items must be strings`,
      };
    }

    const value = entry.trim();
    if (value.length === 0) {
      continue;
    }

    if (value.length > maxItemLength) {
      return {
        ok: false,
        message: `${field} items must be ${maxItemLength} characters or fewer`,
      };
    }

    if (!normalized.includes(value)) {
      normalized.push(value);
    }
  }

  return {
    ok: true,
    value: normalized,
  };
}
