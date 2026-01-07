package schema

import (
	"entgo.io/ent"
	"entgo.io/ent/schema/edge"
	"entgo.io/ent/schema/field"
	"time"
)

// User holds the schema definition for the User entity.
type User struct {
	ent.Schema
}

// Fields of the User.
func (User) Fields() []ent.Field {
	return []ent.Field{
		field.String("username").Unique().NotEmpty(),
		field.String("password_hash").NotEmpty().Comment("bcrypt hashed password"),
		field.String("email").Optional(),
		field.Int64("total_quota").Default(10737418240).Comment("Total storage quota in bytes, default 10GB"),
		field.Int64("total_used").Default(0).Comment("Total used storage in bytes"),
		field.Time("created_at").Default(time.Now),
		field.Time("updated_at").Default(time.Now).UpdateDefault(time.Now),
		field.Time("last_login_at").Optional(),
	}
}

// Edges of the User.
func (User) Edges() []ent.Edge {
	return []ent.Edge{
		edge.To("nodes", Node.Type),
		edge.To("shares", Share.Type),
	}
}
