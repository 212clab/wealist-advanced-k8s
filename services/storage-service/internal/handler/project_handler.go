package handler

import (
	"net/http"
	"strconv"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"

	"storage-service/internal/domain"
	"storage-service/internal/middleware"
	"storage-service/internal/service"
)

// ProjectHandler handles project-related HTTP requests
type ProjectHandler struct {
	projectService service.ProjectService
}

// NewProjectHandler creates a new project handler
func NewProjectHandler(projectService service.ProjectService) *ProjectHandler {
	return &ProjectHandler{
		projectService: projectService,
	}
}

// CreateProject godoc
// @Summary Create a new project
// @Description Create a new project in a workspace
// @Tags projects
// @Accept json
// @Produce json
// @Param request body domain.CreateProjectRequest true "Project creation request"
// @Success 201 {object} domain.ProjectResponse
// @Failure 400 {object} ErrorResponse
// @Failure 401 {object} ErrorResponse
// @Failure 403 {object} ErrorResponse
// @Security BearerAuth
// @Router /storage/projects [post]
func (h *ProjectHandler) CreateProject(c *gin.Context) {
	userID, ok := middleware.GetUserID(c)
	if !ok {
		c.JSON(http.StatusUnauthorized, ErrorResponse{
			Error: ErrorDetail{
				Code:    "UNAUTHORIZED",
				Message: "User not authenticated",
			},
		})
		return
	}

	token := c.GetString("jwtToken")

	var req domain.CreateProjectRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, ErrorResponse{
			Error: ErrorDetail{
				Code:    "INVALID_REQUEST",
				Message: err.Error(),
			},
		})
		return
	}

	project, err := h.projectService.CreateProject(c.Request.Context(), req, userID, token)
	if err != nil {
		handleServiceError(c, err)
		return
	}

	c.JSON(http.StatusCreated, project)
}

// GetProject godoc
// @Summary Get a project by ID
// @Description Get project details by ID
// @Tags projects
// @Produce json
// @Param projectId path string true "Project ID"
// @Success 200 {object} domain.ProjectResponse
// @Failure 401 {object} ErrorResponse
// @Failure 403 {object} ErrorResponse
// @Failure 404 {object} ErrorResponse
// @Security BearerAuth
// @Router /storage/projects/{projectId} [get]
func (h *ProjectHandler) GetProject(c *gin.Context) {
	userID, ok := middleware.GetUserID(c)
	if !ok {
		c.JSON(http.StatusUnauthorized, ErrorResponse{
			Error: ErrorDetail{
				Code:    "UNAUTHORIZED",
				Message: "User not authenticated",
			},
		})
		return
	}

	token := c.GetString("jwtToken")

	projectID, err := uuid.Parse(c.Param("projectId"))
	if err != nil {
		c.JSON(http.StatusBadRequest, ErrorResponse{
			Error: ErrorDetail{
				Code:    "INVALID_PROJECT_ID",
				Message: "Invalid project ID format",
			},
		})
		return
	}

	project, err := h.projectService.GetProject(c.Request.Context(), projectID, userID, token)
	if err != nil {
		handleServiceError(c, err)
		return
	}

	c.JSON(http.StatusOK, project)
}

// GetWorkspaceProjects godoc
// @Summary Get projects in a workspace
// @Description Get all projects that the user has access to in a workspace
// @Tags projects
// @Produce json
// @Param workspaceId path string true "Workspace ID"
// @Param page query int false "Page number" default(1)
// @Param pageSize query int false "Page size" default(20)
// @Success 200 {object} domain.ProjectListResponse
// @Failure 401 {object} ErrorResponse
// @Failure 403 {object} ErrorResponse
// @Security BearerAuth
// @Router /storage/workspaces/{workspaceId}/projects [get]
func (h *ProjectHandler) GetWorkspaceProjects(c *gin.Context) {
	userID, ok := middleware.GetUserID(c)
	if !ok {
		c.JSON(http.StatusUnauthorized, ErrorResponse{
			Error: ErrorDetail{
				Code:    "UNAUTHORIZED",
				Message: "User not authenticated",
			},
		})
		return
	}

	token := c.GetString("jwtToken")

	workspaceID, err := uuid.Parse(c.Param("workspaceId"))
	if err != nil {
		c.JSON(http.StatusBadRequest, ErrorResponse{
			Error: ErrorDetail{
				Code:    "INVALID_WORKSPACE_ID",
				Message: "Invalid workspace ID format",
			},
		})
		return
	}

	page, _ := strconv.Atoi(c.DefaultQuery("page", "1"))
	pageSize, _ := strconv.Atoi(c.DefaultQuery("pageSize", "20"))

	if page < 1 {
		page = 1
	}
	if pageSize < 1 || pageSize > 100 {
		pageSize = 20
	}

	projects, err := h.projectService.GetWorkspaceProjects(c.Request.Context(), workspaceID, userID, token, page, pageSize)
	if err != nil {
		handleServiceError(c, err)
		return
	}

	c.JSON(http.StatusOK, projects)
}

