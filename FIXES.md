# 代码修复说明

## 主要问题

1. **ID类型**: Ent生成的ID是`int`类型，但代码中使用了`uuid.UUID`
2. **查询方法**: 需要使用Ent的predicate方法（如`node.ID()`, `node.NameEQ()`等）
3. **ParentID**: 通过edge访问，不是直接字段
4. **可选字段**: 某些可选字段的类型处理需要调整

## 已修复

- ✅ `src/internal/api/auth.go` - 修复了User查询和ID类型
- ✅ `src/internal/api/helpers.go` - 创建了辅助函数

## 待修复

- ⚠️ `src/internal/api/file.go` - 需要修复所有Ent API调用
- ⚠️ `src/internal/api/share.go` - 需要修复Share查询
- ⚠️ `src/internal/preview/preview.go` - 需要修复Preview查询

## 修复模式

### 1. ID类型转换
```go
// 错误
uid, err := uuid.Parse(userID)

// 正确
uid, err := strconv.Atoi(userID)
```

### 2. 查询方法
```go
// 错误
database.Client.Node.Query().Where(database.Client.Node.OwnerID(uid))

// 正确
database.Client.Node.Query().Where(node.HasOwnerWith(user.IDEQ(uid)))
```

### 3. ParentID访问
```go
// 错误
node.ParentID

// 正确
if node.Edges.Parent != nil {
    parentID := node.Edges.Parent.ID
}
```

### 4. 创建Node
```go
// 错误
SetOwnerID(uid) // uid是uuid.UUID

// 正确
SetOwnerID(uid) // uid是int
SetNillableParentID(&parentID) // parentID是*int
```

