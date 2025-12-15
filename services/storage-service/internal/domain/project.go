package domain

import (
	"time"

	"github.com/google/uuid"
)

// ProjectPermission represents the permission level for a project member
type ProjectPermission string

const (
	ProjectPermissionOwner  ProjectPermission = "OWNER"  // Full control, can delete project, manage members
	ProjectPermissionEditor ProjectPermission = "EDITOR" // Can upload, edit, delete files/folders
	ProjectPermissionViewer ProjectPermission = "VIEWER" // Can only view and download files
)

// Project represents a project within a workspace for organizing files
type Project struct {
	ID                uuid.UUID         `gorm:"type:uuid;primaryKey;default:gen_random_uuid()" json:"id"`
	WorkspaceID       uuid.UUID         `gorm:"type:uuid;not null;index" json:"workspaceId"`
	Name              string            `gorm:"size:255;not null" json:"name"`
	Description       *string           `gorm:"size:1024" json:"description,omitempty"`
	DefaultPermission ProjectPermission `gorm:"size:20;not null;default:'VIEWER'" json:"defaultPermission"` // Default permission for workspace members
	IsPublic          bool              `gorm:"not null;default:false" json:"isPublic"`                     // If true, all workspace members can access with default permission
	CreatedBy         uuid.UUID         `gorm:"type:uuid;not null" json:"createdBy"`
	CreatedAt         time.Time         `gorm:"not null" json:"createdAt"`
	UpdatedAt         time.Time         `gorm:"not null" json:"updatedAt"`
	DeletedAt         *time.Time        `gorm:"index" json:"deletedAt,omitempty"` // Soft delete

	// Relations
	Members []ProjectMember `gorm:"foreignKey:ProjectID" json:"members,omitempty"`
	Folders []Folder        `gorm:"foreignKey:ProjectID" json:"folders,omitempty"`
	Files   []File          `gorm:"foreignKey:ProjectID" json:"files,omitempty"`
}

// TableName returns the table name for Project
func (Project) TableName() string {
	return "storage_projects"
}

// IsDeleted returns true if the project is soft deleted
func (p *Project) IsDeleted() bool {
	return p.DeletedAt != nil
}

// ProjectMember represents a user's membership and permission in a project
type ProjectMember struct {
	ID         uuid.UUID         `gorm:"type:uuid;primaryKey;default:gen_random_uuid()" json:"id"`
	ProjectID  uuid.UUID         `gorm:"type:uuid;not null;index;uniqueIndex:idx_project_user" json:"projectId"`
	UserID     uuid.UUID         `gorm:"type:uuid;not null;index;uniqueIndex:idx_project_user" json:"userId"`
	Permission ProjectPermission `gorm:"size:20;not null;default:'VIEWER'" json:"permission"`
	AddedBy    uuid.UUID         `gorm:"type:uuid;not null" json:"addedBy"`
	CreatedAt  time.Time         `gorm:"not null" json:"createdAt"`
	UpdatedAt  time.Time         `gorm:"not null" json:"updatedAt"`

	// Relations
	Project *Project `gorm:"foreignKey:ProjectID" json:"project,omitempty"`
}

// TableName returns the table name for ProjectMember
func (ProjectMember) TableName() string {
	return "storage_project_members"
}

// CanView returns true if the permission allows viewing
func (p ProjectPermission) CanView() bool {
	return p == ProjectPermissionOwner || p == ProjectPermissionEditor || p == ProjectPermissionViewer
}

// CanEdit returns true if the permission allows editing
func (p ProjectPermission) CanEdit() bool {
	return p == ProjectPermissionOwner || p == ProjectPermissionEditor
}

// CanManage returns true if the permission allows managing (owner only)
func (p ProjectPermission) CanManage() bool {
	return p == ProjectPermissionOwner
}

// IsValid returns true if the permission is a valid value
func (p ProjectPermission) IsValid() bool {
	switch p {
	case ProjectPermissionOwner, ProjectPermissionEditor, ProjectPermissionViewer:
		return true
	default:
		return false
	}
}

// CreateProjectRequest represents request for creating a new project
type CreateProjectRequest struct {
	WorkspaceID       uuid.UUID          `json:"workspaceId" binding:"required"`
	Name              string             `json:"name" binding:"required,min=1,max=255"`
	Description       *string            `json:"description,omitempty"`
	DefaultPermission *ProjectPermission `json:"defaultPermission,omitempty"` // Defaults to VIEWER if not specified
	IsPublic          *bool              `json:"isPublic,omitempty"`          // Defaults to false if not specified
}