// UpdateProject godoc
// @Summary Update a project
// @Description Update project details (requires EDITOR or OWNER permission)
// @Tags projects
// @Accept json
// @Produce json
// @Param projectId path string true "Project ID"
// @Param request body domain.UpdateProjectRequest true "Project update request"
// @Success 200 {object} domain.ProjectResponse
// @Failure 400 {object} ErrorResponse
// @Failure 401 {object} ErrorResponse
// @Failure 403 {object} ErrorResponse
// @Failure 404 {object} ErrorResponse
// @Security BearerAuth
// @Router /storage/projects/{projectId} [put]
func (h *ProjectHandler) UpdateProject(c *gin.Context) {
	userID, ok := middleware.GetUserID(c)
	if !ok {
		c.JSON(http.StatusUnauthorized, ErrorResponse{
			Error: ErrorDetail{
				Code:    "UNAUTHORIZED",
				Message: "User not authenticated",
			},
		})
		return
	}

	token := c.GetString("jwtToken")

	projectID, err := uuid.Parse(c.Param("projectId"))
	if err != nil {
		c.JSON(http.StatusBadRequest, ErrorResponse{
			Error: ErrorDetail{
				Code:    "INVALID_PROJECT_ID",
				Message: "Invalid project ID format",
			},
		})
		return
	}

	var req domain.UpdateProjectRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, ErrorResponse{
			Error: ErrorDetail{
				Code:    "INVALID_REQUEST",
				Message: err.Error(),
			},
		})
		return
	}

	project, err := h.projectService.UpdateProject(c.Request.Context(), projectID, req, userID, token)
	if err != nil {
		handleServiceError(c, err)
		return
	}

	c.JSON(http.StatusOK, project)
}

// DeleteProject godoc
// @Summary Delete a project
// @Description Delete a project (requires OWNER permission)
// @Tags projects
// @Param projectId path string true "Project ID"
// @Success 204
// @Failure 401 {object} ErrorResponse
// @Failure 403 {object} ErrorResponse
// @Failure 404 {object} ErrorResponse
// @Security BearerAuth
// @Router /storage/projects/{projectId} [delete]
func (h *ProjectHandler) DeleteProject(c *gin.Context) {
	userID, ok := middleware.GetUserID(c)
	if !ok {
		c.JSON(http.StatusUnauthorized, ErrorResponse{
			Error: ErrorDetail{
				Code:    "UNAUTHORIZED",
				Message: "User not authenticated",
			},
		})
		return
	}

	token := c.GetString("jwtToken")

	projectID, err := uuid.Parse(c.Param("projectId"))
	if err != nil {
		c.JSON(http.StatusBadRequest, ErrorResponse{
			Error: ErrorDetail{
				Code:    "INVALID_PROJECT_ID",
				Message: "Invalid project ID format",
			},
		})
		return
	}

	if err := h.projectService.DeleteProject(c.Request.Context(), projectID, userID, token); err != nil {
		handleServiceError(c, err)
		return
	}

	c.Status(http.StatusNoContent)
}

// AddMember godoc
// @Summary Add a member to a project
// @Description Add a new member to a project (requires EDITOR or OWNER permission)
// @Tags projects
// @Accept json
// @Produce json
// @Param projectId path string true "Project ID"
// @Param request body domain.AddProjectMemberRequest true "Add member request"
// @Success 201 {object} domain.ProjectMemberResponse
// @Failure 400 {object} ErrorResponse
// @Failure 401 {object} ErrorResponse
// @Failure 403 {object} ErrorResponse
// @Failure 404 {object} ErrorResponse
// @Security BearerAuth
// @Router /storage/projects/{projectId}/members [post]
func (h *ProjectHandler) AddMember(c *gin.Context) {
	userID, ok := middleware.GetUserID(c)
	if !ok {
		c.JSON(http.StatusUnauthorized, ErrorResponse{
			Error: ErrorDetail{
				Code:    "UNAUTHORIZED",
				Message: "User not authenticated",
			},
		})
		return
	}

	token := c.GetString("jwtToken")

	projectID, err := uuid.Parse(c.Param("projectId"))
	if err != nil {
		c.JSON(http.StatusBadRequest, ErrorResponse{
			Error: ErrorDetail{
				Code:    "INVALID_PROJECT_ID",
				Message: "Invalid project ID format",
			},
		})
		return
	}

	var req domain.AddProjectMemberRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, ErrorResponse{
			Error: ErrorDetail{
				Code:    "INVALID_REQUEST",
				Message: err.Error(),
			},
		})
		return
	}

	member, err := h.projectService.AddMember(c.Request.Context(), projectID, req, userID, token)
	if err != nil {
		handleServiceError(c, err)
		return
	}

	c.JSON(http.StatusCreated, member)
}

