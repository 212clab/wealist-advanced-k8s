package repository

import (
	"context"
	"errors"

	"github.com/google/uuid"
	"gorm.io/gorm"

	"storage-service/internal/domain"
)

var (
	ErrProjectNotFound       = errors.New("project not found")
	ErrProjectMemberNotFound = errors.New("project member not found")
	ErrProjectMemberExists   = errors.New("project member already exists")
)

// ProjectRepository defines the interface for project data access
type ProjectRepository interface {
	// Project CRUD
	Create(ctx context.Context, project *domain.Project) error
	GetByID(ctx context.Context, id uuid.UUID) (*domain.Project, error)
	GetByWorkspaceID(ctx context.Context, workspaceID uuid.UUID, page, pageSize int) ([]domain.Project, int64, error)
	Update(ctx context.Context, project *domain.Project) error
	Delete(ctx context.Context, id uuid.UUID) error
	PermanentDelete(ctx context.Context, id uuid.UUID) error
	Restore(ctx context.Context, id uuid.UUID) error

	// Project Members
	AddMember(ctx context.Context, member *domain.ProjectMember) error
	GetMember(ctx context.Context, projectID, userID uuid.UUID) (*domain.ProjectMember, error)
	GetMemberByID(ctx context.Context, memberID uuid.UUID) (*domain.ProjectMember, error)
	GetMembers(ctx context.Context, projectID uuid.UUID) ([]domain.ProjectMember, error)
	UpdateMember(ctx context.Context, member *domain.ProjectMember) error
	RemoveMember(ctx context.Context, projectID, userID uuid.UUID) error

	// Access Control
	GetUserPermission(ctx context.Context, projectID, userID uuid.UUID) (*domain.ProjectPermission, error)
	GetUserProjects(ctx context.Context, workspaceID, userID uuid.UUID) ([]domain.Project, error)

	// Stats
	GetProjectStats(ctx context.Context, projectID uuid.UUID) (fileCount, folderCount, totalSize int64, err error)
}

type projectRepository struct {
	db *gorm.DB
}

// NewProjectRepository creates a new project repository
func NewProjectRepository(db *gorm.DB) ProjectRepository {
	return &projectRepository{db: db}
}

// Create creates a new project
func (r *projectRepository) Create(ctx context.Context, project *domain.Project) error {
	return r.db.WithContext(ctx).Create(project).Error
}

// GetByID retrieves a project by its ID
func (r *projectRepository) GetByID(ctx context.Context, id uuid.UUID) (*domain.Project, error) {
	var project domain.Project
	err := r.db.WithContext(ctx).
		Where("id = ? AND deleted_at IS NULL", id).
		First(&project).Error
	if err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, ErrProjectNotFound
		}
		return nil, err
	}
	return &project, nil
}

// GetByWorkspaceID retrieves projects by workspace ID with pagination
func (r *projectRepository) GetByWorkspaceID(ctx context.Context, workspaceID uuid.UUID, page, pageSize int) ([]domain.Project, int64, error) {
	var projects []domain.Project
	var total int64

	query := r.db.WithContext(ctx).
		Model(&domain.Project{}).
		Where("workspace_id = ? AND deleted_at IS NULL", workspaceID)

	if err := query.Count(&total).Error; err != nil {
		return nil, 0, err
	}

	offset := (page - 1) * pageSize
	err := query.
		Order("created_at DESC").
		Offset(offset).
		Limit(pageSize).
		Find(&projects).Error

	return projects, total, err
}

// Update updates a project
func (r *projectRepository) Update(ctx context.Context, project *domain.Project) error {
	return r.db.WithContext(ctx).Save(project).Error
}

// Delete soft deletes a project
func (r *projectRepository) Delete(ctx context.Context, id uuid.UUID) error {
	result := r.db.WithContext(ctx).
		Model(&domain.Project{}).
		Where("id = ? AND deleted_at IS NULL", id).
		Update("deleted_at", gorm.Expr("NOW()"))
	if result.RowsAffected == 0 {
		return ErrProjectNotFound
	}
	return result.Error
}

// PermanentDelete permanently deletes a project
func (r *projectRepository) PermanentDelete(ctx context.Context, id uuid.UUID) error {
	result := r.db.WithContext(ctx).
		Unscoped().
		Where("id = ?", id).
		Delete(&domain.Project{})
	if result.RowsAffected == 0 {
		return ErrProjectNotFound
	}
	return result.Error
}

// Restore restores a soft-deleted project
func (r *projectRepository) Restore(ctx context.Context, id uuid.UUID) error {
	result := r.db.WithContext(ctx).
		Model(&domain.Project{}).
		Where("id = ? AND deleted_at IS NOT NULL", id).
		Update("deleted_at", nil)
	if result.RowsAffected == 0 {
		return ErrProjectNotFound
	}
	return result.Error
}

