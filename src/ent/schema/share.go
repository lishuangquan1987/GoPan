package schema

import (
	"entgo.io/ent"
	"entgo.io/ent/schema/edge"
	"entgo.io/ent/schema/field"
	"time"
)

// Share holds the schema definition for the Share entity.
type Share struct {
	ent.Schema
}

// Fields of the Share.
func (Share) Fields() []ent.Field {
	return []ent.Field{
		field.String("code").Unique().NotEmpty().Comment("Unique share code"),
		field.Int("share_type").Default(0).Comment("0: permanent, 1: temporary"),
		field.Time("expires_at").Optional().Comment("Expiration time for temporary shares"),
		field.String("password").Optional().Comment("Optional password for share"),
		field.Int("access_count").Default(0).Comment("Number of times accessed"),
		field.Int("max_access_count").Optional().Comment("Maximum access count, 0 for unlimited"),
		field.Time("created_at").Default(time.Now),
		field.Time("updated_at").Default(time.Now).UpdateDefault(time.Now),
	}
}

// Edges of the Share.
func (Share) Edges() []ent.Edge {
	return []ent.Edge{
		edge.From("owner", User.Type).Ref("shares").Required().Unique(),
		edge.From("node", Node.Type).Ref("shares").Required().Unique(),
	}
}

