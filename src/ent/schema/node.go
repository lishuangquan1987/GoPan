package schema

import (
	"entgo.io/ent"
	"entgo.io/ent/schema/edge"
	"entgo.io/ent/schema/field"
	"time"
)

// Node holds the schema definition for the Node entity.
type Node struct {
	ent.Schema
}

// Fields of the Node.
func (Node) Fields() []ent.Field {
	return []ent.Field{
		field.String("name").NotEmpty(),
		field.Int("type").Default(0).Comment("0: folder, 1: file"),
		field.Int64("size").Default(0).Comment("File size in bytes, 0 for folder"),
		field.String("mime_type").Optional().Comment("MIME type for files"),
		field.String("file_hash").Optional().Comment("File hash (MD5/SHA256) for quick upload"),
		field.String("minio_object").Optional().Comment("MinIO object name/path"),
		field.Bool("is_deleted").Default(false).Comment("Whether the file is in trash"),
		field.Time("deleted_at").Optional().Comment("When the file was deleted"),
		field.Time("created_at").Default(time.Now),
		field.Time("updated_at").Default(time.Now).UpdateDefault(time.Now),
	}
}

// Edges of the Node.
func (Node) Edges() []ent.Edge {
	return []ent.Edge{
		edge.From("owner", User.Type).Ref("nodes").Required().Unique(),
		edge.To("parent", Node.Type).Unique(),
		edge.From("children", Node.Type).Ref("parent"),
		edge.To("shares", Share.Type),
	}
}