// AddMember adds a new member to a project
func (r *projectRepository) AddMember(ctx context.Context, member *domain.ProjectMember) error {
	// Check if member already exists
	var count int64
	r.db.WithContext(ctx).
		Model(&domain.ProjectMember{}).
		Where("project_id = ? AND user_id = ?", member.ProjectID, member.UserID).
		Count(&count)
	if count > 0 {
		return ErrProjectMemberExists
	}
	return r.db.WithContext(ctx).Create(member).Error
}

// GetMember retrieves a project member by project ID and user ID
func (r *projectRepository) GetMember(ctx context.Context, projectID, userID uuid.UUID) (*domain.ProjectMember, error) {
	var member domain.ProjectMember
	err := r.db.WithContext(ctx).
		Where("project_id = ? AND user_id = ?", projectID, userID).
		First(&member).Error
	if err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, ErrProjectMemberNotFound
		}
		return nil, err
	}
	return &member, nil
}

// GetMemberByID retrieves a project member by member ID
func (r *projectRepository) GetMemberByID(ctx context.Context, memberID uuid.UUID) (*domain.ProjectMember, error) {
	var member domain.ProjectMember
	err := r.db.WithContext(ctx).
		Where("id = ?", memberID).
		First(&member).Error
	if err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, ErrProjectMemberNotFound
		}
		return nil, err
	}
	return &member, nil
}

// GetMembers retrieves all members of a project
func (r *projectRepository) GetMembers(ctx context.Context, projectID uuid.UUID) ([]domain.ProjectMember, error) {
	var members []domain.ProjectMember
	err := r.db.WithContext(ctx).
		Where("project_id = ?", projectID).
		Order("created_at ASC").
		Find(&members).Error
	return members, err
}

// UpdateMember updates a project member
func (r *projectRepository) UpdateMember(ctx context.Context, member *domain.ProjectMember) error {
	return r.db.WithContext(ctx).Save(member).Error
}

// RemoveMember removes a member from a project
func (r *projectRepository) RemoveMember(ctx context.Context, projectID, userID uuid.UUID) error {
	result := r.db.WithContext(ctx).
		Where("project_id = ? AND user_id = ?", projectID, userID).
		Delete(&domain.ProjectMember{})
	if result.RowsAffected == 0 {
		return ErrProjectMemberNotFound
	}
	return result.Error
}

// GetUserPermission gets the permission level of a user in a project
func (r *projectRepository) GetUserPermission(ctx context.Context, projectID, userID uuid.UUID) (*domain.ProjectPermission, error) {
	// First check if user is a direct member
	member, err := r.GetMember(ctx, projectID, userID)
	if err == nil {
		return &member.Permission, nil
	}

	// If not a direct member, check if project is public and return default permission
	project, err := r.GetByID(ctx, projectID)
	if err != nil {
		return nil, err
	}

	if project.IsPublic {
		return &project.DefaultPermission, nil
	}

	// User is the project creator (owner)
	if project.CreatedBy == userID {
		perm := domain.ProjectPermissionOwner
		return &perm, nil
	}

	return nil, ErrProjectMemberNotFound
}

// GetUserProjects retrieves all projects a user has access to in a workspace
func (r *projectRepository) GetUserProjects(ctx context.Context, workspaceID, userID uuid.UUID) ([]domain.Project, error) {
	var projects []domain.Project

	// Get projects where user is a member OR project is public OR user is creator
	err := r.db.WithContext(ctx).
		Distinct().
		Where("workspace_id = ? AND deleted_at IS NULL", workspaceID).
		Where(`(
			is_public = true
			OR created_by = ?
			OR id IN (SELECT project_id FROM storage_project_members WHERE user_id = ?)
		)`, userID, userID).
		Order("created_at DESC").
		Find(&projects).Error

	return projects, err
}

// GetProjectStats retrieves statistics for a project
func (r *projectRepository) GetProjectStats(ctx context.Context, projectID uuid.UUID) (fileCount, folderCount, totalSize int64, err error) {
	// Count files
	err = r.db.WithContext(ctx).
		Model(&domain.File{}).
		Where("project_id = ? AND deleted_at IS NULL AND status = ?", projectID, domain.FileStatusActive).
		Count(&fileCount).Error
	if err != nil {
		return
	}

	// Count folders
	err = r.db.WithContext(ctx).
		Model(&domain.Folder{}).
		Where("project_id = ? AND deleted_at IS NULL", projectID).
		Count(&folderCount).Error
	if err != nil {
		return
	}

	// Calculate total size
	var result struct {
		TotalSize int64
	}
	err = r.db.WithContext(ctx).
		Model(&domain.File{}).
		Select("COALESCE(SUM(file_size), 0) as total_size").
		Where("project_id = ? AND deleted_at IS NULL AND status = ?", projectID, domain.FileStatusActive).
		Scan(&result).Error
	totalSize = result.TotalSize

	return
}
