// API Utility Module - Unified API request handling
const API_BASE = window.location.origin + '/api';

/**
 * Unified API request function
 * @param {string} endpoint - API endpoint (e.g., '/files', '/auth/me')
 * @param {object} options - Request options
 * @param {string} options.method - HTTP method (GET, POST, PUT, DELETE)
 * @param {object} options.body - Request body (for POST/PUT)
 * @param {boolean} options.rawResponse - Return raw response instead of JSON
 * @returns {Promise<Response>} - Fetch response
 */
async function apiCall(endpoint, options = {}) {
    const {
        method = 'GET',
        body = null,
        headers = {},
        rawResponse = false
    } = options;

    const requestHeaders = {
        'Content-Type': 'application/json',
        ...headers
    };

    // Add authorization header
    const token = localStorage.getItem('token');
    if (token) {
        requestHeaders['Authorization'] = `Bearer ${token}`;
    }

    const requestOptions = {
        method: method,
        headers: requestHeaders
    };

    if (body !== null) {
        if (body instanceof FormData) {
            // For FormData, let browser set Content-Type
            delete requestHeaders['Content-Type'];
            requestOptions.body = body;
        } else {
            requestOptions.body = JSON.stringify(body);
        }
    }

    try {
        const response = await fetch(`${API_BASE}${endpoint}`, requestOptions);

        // Handle 401 Unauthorized
        if (response.status === 401) {
            localStorage.removeItem('token');
            window.location.href = '/index.html';
            throw new Error('Unauthorized');
        }

        return response;
    } catch (error) {
        console.error('API request failed:', error);
        throw error;
    }
}

/**
 * GET request wrapper
 */
async function get(endpoint, options = {}) {
    return apiCall(endpoint, { ...options, method: 'GET' });
}

/**
 * POST request wrapper
 */
async function post(endpoint, options = {}) {
    return apiCall(endpoint, { ...options, method: 'POST' });
}

/**
 * PUT request wrapper
 */
async function put(endpoint, options = {}) {
    return apiCall(endpoint, { ...options, method: 'PUT' });
}

/**
 * DELETE request wrapper
 */
async function del(endpoint, options = {}) {
    return apiCall(endpoint, { ...options, method: 'DELETE' });
}

/**
 * Upload file with progress tracking
 * @param {File} file - File object to upload
 * @param {string} parentId - Parent folder ID
 * @param {function} onProgress - Progress callback (percent)
 * @returns {Promise<object>} - Upload result
 */
async function uploadFile(file, parentId = null, onProgress = null) {
    const formData = new FormData();
    formData.append('file', file);

    if (parentId !== null && parentId !== 'root') {
        formData.append('parent_id', parentId);
    }

    const token = localStorage.getItem('token');
    const xhr = new XMLHttpRequest();

    return new Promise((resolve, reject) => {
        xhr.open('POST', `${API_BASE}/files/upload`, true);
        xhr.setRequestHeader('Authorization', `Bearer ${token}`);

        // Progress tracking
        if (onProgress) {
            xhr.upload.addEventListener('progress', (e) => {
                if (e.lengthComputable) {
                    const percent = Math.round((e.loaded / e.total) * 100);
                    onProgress(percent);
                }
            });
        }

        xhr.onload = () => {
            if (xhr.status === 200) {
                try {
                    const response = JSON.parse(xhr.responseText);
                    resolve(response);
                } catch (e) {
                    resolve({ id: xhr.responseText });
                }
            } else {
                const error = JSON.parse(xhr.responseText || '{"error": "Upload failed"}');
                reject(new Error(error.error || 'Upload failed'));
            }
        };

        xhr.onerror = () => {
            reject(new Error('Network error during upload'));
        };

        xhr.send(formData);
    });
}

/**
 * Download file
 * @param {number} fileId - File ID to download
 * @returns {Promise<Blob>} - File blob
 */
async function downloadFile(fileId) {
    const response = await get(`/files/${fileId}/download`, {
        rawResponse: true
    });

    if (!response.ok) {
        throw new Error('Download failed');
    }

    return await response.blob();
}

// Export functions for use in other modules
window.APIUtils = {
    apiCall,
    get,
    post,
    put,
    del,
    uploadFile,
    downloadFile
};
