package api

import (
	"gopan-server/ent"
	"gopan-server/ent/node"
	"gopan-server/ent/user"
	"strconv"
)

// parseUserID converts string userID to int
func parseUserID(userID string) (int, error) {
	return strconv.Atoi(userID)
}

// parseNodeID converts string nodeID to int
func parseNodeID(nodeID string) (int, error) {
	return strconv.Atoi(nodeID)
}

// queryNodesByOwner creates a query for nodes owned by a user
func queryNodesByOwner(client *ent.Client, ownerID int) *ent.NodeQuery {
	return client.Node.Query().
		Where(node.HasOwnerWith(user.IDEQ(ownerID)))
}

// queryNodesByParent creates a query for nodes with a specific parent
func queryNodesByParent(query *ent.NodeQuery, parentID int) *ent.NodeQuery {
	return query.Where(node.HasParentWith(node.IDEQ(parentID)))
}

// queryNodesWithoutParent creates a query for nodes without parent (root level)
func queryNodesWithoutParent(query *ent.NodeQuery) *ent.NodeQuery {
	return query.Where(node.Not(node.HasParent()))
}

// getParentID returns the parent ID from a node, or nil if no parent
func getParentID(n *ent.Node) *int {
	if n.Edges.Parent != nil {
		return &n.Edges.Parent.ID
	}
	return nil
}
