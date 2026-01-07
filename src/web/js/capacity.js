// Capacity Management Module

/**
 * Get user capacity information
 * @returns {Promise<object>} - Capacity info { total_quota, total_used, remaining, percentage }
 */
async function getCapacity() {
    try {
        const response = await window.APIUtils.get('/user/capacity');
        if (!response.ok) {
            const error = await response.json();
            throw new Error(error.error || 'Failed to get capacity');
        }
        return await response.json();
    } catch (error) {
        console.error('Get capacity failed:', error);
        throw error;
    }
}

/**
 * Update capacity display in the UI
 * @param {object} capacity - Capacity info object
 */
function updateCapacityDisplay(capacity) {
    const usedEl = document.getElementById('capacityUsed');
    const totalEl = document.getElementById('capacityTotal');
    const progressBar = document.getElementById('capacityProgressBar');
    const percentageEl = document.getElementById('capacityPercentage');
    const remainingEl = document.getElementById('capacityRemaining');

    if (!capacity) return;

    const { total_quota, total_used, remaining, percentage } = capacity;

    // Update text displays
    if (usedEl) {
        usedEl.textContent = window.Utils.formatSize(total_used);
    }

    if (totalEl) {
        totalEl.textContent = window.Utils.formatSize(total_quota);
    }

    if (remainingEl) {
        remainingEl.textContent = window.Utils.formatSize(remaining);
    }

    if (percentageEl) {
        percentageEl.textContent = percentage.toFixed(1) + '%';
    }

    // Update progress bar
    if (progressBar) {
        progressBar.style.width = `${Math.min(percentage, 100)}%`;

        // Update color based on usage
        progressBar.classList.remove('bg-green-500', 'bg-yellow-500', 'bg-orange-500', 'bg-red-500');

        if (percentage >= 95) {
            progressBar.classList.add('bg-red-500');
        } else if (percentage >= 80) {
            progressBar.classList.add('bg-orange-500');
        } else if (percentage >= 50) {
            progressBar.classList.add('bg-yellow-500');
        } else {
            progressBar.classList.add('bg-green-500');
        }
    }

    // Show warning if near limit
    if (percentage >= 90) {
        showCapacityWarning(capacity);
    }
}

/**
 * Show capacity warning toast
 * @param {object} capacity - Capacity info object
 */
function showCapacityWarning(capacity) {
    const { total_used, total_quota, remaining } = capacity;
    const message = `存储空间不足！已用 ${window.Utils.formatSize(total_used)} / ${window.Utils.formatSize(total_quota)}，剩余 ${window.Utils.formatSize(remaining)}`;

    showToast(message, 'warning');
}

/**
 * Check if user has enough capacity before upload
 * @param {number} fileSize - File size in bytes
 * @returns {Promise<boolean>} - True if has enough capacity
 */
async function checkCapacityBeforeUpload(fileSize) {
    try {
        const capacity = await getCapacity();
        if (capacity.total_used + fileSize > capacity.total_quota) {
            const needed = window.Utils.formatSize(fileSize);
            const available = window.Utils.formatSize(capacity.total_quota - capacity.total_used);
            const message = `存储空间不足！需要 ${needed}，仅剩 ${available}`;
            showToast(message, 'error');
            return false;
        }
        return true;
    } catch (error) {
        console.error('Capacity check failed:', error);
        // Allow upload if check fails (fallback behavior)
        return true;
    }
}

/**
 * Recalculate user capacity (admin utility)
 * @returns {Promise<object>} - Recalculation result
 */
async function recalculateCapacity() {
    try {
        const response = await window.APIUtils.post('/user/recalculate');
        if (!response.ok) {
            const error = await response.json();
            throw new Error(error.error || 'Failed to recalculate');
        }
        showToast('容量已重新计算', 'success');
        return await response.json();
    } catch (error) {
        console.error('Recalculate capacity failed:', error);
        showToast('重新计算失败', 'error');
        throw error;
    }
}

/**
 * Initialize capacity display on page load
 */
async function initCapacityDisplay() {
    try {
        const capacity = await getCapacity();
        updateCapacityDisplay(capacity);
    } catch (error) {
        console.error('Failed to initialize capacity display:', error);
    }
}

// Export functions
window.CapacityUtils = {
    getCapacity,
    updateCapacityDisplay,
    showCapacityWarning,
    checkCapacityBeforeUpload,
    recalculateCapacity,
    initCapacityDisplay
};
