// Utility Functions Module

/**
 * Format file size to human-readable format
 * @param {number} bytes - Size in bytes
 * @returns {string} - Formatted size (e.g., "1.5 GB")
 */
function formatSize(bytes) {
    if (!bytes) return '0 B';
    if (bytes < 1024) return bytes + ' B';
    if (bytes < 1024 * 1024) return (bytes / 1024).toFixed(1) + ' KB';
    if (bytes < 1024 * 1024 * 1024) return (bytes / (1024 * 1024)).toFixed(1) + ' MB';
    return (bytes / (1024 * 1024 * 1024)).toFixed(1) + ' GB';
}

/**
 * Format date to localized string
 * @param {string|Date} date - Date string or Date object
 * @returns {string} - Formatted date string
 */
function formatDate(dateStr) {
    if (!dateStr) return '-';
    const date = new Date(dateStr);
    return date.toLocaleString('zh-CN', {
        year: 'numeric',
        month: '2-digit',
        day: '2-digit',
        hour: '2-digit',
        minute: '2-digit',
        second: '2-digit'
    });
}

/**
 * Format relative time (e.g., "5 minutes ago", "2 hours ago")
 * @param {string|Date} date - Date string or Date object
 * @returns {string} - Relative time string
 */
function formatRelativeTime(dateStr) {
    if (!dateStr) return '-';

    const date = new Date(dateStr);
    const now = new Date();
    const diff = now - date;

    const seconds = Math.floor(diff / 1000);
    const minutes = Math.floor(seconds / 60);
    const hours = Math.floor(minutes / 60);
    const days = Math.floor(hours / 24);

    if (seconds < 60) return '刚刚';
    if (minutes < 60) return `${minutes} 分钟前`;
    if (hours < 24) return `${hours} 小时前`;
    if (days < 7) return `${days} 天前`;
    if (days < 30) return `${Math.floor(days / 7)} 周前`;
    return formatDate(dateStr); // Return full date if older than 30 days
}

/**
 * Get file icon based on file type
 * @param {object} file - File object with name and mime_type
 * @returns {object} - Icon info { emoji, class }
 */
function getFileIcon(file) {
    if (!file) return { emoji: '📄', class: 'file-icon-default' };

    // Check if it's a folder
    if (file.type === 0 || file.mime_type === 'folder') {
        return { emoji: '📁', class: 'file-icon-folder' };
    }

    // Get file extension
    const ext = file.name.split('.').pop().toLowerCase();

    // Images
    if (['jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp', 'svg', 'ico'].includes(ext)) {
        return { emoji: '🖼️', class: 'file-icon-image' };
    }
    // Videos
    if (['mp4', 'avi', 'mkv', 'mov', 'wmv', 'flv', 'webm'].includes(ext)) {
        return { emoji: '🎬', class: 'file-icon-video' };
    }
    // Audio
    if (['mp3', 'wav', 'flac', 'aac', 'ogg', 'm4a', 'wma'].includes(ext)) {
        return { emoji: '🎵', class: 'file-icon-audio' };
    }
    // PDF
    if (ext === 'pdf') {
        return { emoji: '📕', class: 'file-icon-pdf' };
    }
    // Office documents
    if (['doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx'].includes(ext)) {
        return { emoji: '📄', class: 'file-icon-document' };
    }
    // Archives
    if (['zip', 'rar', '7z', 'tar', 'gz', 'bz2'].includes(ext)) {
        return { emoji: '📦', class: 'file-icon-archive' };
    }
    // Code files
    if (['js', 'ts', 'html', 'css', 'py', 'java', 'cpp', 'c', 'go', 'rs', 'php', 'rb', 'sh', 'json', 'xml', 'yaml', 'yml'].includes(ext)) {
        return { emoji: '💻', class: 'file-icon-code' };
    }
    // Text files
    if (['txt', 'md', 'log', 'ini', 'conf'].includes(ext)) {
        return { emoji: '📝', class: 'file-icon-document' };
    }

    // Default file
    return { emoji: '📄', class: 'file-icon-default' };
}

/**
 * Escape HTML to prevent XSS
 * @param {string} text - Text to escape
 * @returns {string} - Escaped HTML
 */
function escapeHtml(text) {
    const div = document.createElement('div');
    div.textContent = text;
    return div.innerHTML;
}

/**
 * Debounce function to limit execution frequency
 * @param {Function} func - Function to debounce
 * @param {number} wait - Wait time in milliseconds
 * @returns {Function} - Debounced function
 */
function debounce(func, wait) {
    let timeout;
    return function executedFunction(...args) {
        const later = () => {
            clearTimeout(timeout);
            func(...args);
        };
        clearTimeout(timeout);
        timeout = setTimeout(later, wait);
    };
}

/**
 * Generate UUID v4
 * @returns {string} - UUID string
 */
function generateUUID() {
    return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, function(c) {
        const r = Math.random() * 16 | 0;
        const v = c === 'x' ? r : (r & 0x3 | 0x8);
        return v.toString(16);
    });
}

/**
 * Get file extension
 * @param {string} filename - File name
 * @returns {string} - File extension (without dot)
 */
function getFileExtension(filename) {
    const parts = filename.split('.');
    return parts.length > 1 ? parts.pop().toLowerCase() : '';
}

/**
 * Check if file type is image
 * @param {string} filename - File name
 * @returns {boolean} - True if image
 */
function isImageFile(filename) {
    const ext = getFileExtension(filename);
    const imageExtensions = ['jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp', 'svg', 'ico'];
    return imageExtensions.includes(ext);
}

/**
 * Check if file type is video
 * @param {string} filename - File name
 * @returns {boolean} - True if video
 */
function isVideoFile(filename) {
    const ext = getFileExtension(filename);
    const videoExtensions = ['mp4', 'avi', 'mkv', 'mov', 'wmv', 'flv', 'webm'];
    return videoExtensions.includes(ext);
}

/**
 * Copy text to clipboard
 * @param {string} text - Text to copy
 * @returns {Promise<boolean>} - Success status
 */
async function copyToClipboard(text) {
    try {
        if (navigator.clipboard && navigator.clipboard.writeText) {
            await navigator.clipboard.writeText(text);
            return true;
        }
        // Fallback for older browsers
        const textArea = document.createElement('textarea');
        textArea.value = text;
        textArea.style.position = 'fixed';
        textArea.style.left = '-999999px';
        document.body.appendChild(textArea);
        textArea.select();
        const successful = document.execCommand('copy');
        document.body.removeChild(textArea);
        return successful;
    } catch (err) {
        console.error('Failed to copy to clipboard:', err);
        return false;
    }
}

// Export functions for use in other modules
window.Utils = {
    formatSize,
    formatDate,
    formatRelativeTime,
    getFileIcon,
    escapeHtml,
    debounce,
    generateUUID,
    getFileExtension,
    isImageFile,
    isVideoFile,
    copyToClipboard
};