// GetMembers godoc
// @Summary Get project members
// @Description Get all members of a project
// @Tags projects
// @Produce json
// @Param projectId path string true "Project ID"
// @Success 200 {array} domain.ProjectMemberResponse
// @Failure 401 {object} ErrorResponse
// @Failure 403 {object} ErrorResponse
// @Failure 404 {object} ErrorResponse
// @Security BearerAuth
// @Router /storage/projects/{projectId}/members [get]
func (h *ProjectHandler) GetMembers(c *gin.Context) {
	userID, ok := middleware.GetUserID(c)
	if !ok {
		c.JSON(http.StatusUnauthorized, ErrorResponse{
			Error: ErrorDetail{
				Code:    "UNAUTHORIZED",
				Message: "User not authenticated",
			},
		})
		return
	}

	token := c.GetString("jwtToken")

	projectID, err := uuid.Parse(c.Param("projectId"))
	if err != nil {
		c.JSON(http.StatusBadRequest, ErrorResponse{
			Error: ErrorDetail{
				Code:    "INVALID_PROJECT_ID",
				Message: "Invalid project ID format",
			},
		})
		return
	}

	members, err := h.projectService.GetMembers(c.Request.Context(), projectID, userID, token)
	if err != nil {
		handleServiceError(c, err)
		return
	}

	c.JSON(http.StatusOK, gin.H{"members": members})
}

// UpdateMember godoc
// @Summary Update a project member
// @Description Update a member's permission (requires OWNER permission)
// @Tags projects
// @Accept json
// @Produce json
// @Param projectId path string true "Project ID"
// @Param userId path string true "User ID of the member to update"
// @Param request body domain.UpdateProjectMemberRequest true "Update member request"
// @Success 200 {object} domain.ProjectMemberResponse
// @Failure 400 {object} ErrorResponse
// @Failure 401 {object} ErrorResponse
// @Failure 403 {object} ErrorResponse
// @Failure 404 {object} ErrorResponse
// @Security BearerAuth
// @Router /storage/projects/{projectId}/members/{userId} [put]
func (h *ProjectHandler) UpdateMember(c *gin.Context) {
	userID, ok := middleware.GetUserID(c)
	if !ok {
		c.JSON(http.StatusUnauthorized, ErrorResponse{
			Error: ErrorDetail{
				Code:    "UNAUTHORIZED",
				Message: "User not authenticated",
			},
		})
		return
	}

	token := c.GetString("jwtToken")

	projectID, err := uuid.Parse(c.Param("projectId"))
	if err != nil {
		c.JSON(http.StatusBadRequest, ErrorResponse{
			Error: ErrorDetail{
				Code:    "INVALID_PROJECT_ID",
				Message: "Invalid project ID format",
			},
		})
		return
	}

	memberUserID, err := uuid.Parse(c.Param("userId"))
	if err != nil {
		c.JSON(http.StatusBadRequest, ErrorResponse{
			Error: ErrorDetail{
				Code:    "INVALID_USER_ID",
				Message: "Invalid user ID format",
			},
		})
		return
	}

	var req domain.UpdateProjectMemberRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, ErrorResponse{
			Error: ErrorDetail{
				Code:    "INVALID_REQUEST",
				Message: err.Error(),
			},
		})
		return
	}

	member, err := h.projectService.UpdateMember(c.Request.Context(), projectID, memberUserID, req, userID, token)
	if err != nil {
		handleServiceError(c, err)
		return
	}

	c.JSON(http.StatusOK, member)
}

// RemoveMember godoc
// @Summary Remove a project member
// @Description Remove a member from a project (requires OWNER permission, or removing self)
// @Tags projects
// @Param projectId path string true "Project ID"
// @Param userId path string true "User ID of the member to remove"
// @Success 204
// @Failure 400 {object} ErrorResponse
// @Failure 401 {object} ErrorResponse
// @Failure 403 {object} ErrorResponse
// @Failure 404 {object} ErrorResponse
// @Security BearerAuth
// @Router /storage/projects/{projectId}/members/{userId} [delete]
func (h *ProjectHandler) RemoveMember(c *gin.Context) {
	userID, ok := middleware.GetUserID(c)
	if !ok {
		c.JSON(http.StatusUnauthorized, ErrorResponse{
			Error: ErrorDetail{
				Code:    "UNAUTHORIZED",
				Message: "User not authenticated",
			},
		})
		return
	}

	token := c.GetString("jwtToken")

	projectID, err := uuid.Parse(c.Param("projectId"))
	if err != nil {
		c.JSON(http.StatusBadRequest, ErrorResponse{
			Error: ErrorDetail{
				Code:    "INVALID_PROJECT_ID",
				Message: "Invalid project ID format",
			},
		})
		return
	}

	memberUserID, err := uuid.Parse(c.Param("userId"))
	if err != nil {
		c.JSON(http.StatusBadRequest, ErrorResponse{
			Error: ErrorDetail{
				Code:    "INVALID_USER_ID",
				Message: "Invalid user ID format",
			},
		})
		return
	}

	if err := h.projectService.RemoveMember(c.Request.Context(), projectID, memberUserID, userID, token); err != nil {
		handleServiceError(c, err)
		return
	}

	c.Status(http.StatusNoContent)
}
