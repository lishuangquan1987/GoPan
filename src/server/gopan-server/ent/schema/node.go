package schema

import (
	"entgo.io/ent"
	"entgo.io/ent/schema/field"
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
		field.String("parent_id").Optional().Comment("ID of the parent node, if any"),
	}
}

// Edges of the Node.
func (Node) Edges() []ent.Edge {
	return nil
}
