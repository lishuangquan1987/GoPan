package schema

import (
	"entgo.io/ent"
	"entgo.io/ent/schema/field"
	"time"
)

// FileHash holds the schema definition for the FileHash entity.
type FileHash struct {
	ent.Schema
}

// Fields of the FileHash.
func (FileHash) Fields() []ent.Field {
	return []ent.Field{
		field.String("hash").Unique().NotEmpty().Comment("File hash (MD5 or SHA256)"),
		field.String("minio_object").NotEmpty().Comment("MinIO object name/path"),
		field.Int64("size").Comment("File size in bytes"),
		field.String("mime_type").Optional().Comment("MIME type"),
		field.Int("reference_count").Default(1).Comment("Number of files referencing this hash"),
		field.Time("created_at").Default(time.Now),
		field.Time("updated_at").Default(time.Now).UpdateDefault(time.Now),
	}
}

// Edges of the FileHash.
func (FileHash) Edges() []ent.Edge {
	return nil
}

