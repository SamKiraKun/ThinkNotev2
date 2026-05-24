const assert = require("node:assert/strict");

const {
  notePayloadLimits,
  validateCreateNotePayload,
  validateSyncDeletePayload,
  validatePatchNotePayload,
  validateSyncFolderPayload,
  validateSyncNotePayload,
  validateSyncTagPayload,
} = require("../dist/utils/note_validation.js");

function expectOk(result, message) {
  assert.equal(result.ok, true, message);
  return result.value;
}

function expectInvalid(result, expectedMessage) {
  assert.equal(result.ok, false);
  assert.match(result.message, expectedMessage);
}

const createPayload = expectOk(
  validateCreateNotePayload({
    title: "  Launch checklist  ",
    content: "Keep the release small and verifiable.",
    category: "Production",
    folder_id: null,
    is_pinned: true,
  }),
  "create payload should accept a valid local note",
);

assert.equal(createPayload.title, "Launch checklist");
assert.equal(createPayload.content, "Keep the release small and verifiable.");
assert.equal(createPayload.folder_id, null);
assert.equal(createPayload.is_pinned, true);
assert.deepEqual(createPayload.tags, undefined);

expectInvalid(
  validateCreateNotePayload({ title: "   ", content: "" }),
  /required/,
);
expectInvalid(validateCreateNotePayload(null), /JSON object/);
expectInvalid(validateCreateNotePayload([]), /JSON object/);
expectInvalid(
  validateCreateNotePayload({
    title: "a".repeat(notePayloadLimits.title + 1),
  }),
  /title must be 200 characters or fewer/,
);

const patchPayload = expectOk(
  validatePatchNotePayload({
    title: "Updated",
    content: "",
    is_favorite: false,
    deleted_at: null,
    tags: ["Work", "Launch", "Work"],
  }),
  "patch payload should allow explicit empty content and nullable deletion time",
);

assert.equal(patchPayload.title, "Updated");
assert.equal(patchPayload.content, "");
assert.equal(patchPayload.is_favorite, false);
assert.equal(patchPayload.deleted_at, null);
assert.deepEqual(patchPayload.tags, ["Work", "Launch"]);

expectInvalid(
  validatePatchNotePayload({ is_archived: "yes" }),
  /is_archived must be a boolean/,
);
expectInvalid(
  validatePatchNotePayload({
    folder_id: "f".repeat(notePayloadLimits.folderId + 1),
  }),
  /folder_id must be 128 characters or fewer/,
);
expectInvalid(
  validatePatchNotePayload({
    tags: new Array(notePayloadLimits.tagsPerNote + 1).fill("x"),
  }),
  /tags must contain 24 items or fewer/,
);

const syncPayload = expectOk(
  validateSyncNotePayload({
    id: "note-1",
    title: "Synced later",
    content: "Prepared for future sync validation.",
    created_at: "2026-05-24T00:00:00.000Z",
    updated_at: "2026-05-24T00:01:00.000Z",
  }),
  "sync payload should keep accepted identifiers and timestamps",
);

assert.equal(syncPayload.id, "note-1");
assert.equal(syncPayload.created_at, "2026-05-24T00:00:00.000Z");
assert.equal(syncPayload.updated_at, "2026-05-24T00:01:00.000Z");

expectInvalid(
  validateSyncNotePayload({ id: "x".repeat(notePayloadLimits.id + 1) }),
  /id must be 128 characters or fewer/,
);

const syncFolderPayload = expectOk(
  validateSyncFolderPayload({
    id: "folder-1",
    name: "Work",
    color_key: "work",
    emoji: "W",
  }),
  "sync folder payload should accept a valid folder",
);

assert.equal(syncFolderPayload.id, "folder-1");
assert.equal(syncFolderPayload.name, "Work");

const syncTagPayload = expectOk(
  validateSyncTagPayload({
    id: "tag-1",
    label: "Launch",
    emoji: "#",
  }),
  "sync tag payload should accept a valid tag",
);

assert.equal(syncTagPayload.id, "tag-1");
assert.equal(syncTagPayload.label, "Launch");

expectInvalid(validateSyncFolderPayload({ name: "No id" }), /id is required/);
expectInvalid(validateSyncTagPayload({ id: "tag-1" }), /label is required/);

const syncDeletePayload = expectOk(
  validateSyncDeletePayload({
    id: "note-1",
    deleted_at: "2026-05-24T00:02:00.000Z",
  }),
  "sync delete payload should accept a valid delete marker",
);

assert.equal(syncDeletePayload.id, "note-1");
assert.equal(syncDeletePayload.deleted_at, "2026-05-24T00:02:00.000Z");

expectInvalid(
  validateSyncDeletePayload({ deleted_at: "2026-05-24T00:02:00.000Z" }),
  /id is required/,
);

console.log("note payload validation checks passed");