// UpdateProjectRequest represents request for updating a project
type UpdateProjectRequest struct {
	Name              *string            `json:"name,omitempty"`
	Description       *string            `json:"description,omitempty"`
	DefaultPermission *ProjectPermission `json:"defaultPermission,omitempty"`
	IsPublic          *bool              `json:"isPublic,omitempty"`
}

// AddProjectMemberRequest represents request for adding a member to a project
type AddProjectMemberRequest struct {
	UserID     uuid.UUID         `json:"userId" binding:"required"`
	Permission ProjectPermission `json:"permission" binding:"required"`
}

// UpdateProjectMemberRequest represents request for updating a project member's permission
type UpdateProjectMemberRequest struct {
	Permission ProjectPermission `json:"permission" binding:"required"`
}

// ProjectResponse represents project data returned to client
type ProjectResponse struct {
	ID                uuid.UUID               `json:"id"`
	WorkspaceID       uuid.UUID               `json:"workspaceId"`
	Name              string                  `json:"name"`
	Description       *string                 `json:"description,omitempty"`
	DefaultPermission ProjectPermission       `json:"defaultPermission"`
	IsPublic          bool                    `json:"isPublic"`
	CreatedBy         uuid.UUID               `json:"createdBy"`
	CreatedAt         time.Time               `json:"createdAt"`
	UpdatedAt         time.Time               `json:"updatedAt"`
	IsDeleted         bool                    `json:"isDeleted"`
	MemberCount       int64                   `json:"memberCount"`
	FileCount         int64                   `json:"fileCount"`
	FolderCount       int64                   `json:"folderCount"`
	TotalSize         int64                   `json:"totalSize"` // Total size in bytes
	Members           []ProjectMemberResponse `json:"members,omitempty"`
	MyPermission      *ProjectPermission      `json:"myPermission,omitempty"` // Current user's permission in this project
}

// ToResponse converts Project to ProjectResponse
func (p *Project) ToResponse() ProjectResponse {
	return ProjectResponse{
		ID:                p.ID,
		WorkspaceID:       p.WorkspaceID,
		Name:              p.Name,
		Description:       p.Description,
		DefaultPermission: p.DefaultPermission,
		IsPublic:          p.IsPublic,
		CreatedBy:         p.CreatedBy,
		CreatedAt:         p.CreatedAt,
		UpdatedAt:         p.UpdatedAt,
		IsDeleted:         p.IsDeleted(),
	}
}

// ProjectMemberResponse represents project member data returned to client
type ProjectMemberResponse struct {
	ID         uuid.UUID         `json:"id"`
	ProjectID  uuid.UUID         `json:"projectId"`
	UserID     uuid.UUID         `json:"userId"`
	UserName   string            `json:"userName,omitempty"` // Resolved from user service
	UserEmail  string            `json:"userEmail,omitempty"`
	Permission ProjectPermission `json:"permission"`
	AddedBy    uuid.UUID         `json:"addedBy"`
	CreatedAt  time.Time         `json:"createdAt"`
}

// ToResponse converts ProjectMember to ProjectMemberResponse
func (pm *ProjectMember) ToResponse() ProjectMemberResponse {
	return ProjectMemberResponse{
		ID:         pm.ID,
		ProjectID:  pm.ProjectID,
		UserID:     pm.UserID,
		Permission: pm.Permission,
		AddedBy:    pm.AddedBy,
		CreatedAt:  pm.CreatedAt,
	}
}

// ProjectListResponse represents list of projects with pagination
type ProjectListResponse struct {
	Projects   []ProjectResponse `json:"projects"`
	Total      int64             `json:"total"`
	Page       int               `json:"page"`
	PageSize   int               `json:"pageSize"`
	TotalPages int               `json:"totalPages"`
}

// ProjectAccessCheckResult represents the result of checking project access
type ProjectAccessCheckResult struct {
	HasAccess  bool               `json:"hasAccess"`
	Permission *ProjectPermission `json:"permission,omitempty"`
	IsOwner    bool               `json:"isOwner"`
	Reason     string             `json:"reason,omitempty"` // Reason if access is denied
}
